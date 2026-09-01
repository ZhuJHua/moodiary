//! 图片压缩 / 缩放 / 编码。

use std::fs::{self, File};
use std::io::{BufWriter, Write};

use anyhow::{Result, anyhow};
use fast_image_resize::images::Image;
use fast_image_resize::{IntoImageView, Resizer};

use image::{
    DynamicImage, GenericImageView, ImageDecoder, ImageEncoder, ImageReader,
    codecs::{
        jpeg::JpegEncoder,
        png::{CompressionType, FilterType, PngEncoder},
    },
    metadata::Orientation,
};

#[derive(PartialEq, Eq)]
pub enum CompressFormat {
    Jpeg,
    WebP,
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

fn compress<W: Write>(
    img: &DynamicImage,
    dst_height: u32,
    dst_width: u32,
    compress_format: CompressFormat,
    quality: u8,
    writer: &mut W,
) -> Result<()> {
    let pixel_type = img
        .pixel_type()
        .ok_or_else(|| anyhow!("Failed to determine pixel type"))?;
    let mut dst_image = Image::new(dst_width, dst_height, pixel_type);
    let mut resizer = Resizer::new();

    resizer.resize(img, &mut dst_image, None)?;

    match compress_format {
        // 有损 WebP（libwebp）。image crate 的 WebPEncoder 仅无损，照片会比 JPEG 还大。
        // prepare 已把 WebP 目标的源图归一为 RGB8/RGBA8，这里只需两分支。
        CompressFormat::WebP => {
            let enc = if img.color().has_alpha() {
                webp::Encoder::from_rgba(dst_image.buffer(), dst_width, dst_height)
            } else {
                webp::Encoder::from_rgb(dst_image.buffer(), dst_width, dst_height)
            };
            // `Encoder::encode` 内部是 `encode_simple(..).unwrap()`：任一边超过
            // WEBP_MAX_DIMENSION(16383) 就 panic。走 encode_simple 拿回错误。
            let mem = enc
                .encode_simple(false, quality as f32)
                .map_err(|e| anyhow!("webp encode failed: {e:?}"))?;
            writer.write_all(&mem)?;
        }
        CompressFormat::Png => {
            PngEncoder::new_with_quality(writer, CompressionType::Fast, FilterType::Adaptive)
                .write_image(
                    dst_image.buffer(),
                    dst_width,
                    dst_height,
                    img.color().into(),
                )?;
        }
        CompressFormat::Jpeg => {
            JpegEncoder::new_with_quality(writer, quality).write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                img.color().into(),
            )?;
        }
    }

    Ok(())
}

/// 统一压缩尺寸规则（上限 1280）：
/// - 宽高均 ≤ 1280：不变（含宽高比 > 2 的小长图——不做放大）
/// - 任一边 > 1280 且 宽高比 ≤ 2：长边压到 1280，短边等比
/// - 仅一边 > 1280 且 宽高比 > 2：不变（长图）
/// - 两边均 > 1280 且 宽高比 > 2：短边压到 1280，长边等比
fn optimize_dimensions(width: u32, height: u32) -> (u32, u32) {
    const LIMIT: f64 = 1280.0;
    let (w, h) = (width as f64, height as f64);
    let (long, short) = if w >= h { (w, h) } else { (h, w) };
    if long <= LIMIT {
        return (width, height);
    }
    let scale = if long / short <= 2.0 {
        LIMIT / long
    } else if short > LIMIT {
        LIMIT / short
    } else {
        return (width, height);
    };
    (
        (w * scale).round().max(1.0) as u32,
        (h * scale).round().max(1.0) as u32,
    )
}

/// 解码，并**按 EXIF 把像素转正**。
///
/// `ImageReader::decode()` 不看 EXIF：它吐的是传感器方向的像素，而我们重编码之后
/// 那个方向标记也一并没了。相机成片正是这种 —— CameraX 与 AVFoundation 都只写
/// EXIF、不转像素，所以同一张照片在系统相册里是竖的（相册认标记），进了日记就成
/// 了横的（我们既没转像素、也没留标记）。从相册选进来的照片同理。
///
/// 转正必须发生在读 `dimensions()` 之前：90/270 会把宽高换过来，晚一步算出来的
/// 目标尺寸就是错的。
fn decode_upright(file_path: &str) -> Result<DynamicImage> {
    let mut decoder = ImageReader::open(file_path)?
        .with_guessed_format()?
        .into_decoder()
        .map_err(|e| anyhow!("Failed to decode image: {}", e))?;
    // 没有 EXIF、或解不出方向的，一律按不变换处理 —— 别让一个可选的元数据把整张图
    // 挡在门外。
    let orientation = decoder.orientation().unwrap_or(Orientation::NoTransforms);
    let mut img = DynamicImage::from_decoder(decoder)
        .map_err(|e| anyhow!("Failed to decode image: {}", e))?;
    img.apply_orientation(orientation);
    Ok(img)
}

pub fn optimize_to_file(file_path: String, output_path: String, quality: Option<u8>) -> Result<()> {
    let src_img = decode_upright(&file_path)?;
    // libwebp 只吃 RGB8/RGBA8。必须用 into_ 而非 to_：后者借用再新建一份，而 shadowing
    // 不 drop 旧值，两份全分辨率缓冲会一直活到函数结束。
    let src_img = if src_img.color().has_alpha() {
        DynamicImage::ImageRgba8(src_img.into_rgba8())
    } else {
        DynamicImage::ImageRgb8(src_img.into_rgb8())
    };
    let (width, height) = src_img.dimensions();
    let (dst_width, dst_height) = optimize_dimensions(width, height);

    if let Some(parent) = std::path::Path::new(&output_path).parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }
    let mut writer = BufWriter::new(File::create(&output_path)?);
    compress(
        &src_img,
        dst_height,
        dst_width,
        CompressFormat::WebP,
        quality.unwrap_or(80),
        &mut writer,
    )?;
    writer.flush()?;
    Ok(())
}

pub fn contain_to_file(file_path: String, output_path: String, spec: CompressSpec) -> Result<()> {
    let (src_img, dst_width, dst_height, format, quality) = prepare(file_path, spec)?;

    if let Some(parent) = std::path::Path::new(&output_path).parent()
        && !parent.as_os_str().is_empty()
    {
        fs::create_dir_all(parent)?;
    }

    let mut writer = BufWriter::new(File::create(&output_path)?);
    compress(
        &src_img,
        dst_height,
        dst_width,
        format,
        quality,
        &mut writer,
    )?;
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

    // libwebp 只吃 RGB8/RGBA8；灰度 / 16 位等色型先归一，其余格式不动。
    if format == CompressFormat::WebP {
        src_img = if src_img.color().has_alpha() {
            DynamicImage::ImageRgba8(src_img.into_rgba8())
        } else {
            DynamicImage::ImageRgb8(src_img.into_rgb8())
        };
    }

    // JPEG 同样挑色型：image 0.25 的编码器只认 L8 与 Rgb8，其余（RGBA、16 位…）
    // 一律 Err(Unsupported)。归一化此前只对 WebP 做，于是带 alpha 的源图导出必失败
    // ——而入库路径对有 alpha 的图存的正是 RGBA WebP，Markdown / DOCX / PDF 三种导出
    // 又都走 JPEG，等于库里每一张带透明通道的图在导出产物里都不存在。
    if format == CompressFormat::Jpeg {
        src_img = match src_img {
            // 编码器原生支持，不动（灰度保持灰度，免得白白胀成三通道）。
            img @ (DynamicImage::ImageLuma8(_) | DynamicImage::ImageRgb8(_)) => img,
            img if img.color().has_alpha() => {
                // JPEG 没有 alpha 通道。直接 into_rgb8 会丢弃 alpha 而保留其下的
                // RGB，透明区常常变成黑块；合成到白底才是用户预期的样子。
                let rgba = img.into_rgba8();
                let mut rgb = image::RgbImage::new(rgba.width(), rgba.height());
                for (x, y, px) in rgba.enumerate_pixels() {
                    let a = px[3] as u32;
                    let over = |c: u8| {
                        ((c as u32 * a + 255 * (255 - a)) / 255) as u8
                    };
                    rgb.put_pixel(x, y, image::Rgb([over(px[0]), over(px[1]), over(px[2])]));
                }
                DynamicImage::ImageRgb8(rgb)
            }
            img => DynamicImage::ImageRgb8(img.into_rgb8()),
        };
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
    use super::{CompressFormat, CompressSpec, contain_to_file, optimize_dimensions};

    #[test]
    fn optimize_dimension_rules() {
        assert_eq!(optimize_dimensions(1000, 800), (1000, 800));
        assert_eq!(optimize_dimensions(1200, 300), (1200, 300));
        assert_eq!(optimize_dimensions(2560, 1920), (1280, 960));
        assert_eq!(optimize_dimensions(1920, 2560), (960, 1280));
        assert_eq!(optimize_dimensions(4000, 2000), (1280, 640));
        assert_eq!(optimize_dimensions(800, 6000), (800, 6000));
        assert_eq!(optimize_dimensions(3000, 900), (3000, 900));
        assert_eq!(optimize_dimensions(3000, 9000), (1280, 3840));
        assert_eq!(optimize_dimensions(9000, 3000), (3840, 1280));
        assert_eq!(optimize_dimensions(1280, 1280), (1280, 1280));
    }

    /// 带 alpha 的源图必须能编成 JPEG。image 0.25 的 JPEG 编码器只认 L8/Rgb8，
    /// 归一化此前只对 WebP 做，于是 RGBA 源图一律 Err(Unsupported) —— 而入库路径
    /// 对有 alpha 的图存的正是 RGBA WebP，三种导出又都走 JPEG，等于库里每一张
    /// 带透明通道的图在导出产物里都不存在。
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

        // 断言的重点是「能编出来」——修复前这一步就是 Err(Unsupported)。
        // 尺寸不断言：CompressSpec 的 min_* 不是夹取而是「拉到正好」，小图会被放大，
        // 那是既有行为，不在本次改动范围内。
        let out = image::open(&dst).expect("产物应当是可解码的 JPEG");
        let (w, h) = image::GenericImageView::dimensions(&out);
        assert_eq!(w / 2, h, "宽高比应保持 2:1");
        let rgb = out.to_rgb8();
        // 透明区合成到白底，而不是丢弃 alpha 后留下的黑块。
        let px = rgb.get_pixel(w - 2, 1).0;
        assert!(
            px[0] > 200 && px[1] > 200 && px[2] > 200,
            "透明区应合成为白色，实际 {px:?}"
        );
        // 不透明区仍是红的（没被整张压白）。
        let red = rgb.get_pixel(1, 1).0;
        assert!(red[0] > 150 && red[1] < 100, "不透明区应保持红色，实际 {red:?}");

        let _ = std::fs::remove_dir_all(&dir);
    }
}
