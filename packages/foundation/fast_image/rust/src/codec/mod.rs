mod jpeg_region;
mod png_region;
mod png_stripe;
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

pub use png_stripe::PngStripeWriter;
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

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ImageFormat {
    Jpeg,
    Png,
    WebP,
    Gif,
    Bmp,
    Other,
}

pub struct ImageProbe {
    pub format: ImageFormat,
    pub width: u32,
    pub height: u32,
    pub progressive: bool,
    pub region_decodable: bool,
}

pub struct ThumbnailTarget {
    pub width: u32,
    pub output_stem: String,
}

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

fn image_header(bytes: &[u8]) -> Result<(u32, u32, Orientation)> {
    let mut decoder = ImageReader::new(Cursor::new(bytes))
        .with_guessed_format()?
        .into_decoder()
        .map_err(|e| anyhow!("Failed to read image header: {}", e))?;
    let (width, height) = decoder.dimensions();
    let orientation = decoder.orientation().unwrap_or(Orientation::NoTransforms);
    Ok((width, height, orientation))
}

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

// tj3Transform 要整幅系数缓冲，64MP ≈ 192MB 瞬时峰值
const BASELINE_MAX_PIXELS: u64 = 64 * 1024 * 1024;

pub fn to_baseline_file(file_path: &str, output_path: &str) -> Result<()> {
    let bytes = map_file(file_path)?;
    let header = turbo::read_header(&bytes)?;
    if header.width as u64 * header.height as u64 > BASELINE_MAX_PIXELS {
        bail!("JPEG too large to transcode to baseline");
    }
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

pub fn make_thumbnails(
    file_path: &str,
    targets: &[ThumbnailTarget],
    quality: u8,
) -> Result<ImageMeta> {
    let bytes = map_file(file_path)?;
    let header = read_header(&bytes)?;
    let (src_width, src_height) = header.upright();
    let swaps = swaps_axes(header.orientation);

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
            if img.color().has_alpha() {
                DynamicImage::ImageRgba8(img.into_rgba8())
            } else {
                DynamicImage::ImageRgb8(img.into_rgb8())
            }
        }
    };
    drop(bytes);

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

fn part_path(out_path: &str) -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    format!(
        "{out_path}.{}-{}.part",
        std::process::id(),
        SEQ.fetch_add(1, Ordering::Relaxed)
    )
}

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

const TIER_MAX_ASPECT: f64 = 3.0;

fn scale_numerator(src_width: u32, needed: u32) -> u8 {
    (1..=8u8)
        .find(|&n| turbo::scaled(src_width, n) >= needed)
        .unwrap_or(8)
}

const PARALLEL_MIN_BYTES: usize = 6 * 1024 * 1024;

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

fn decode_upright(file_path: &str) -> Result<DynamicImage> {
    let (mut img, orientation) = decode_raw(file_path)?;
    img.apply_orientation(orientation);
    Ok(img)
}

fn swaps_axes(orientation: Orientation) -> bool {
    matches!(
        orientation,
        Orientation::Rotate90
            | Orientation::Rotate270
            | Orientation::Rotate90FlipH
            | Orientation::Rotate270FlipH
    )
}

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
        assert_eq!(tier_target(1000, 30000, 512), Some((51, 1536)));
        assert_eq!(tier_target(512, 20000, 512), Some((39, 1536)));
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

    #[test]
    fn thumbnails_alpha_source_stays_png() {
        let dir = std::env::temp_dir().join("moodiary_img_thumb_alpha_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.png");
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

    #[test]
    fn rgba_source_encodes_to_jpeg() {
        let dir = std::env::temp_dir().join("moodiary_img_alpha_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src = dir.join("src.png");
        let dst = dir.join("out.jpg");

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

        // CompressSpec 的 min_* 不是夹取而是「拉到正好」，小图会被放大
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
