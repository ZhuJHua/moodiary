//! 图片读头 / 缩放 / 编码。JPEG 走 turbojpeg（读头、IDCT 缩放解码、编码），其余格式走 image。

mod jpeg_region;
mod png_region;
mod region;
mod restart;
mod turbo;
mod webp_region;

use std::fs::{self, File};
use std::io::{BufWriter, Cursor, Write};

use anyhow::{Result, anyhow, bail};
use fast_image_resize::images::Image;
use fast_image_resize::{IntoImageView, Resizer};

use image::{
    DynamicImage, ExtendedColorType, GenericImageView, ImageDecoder, ImageEncoder, ImageReader,
    codecs::{
        jpeg::JpegEncoder,
        png::{CompressionType, FilterType, PngEncoder},
    },
    metadata::Orientation,
};

pub use region::{RawDecoder, Rect, RegionDecoder, TilePixels};
pub use turbo::JpegHeader;

#[derive(PartialEq, Eq)]
pub enum CompressFormat {
    Jpeg,
    Png,
}

pub struct CompressSpec {
    pub compress_format: Option<CompressFormat>,
    pub target_width: Option<u32>,
    pub target_height: Option<u32>,
    pub min_width: Option<u32>,
    pub min_height: Option<u32>,
    pub max_width: Option<u32>,
    pub max_height: Option<u32>,
    pub quality: Option<u8>,
}

/// 源格式，按魔数定。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ImageFormat {
    Jpeg,
    Png,
    WebP,
    Gif,
    Bmp,
    Other,
}

/// 只读头不解像素。宽高是 EXIF 转正后的。
pub struct ImageProbe {
    pub format: ImageFormat,
    pub width: u32,
    pub height: u32,
    pub progressive: bool,
    /// 能走 turbojpeg 缩放 / 区域解码（8 位 Huffman 有损 JPEG）。
    pub region_decodable: bool,
}

/// 一个缩略图档位：缩到 [`width`] 宽（高等比），写到 `output_stem` + 按内容定的后缀
/// （`.jpg`，带 alpha 的源 `.png`）。
pub struct ThumbnailTarget {
    pub width: u32,
    pub output_stem: String,
}

/// 源图（EXIF 转正后）的像素尺寸，以及这次写出的派生物后缀（`jpg` / `png`）。
pub struct ImageMeta {
    pub width: u32,
    pub height: u32,
    pub ext: String,
}

fn sniff(bytes: &[u8]) -> ImageFormat {
    match image::guess_format(bytes) {
        Ok(image::ImageFormat::Jpeg) => ImageFormat::Jpeg,
        Ok(image::ImageFormat::Png) => ImageFormat::Png,
        Ok(image::ImageFormat::WebP) => ImageFormat::WebP,
        Ok(image::ImageFormat::Gif) => ImageFormat::Gif,
        Ok(image::ImageFormat::Bmp) => ImageFormat::Bmp,
        _ => ImageFormat::Other,
    }
}

/// image 侧只读头：原始朝向的宽高 + EXIF 方向。JPEG 的宽高改由 turbojpeg 给，这里只要方向。
fn image_header(bytes: &[u8]) -> Result<(u32, u32, Orientation)> {
    let mut decoder = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .into_decoder()
        .map_err(|e| anyhow!("Failed to read image header: {}", e))?;
    let (width, height) = decoder.dimensions();
    // 没有 EXIF、或解不出方向的，一律按不变换处理 —— 别让一个可选的元数据把整张图挡在门外。
    let orientation = decoder.orientation().unwrap_or(Orientation::NoTransforms);
    Ok((width, height, orientation))
}

/// 头信息：原始朝向宽高、方向、格式、JPEG 头（非 JPEG 为 None）。
struct Header {
    format: ImageFormat,
    raw_width: u32,
    raw_height: u32,
    orientation: Orientation,
    jpeg: Option<JpegHeader>,
}

fn read_header(bytes: &[u8]) -> Result<Header> {
    let format = sniff(bytes);
    let (_, _, orientation) = image_header(bytes)?;
    if format == ImageFormat::Jpeg {
        let jpeg = turbo::read_header(bytes)?;
        return Ok(Header {
            format,
            raw_width: jpeg.width,
            raw_height: jpeg.height,
            orientation,
            jpeg: Some(jpeg),
        });
    }
    let (raw_width, raw_height, _) = image_header(bytes)?;
    Ok(Header {
        format,
        raw_width,
        raw_height,
        orientation,
        jpeg: None,
    })
}

impl Header {
    fn upright(&self) -> (u32, u32) {
        if swaps_axes(self.orientation) {
            (self.raw_height, self.raw_width)
        } else {
            (self.raw_width, self.raw_height)
        }
    }
}

/// 原件只读映射：313MB 的原图不整个读进内存。原件不可变是全库约定，映射期间不会被改写。
fn map_file(file_path: &str) -> Result<memmap2::Mmap> {
    let file = File::open(file_path)?;
    Ok(unsafe { memmap2::Mmap::map(&file)? })
}

pub fn probe(file_path: &str) -> Result<ImageProbe> {
    let bytes = map_file(file_path)?;
    let header = read_header(&bytes)?;
    let (width, height) = header.upright();
    let region_decodable = match header.format {
        ImageFormat::Jpeg => header.jpeg.is_some_and(|j| j.region_decodable()),
        ImageFormat::Png => png_region::region_decodable(&bytes),
        ImageFormat::WebP => webp_region::region_decodable(&bytes),
        _ => false,
    };
    Ok(ImageProbe {
        format: header.format,
        width,
        height,
        progressive: header.jpeg.is_some_and(|j| j.progressive),
        region_decodable,
    })
}

/// progressive 转 baseline 能接的像素上限：`tj3Transform` 要整幅系数缓冲，4:2:0 约 3 字节 / 像素，
/// 64MP 就是 192MB 的瞬时峰值。
const BASELINE_MAX_PIXELS: u64 = 64 * 1024 * 1024;

/// 把 progressive JPEG **无损**转成 baseline（每行 MCU 一个 restart marker）落到 `output_path`：
/// 看图页 tile 只吃 baseline，progressive 要整幅系数缓冲、不能区域解。先写 `.part` 再 rename。
pub fn to_baseline_file(file_path: &str, output_path: &str) -> Result<()> {
    let bytes = map_file(file_path)?;
    let header = turbo::read_header(&bytes)?;
    if header.width as u64 * header.height as u64 > BASELINE_MAX_PIXELS {
        bail!("JPEG too large to transcode to baseline");
    }
    // 转出来的必须能区域解：12 位 / 算术 / 无损的转了也白转；已是 baseline 的没必要转。
    if !header.progressive {
        bail!("JPEG is already baseline");
    }
    if header.precision != 8 || header.arithmetic || header.lossless || header.cmyk {
        bail!("JPEG cannot be transcoded into a region-decodable baseline");
    }
    let encoded = turbo::to_baseline(&bytes, 1)?;
    drop(bytes);
    let out = std::path::Path::new(output_path);
    if let Some(parent) = out.parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }
    let part = part_path(output_path);
    fs::write(&part, &encoded)?;
    fs::rename(&part, out)?;
    Ok(())
}

/// 一次解码、链式缩出多个宽度档位。
///
/// - JPEG 源走 turbojpeg 按 N/8 IDCT 缩放解码，只解到「刚不小于最大档位」的尺寸：
///   48MP 出 1280 档解 2/8，峰值约 6MB；其余格式走 image 全解。大文件带 restart marker
///   的还分段并行（[`decode_jpeg_scaled`]）。
/// - 编码按透明通道选：不带 alpha 编 JPEG（PNG 源 4:4:4 保文字边缘，其余 4:2:0），
///   带 alpha 编 PNG 无损。派生物后缀由此定，调用方按 [`ImageMeta::ext`] 认。
/// - 源图不比档位宽的档位**跳过不写**（不放大）。
/// - 档位按宽度从大到小处理，每一级从上一级缩：Lanczos3 在这种比例下看不出差别，
///   而重采样的像素数少一个量级；处理完一级就丢掉上一级，内存里只压着两张。
/// - **先缩后转**：链路全程按原始朝向缩，EXIF 方向只作用在每一级缩好的小图上
///   （1280 宽转 90° 是几 MB 的事，全分辨率上转是再来一份原图）。
/// - 先写 `.part` 再 rename：生成中途被杀不会留下半张图被当成有效缩略图。
pub fn make_thumbnails(
    file_path: &str,
    targets: &[ThumbnailTarget],
    quality: u8,
) -> Result<ImageMeta> {
    let bytes = map_file(file_path)?;
    let header = read_header(&bytes)?;
    let (src_width, src_height) = header.upright();
    let swaps = swaps_axes(header.orientation);

    // 每档的目标尺寸（转正后坐标）；源图已经不比档位大的档位跳过不写。
    let mut order: Vec<(&ThumbnailTarget, (u32, u32))> = targets
        .iter()
        .filter(|t| t.width > 0)
        .filter_map(|t| tier_target(src_width, src_height, t.width).map(|dims| (t, dims)))
        .collect();
    order.sort_by_key(|(t, _)| std::cmp::Reverse(t.width));

    let mut meta = ImageMeta {
        width: src_width,
        height: src_height,
        ext: "jpg".into(),
    };
    let Some(largest) = order.first().map(|(_, (w, _))| *w) else {
        return Ok(meta);
    };

    let mut current = match header.jpeg {
        Some(_) => DynamicImage::ImageRgb8(decode_jpeg_scaled(
            &bytes,
            scale_numerator(src_width, largest),
        )?),
        None => {
            let img = ImageReader::new(Cursor::new(&bytes[..]))
                .with_guessed_format()?
                .decode()
                .map_err(|e| anyhow!("Failed to decode image: {}", e))?;
            // 必须用 into_ 而非 to_：后者借用再新建一份，两份全分辨率缓冲会一直活到函数结束。
            if img.color().has_alpha() {
                DynamicImage::ImageRgba8(img.into_rgba8())
            } else {
                DynamicImage::ImageRgb8(img.into_rgb8())
            }
        }
    };
    drop(bytes);

    // 带 alpha 通道但全不透明（WebP / PNG 导出常见）当不透明处理：编 JPEG 而不是 PNG。
    let has_alpha = current.color().has_alpha()
        && current
            .as_rgba8()
            .is_some_and(|img| img.pixels().any(|p| p.0[3] != 255));
    if has_alpha {
        meta.ext = "png".into();
    } else if current.color().has_alpha() {
        current = DynamicImage::ImageRgb8(current.into_rgb8());
    }
    let chroma_444 = header.format == ImageFormat::Png;
    let mut resizer = Resizer::new();

    for (target, (up_width, up_height)) in order {
        // 目标尺寸按源图比例算，不按上一级：N/8 缩放的向上取整会把中间级的比例带偏一像素。
        // 缓冲仍是原始朝向，转正后的宽高换回去。
        let (dst_width, dst_height) = if swaps {
            (up_height, up_width)
        } else {
            (up_width, up_height)
        };

        let pixel_type = current
            .pixel_type()
            .ok_or_else(|| anyhow!("Failed to determine pixel type"))?;
        let mut dst = Image::new(dst_width, dst_height, pixel_type);
        resizer.resize(&current, &mut dst, None)?;

        // 下一级从这一级缩（仍是原始朝向）。
        let raw = dst.into_vec();
        current = if has_alpha {
            DynamicImage::ImageRgba8(
                image::RgbaImage::from_raw(dst_width, dst_height, raw)
                    .ok_or_else(|| anyhow!("resize buffer size mismatch"))?,
            )
        } else {
            DynamicImage::ImageRgb8(
                image::RgbImage::from_raw(dst_width, dst_height, raw)
                    .ok_or_else(|| anyhow!("resize buffer size mismatch"))?,
            )
        };

        // 转正只作用在这一级的小图上。
        let upright;
        let img = if matches!(header.orientation, Orientation::NoTransforms) {
            &current
        } else {
            let mut rotated = current.clone();
            rotated.apply_orientation(header.orientation);
            upright = rotated;
            &upright
        };
        let (out_width, out_height) = img.dimensions();
        let encoded = if has_alpha {
            encode_png(img.as_bytes(), out_width, out_height)?
        } else {
            turbo::encode_jpeg(img.as_bytes(), out_width, out_height, quality, chroma_444)?
        };
        let out_path = format!("{}.{}", target.output_stem, meta.ext);
        let out = std::path::Path::new(&out_path);
        if let Some(parent) = out.parent()
            && !parent.as_os_str().is_empty()
        {
            fs::create_dir_all(parent)?;
        }
        let part = part_path(&out_path);
        fs::write(&part, &encoded)?;
        fs::rename(&part, out)?;
    }
    Ok(meta)
}

/// 临时文件名带进程号与序号：同一档位两路并发生成时各写各的，rename 是原子的，谁后到谁赢，
/// 不会出现一方 rename 另一方的半成品。
fn part_path(out_path: &str) -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    format!(
        "{out_path}.{}-{}.part",
        std::process::id(),
        SEQ.fetch_add(1, Ordering::Relaxed)
    )
}

/// 档位 `width` 在**转正后**的图上的目标尺寸：按宽缩，但高不超过宽的 [`TIER_MAX_ASPECT`] 倍
/// （长截图 1000×30000 的 512 档不能是 512×15360、一张 31MB 的位图），且永不放大；
/// 源图两个方向都已不比目标大就返回 None（不写这一档）。
fn tier_target(src_width: u32, src_height: u32, width: u32) -> Option<(u32, u32)> {
    let scale = (width as f64 / src_width as f64)
        .min(width as f64 * TIER_MAX_ASPECT / src_height as f64)
        .min(1.0);
    if scale >= 1.0 {
        return None;
    }
    let round = |v: u32| ((v as f64 * scale).round() as u32).max(1);
    Some((round(src_width), round(src_height)))
}

/// 派生物的高最多是档位宽的几倍。
const TIER_MAX_ASPECT: f64 = 3.0;

/// 最小的 N/8 使转正后的宽仍 ≥ `needed`。`src_width > needed` 由调用方保证。
fn scale_numerator(src_width: u32, needed: u32) -> u8 {
    (1..=8u8)
        .find(|&n| turbo::scaled(src_width, n) >= needed)
        .unwrap_or(8)
}

/// 超过这个体积的 JPEG 才值得扫一遍 restart 索引并行解：一趟解码 ≥ 几十毫秒时线程才划算。
const PARALLEL_MIN_BYTES: usize = 6 * 1024 * 1024;

/// 整图按 `num`/8 解成 RGB（原始朝向）：大文件且带对齐 restart marker 就分段并行。
fn decode_jpeg_scaled(bytes: &[u8], num: u8) -> Result<image::RgbImage> {
    let index = (bytes.len() >= PARALLEL_MIN_BYTES)
        .then(|| restart::RestartIndex::build(bytes))
        .flatten();
    let Some(index) = index else {
        return turbo::decode_scaled(bytes, num);
    };
    let header = turbo::read_header(bytes)?;
    let region = index.decode(
        bytes,
        num,
        region::Rect {
            x: 0,
            y: 0,
            w: turbo::scaled(header.width, num),
            h: turbo::scaled(header.height, num),
        },
        false,
        restart::threads(),
    )?;
    image::RgbImage::from_raw(region.width, region.height, region.pixels)
        .ok_or_else(|| anyhow!("decoded buffer size mismatch"))
}

fn encode_png(rgba: &[u8], width: u32, height: u32) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    PngEncoder::new_with_quality(&mut out, CompressionType::Fast, FilterType::Adaptive)
        .write_image(rgba, width, height, ExtendedColorType::Rgba8)?;
    Ok(out)
}

/// 解码但**不**转正：原始朝向的像素 + EXIF 方向。
fn decode_raw(file_path: &str) -> Result<(DynamicImage, Orientation)> {
    let mut decoder = ImageReader::open(file_path)?
        .with_guessed_format()?
        .into_decoder()
        .map_err(|e| anyhow!("Failed to decode image: {}", e))?;
    let orientation = decoder.orientation().unwrap_or(Orientation::NoTransforms);
    let img = DynamicImage::from_decoder(decoder)
        .map_err(|e| anyhow!("Failed to decode image: {}", e))?;
    Ok((img, orientation))
}

/// 解码并按 EXIF 把像素转正。`ImageReader::decode()` 不看 EXIF：相机成片只写标记不转像素，
/// 不转正的话竖拍照片进了导出就是横的。
fn decode_upright(file_path: &str) -> Result<DynamicImage> {
    let (mut img, orientation) = decode_raw(file_path)?;
    img.apply_orientation(orientation);
    Ok(img)
}

/// 方向是否交换宽高（90° / 270° 系）。
fn swaps_axes(orientation: Orientation) -> bool {
    matches!(
        orientation,
        Orientation::Rotate90
            | Orientation::Rotate270
            | Orientation::Rotate90FlipH
            | Orientation::Rotate270FlipH
    )
}

/// 导出用：整图转正、按 [`CompressSpec`] 定尺寸、编成 JPEG / PNG 落盘。
pub fn contain_to_file(file_path: String, output_path: String, spec: CompressSpec) -> Result<()> {
    let (src_img, dst_width, dst_height, format, quality) = prepare(file_path, spec)?;

    if let Some(parent) = std::path::Path::new(&output_path).parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }

    let pixel_type = src_img
        .pixel_type()
        .ok_or_else(|| anyhow!("Failed to determine pixel type"))?;
    let mut dst_image = Image::new(dst_width, dst_height, pixel_type);
    Resizer::new().resize(&src_img, &mut dst_image, None)?;

    let mut writer = BufWriter::new(File::create(&output_path)?);
    match format {
        CompressFormat::Png => {
            PngEncoder::new_with_quality(&mut writer, CompressionType::Fast, FilterType::Adaptive)
                .write_image(
                    dst_image.buffer(),
                    dst_width,
                    dst_height,
                    src_img.color().into(),
                )?;
        }
        CompressFormat::Jpeg => {
            JpegEncoder::new_with_quality(&mut writer, quality).write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                src_img.color().into(),
            )?;
        }
    }
    writer.flush()?;
    Ok(())
}

fn prepare(
    file_path: String,
    spec: CompressSpec,
) -> Result<(DynamicImage, u32, u32, CompressFormat, u8)> {
    let mut src_img = decode_upright(&file_path)?;
    let format = spec.compress_format.unwrap_or(CompressFormat::Jpeg);
    let quality = spec.quality.unwrap_or(80);

    // image 0.25 的 JPEG 编码器只认 L8 与 Rgb8，其余（RGBA、16 位…）一律 Err(Unsupported)。
    // 带 alpha 的源图合成到白底：直接丢弃 alpha 会把透明区留成黑块。
    if format == CompressFormat::Jpeg {
        src_img = match src_img {
            img @ (DynamicImage::ImageLuma8(_) | DynamicImage::ImageRgb8(_)) => img,
            img if img.color().has_alpha() => {
                let rgba = img.into_rgba8();
                let mut rgb = image::RgbImage::new(rgba.width(), rgba.height());
                for (x, y, px) in rgba.enumerate_pixels() {
                    let a = px[3] as u32;
                    let over = |c: u8| ((c as u32 * a + 255 * (255 - a)) / 255) as u8;
                    rgb.put_pixel(x, y, image::Rgb([over(px[0]), over(px[1]), over(px[2])]));
                }
                DynamicImage::ImageRgb8(rgb)
            }
            img => DynamicImage::ImageRgb8(img.into_rgb8()),
        };
    }
    if src_img.pixel_type().is_none() {
        bail!("unsupported pixel layout for resizing");
    }

    let (img_width, img_height) = src_img.dimensions();
    let (dst_width, dst_height) = calculate_target_dimensions(
        img_width,
        img_height,
        &ResizeOptions {
            target_width: spec.target_width,
            target_height: spec.target_height,
            min_width: spec.min_width,
            min_height: spec.min_height,
            max_width: spec.max_width,
            max_height: spec.max_height,
        },
    );

    Ok((src_img, dst_width, dst_height, format, quality))
}

fn calculate_target_dimensions(
    img_width: u32,
    img_height: u32,
    options: &ResizeOptions,
) -> (u32, u32) {
    if let (Some(w), Some(h)) = (options.target_width, options.target_height) {
        return (w, h);
    }

    let aspect_ratio = img_width as f64 / img_height as f64;

    if let Some(min_w) = options.min_width {
        let ratio = min_w as f64 / img_width as f64;
        return (min_w, (img_height as f64 * ratio).round() as u32);
    }

    if let Some(min_h) = options.min_height {
        let ratio = min_h as f64 / img_height as f64;
        return ((img_width as f64 * ratio).round() as u32, min_h);
    }

    let max_width = options.max_width.unwrap_or(1024);
    let max_height = options.max_height.unwrap_or(1024);

    if aspect_ratio > 1.0 {
        let ratio = max_height as f64 / img_height as f64;
        ((img_width as f64 * ratio).round() as u32, max_height)
    } else {
        let ratio = max_width as f64 / img_width as f64;
        (max_width, (img_height as f64 * ratio).round() as u32)
    }
}

struct ResizeOptions {
    target_width: Option<u32>,
    target_height: Option<u32>,
    min_width: Option<u32>,
    min_height: Option<u32>,
    max_width: Option<u32>,
    max_height: Option<u32>,
}

#[cfg(test)]
mod tests {
    use image::{ExtendedColorType, ImageEncoder};

    use super::{
        CompressFormat, CompressSpec, ImageFormat, ThumbnailTarget, contain_to_file,
        make_thumbnails, probe, scale_numerator, tier_target,
    };

    /// 一段最小 TIFF：Orientation(0x0112) = 6，即 Rotate90（顺时针）。
    const EXIF_ROTATE90: [u8; 26] = [
        b'I', b'I', 0x2a, 0x00, // little endian
        0x08, 0x00, 0x00, 0x00, // IFD0 @8
        0x01, 0x00, // 1 entry
        0x12, 0x01, 0x03, 0x00, // tag 0x0112, SHORT
        0x01, 0x00, 0x00, 0x00, // count 1
        0x06, 0x00, 0x00, 0x00, // value 6
        0x00, 0x00, 0x00, 0x00, // next IFD
    ];

    fn stem(dir: &std::path::Path, name: &str) -> String {
        dir.join(name).to_string_lossy().into_owned()
    }

    /// 原始朝向 2000x1500 的竖拍 JPEG（EXIF Rotate90）：左半红、右半蓝。
    fn write_rotated_jpeg(path: &std::path::Path) {
        let img = image::RgbImage::from_fn(2000, 1500, |x, _| {
            if x < 1000 {
                image::Rgb([220, 30, 30])
            } else {
                image::Rgb([30, 30, 220])
            }
        });
        let mut file = std::fs::File::create(path).unwrap();
        let mut enc = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut file, 90);
        enc.set_exif_metadata(EXIF_ROTATE90.to_vec()).unwrap();
        enc.write_image(img.as_raw(), 2000, 1500, ExtendedColorType::Rgb8)
            .unwrap();
    }

    /// 竖拍 JPEG 走 turbojpeg 缩放解码：档位宽按转正后算，输出已转正，且是先缩后转。
    #[test]
    fn thumbnails_rotate_after_resize() {
        let dir = std::env::temp_dir().join("moodiary_img_thumb_rot_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.jpg");
        write_rotated_jpeg(&src);

        let targets = vec![ThumbnailTarget {
            width: 512,
            output_stem: stem(&dir, "t_512"),
        }];
        let meta = make_thumbnails(&src.to_string_lossy(), &targets, 82).unwrap();
        assert_eq!((meta.width, meta.height), (1500, 2000), "meta 是转正后尺寸");
        assert_eq!(meta.ext, "jpg");

        let t = image::open(dir.join("t_512.jpg")).unwrap().into_rgb8();
        assert_eq!(t.dimensions(), (512, 683));
        let top = t.get_pixel(256, 100).0;
        let bottom = t.get_pixel(256, 600).0;
        assert!(top[0] > 150 && top[2] < 100, "上半应为红，实际 {top:?}");
        assert!(
            bottom[2] > 150 && bottom[0] < 100,
            "下半应为蓝，实际 {bottom:?}"
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn probe_reads_upright_size_without_decoding() {
        let dir = std::env::temp_dir().join("moodiary_img_probe_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.jpg");
        write_rotated_jpeg(&src);

        let p = probe(&src.to_string_lossy()).unwrap();
        assert_eq!(p.format, ImageFormat::Jpeg);
        assert_eq!((p.width, p.height), (1500, 2000));
        assert!(!p.progressive);
        assert!(p.region_decodable);

        let png = dir.join("src.png");
        image::RgbaImage::new(30, 20).save(&png).unwrap();
        let p = probe(&png.to_string_lossy()).unwrap();
        assert_eq!(p.format, ImageFormat::Png);
        assert_eq!((p.width, p.height), (30, 20));
        assert!(p.region_decodable, "非隔行 PNG 走流式区域解码");

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn tier_target_caps_width_then_height_and_never_upscales() {
        assert_eq!(tier_target(2000, 1500, 512), Some((512, 384)));
        assert_eq!(tier_target(1500, 2000, 512), Some((512, 683)));
        // 长截图：高封顶在 3 × 档位宽，宽跟着缩。
        assert_eq!(tier_target(1000, 30000, 512), Some((51, 1536)));
        // 比档位窄但很高：仍然值得出一档（位图小一个量级）。
        assert_eq!(tier_target(512, 20000, 512), Some((39, 1536)));
        // 两个方向都不比档位大：不写。
        assert_eq!(tier_target(512, 400, 512), None);
        assert_eq!(tier_target(300, 1536, 512), None);
    }

    #[test]
    fn scale_numerator_keeps_width_above_need() {
        assert_eq!(scale_numerator(8000, 1280), 2);
        assert_eq!(scale_numerator(4000, 1280), 3);
        assert_eq!(scale_numerator(4000, 512), 2);
        assert_eq!(scale_numerator(1300, 1280), 8);
    }

    /// 不带 alpha 的 PNG 源：image 全解，链式出两档 JPEG；比源图宽的档位不写（不放大）。
    #[test]
    fn thumbnails_chain_and_skip_upscale() {
        let dir = std::env::temp_dir().join("moodiary_img_thumb_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.png");
        let img =
            image::RgbImage::from_fn(2000, 1500, |x, _| image::Rgb([(x % 256) as u8, 40, 200]));
        img.save(&src).unwrap();

        let targets = vec![
            ThumbnailTarget {
                width: 512,
                output_stem: stem(&dir, "t_512"),
            },
            ThumbnailTarget {
                width: 1280,
                output_stem: stem(&dir, "t_1280"),
            },
            ThumbnailTarget {
                width: 4096,
                output_stem: stem(&dir, "t_4096"),
            },
        ];
        let meta =
            make_thumbnails(&src.to_string_lossy(), &targets, 82).expect("should produce tiers");
        assert_eq!((meta.width, meta.height), (2000, 1500));
        assert_eq!(meta.ext, "jpg");

        let t512 = image::open(dir.join("t_512.jpg")).unwrap();
        let t1280 = image::open(dir.join("t_1280.jpg")).unwrap();
        assert_eq!(image::GenericImageView::dimensions(&t512), (512, 384));
        assert_eq!(image::GenericImageView::dimensions(&t1280), (1280, 960));
        assert!(
            !dir.join("t_4096.jpg").exists(),
            "不放大：比源图宽的档位不该写文件"
        );
        assert!(
            std::fs::read_dir(&dir).unwrap().all(|e| !e
                .unwrap()
                .file_name()
                .to_string_lossy()
                .ends_with(".part"))
        );

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 带 alpha 的源：派生物是 PNG，透明保住。
    #[test]
    fn thumbnails_alpha_source_stays_png() {
        let dir = std::env::temp_dir().join("moodiary_img_thumb_alpha_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.png");
        // 左半不透明红、右半全透明。
        let img = image::RgbaImage::from_fn(1200, 600, |x, _| {
            if x < 600 {
                image::Rgba([255, 0, 0, 255])
            } else {
                image::Rgba([0, 0, 0, 0])
            }
        });
        img.save(&src).unwrap();

        let targets = vec![ThumbnailTarget {
            width: 512,
            output_stem: stem(&dir, "t_512"),
        }];
        let meta = make_thumbnails(&src.to_string_lossy(), &targets, 82).unwrap();
        assert_eq!(meta.ext, "png");
        assert!(!dir.join("t_512.jpg").exists());

        let t = image::open(dir.join("t_512.png")).unwrap().into_rgba8();
        assert_eq!(t.dimensions(), (512, 256));
        assert_eq!(t.get_pixel(100, 100).0[3], 255);
        assert_eq!(t.get_pixel(400, 100).0[3], 0, "透明区应保持透明");

        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 带 alpha 的源图必须能编成 JPEG（导出）：透明区合成到白底而不是黑块。
    #[test]
    fn rgba_source_encodes_to_jpeg() {
        let dir = std::env::temp_dir().join("moodiary_img_alpha_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.png");
        let dst = dir.join("out.jpg");

        // 左半不透明红、右半全透明。
        let mut img = image::RgbaImage::new(8, 4);
        for (x, _y, px) in img.enumerate_pixels_mut() {
            *px = if x < 4 {
                image::Rgba([255, 0, 0, 255])
            } else {
                image::Rgba([0, 0, 0, 0])
            };
        }
        img.save(&src).unwrap();

        contain_to_file(
            src.to_string_lossy().into_owned(),
            dst.to_string_lossy().into_owned(),
            CompressSpec {
                compress_format: Some(CompressFormat::Jpeg),
                target_width: None,
                target_height: None,
                min_width: None,
                min_height: None,
                max_width: None,
                max_height: None,
                quality: Some(85),
            },
        )
        .expect("RGBA 源图应当能编码成 JPEG");

        // 尺寸不断言：CompressSpec 的 min_* 不是夹取而是「拉到正好」，小图会被放大，
        // 那是既有行为。
        let out = image::open(&dst).expect("产物应当是可解码的 JPEG");
        let (w, h) = image::GenericImageView::dimensions(&out);
        assert_eq!(w / 2, h, "宽高比应保持 2:1");
        let rgb = out.to_rgb8();
        let px = rgb.get_pixel(w - 2, 1).0;
        assert!(
            px[0] > 200 && px[1] > 200 && px[2] > 200,
            "透明区应合成为白色，实际 {px:?}"
        );
        let red = rgb.get_pixel(1, 1).0;
        assert!(
            red[0] > 150 && red[1] < 100,
            "不透明区应保持红色，实际 {red:?}"
        );

        let _ = std::fs::remove_dir_all(&dir);
    }
}
