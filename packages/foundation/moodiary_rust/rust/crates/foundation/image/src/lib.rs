//! 图片压缩 / 缩放 / 编码。

use std::fs::{self, File};
use std::io::{BufWriter, Write};

use anyhow::{Result, anyhow};
use fast_image_resize::images::Image;
use fast_image_resize::{IntoImageView, Resizer};

use image::{
    DynamicImage, GenericImageView, ImageEncoder, ImageReader,
    codecs::{
        jpeg::JpegEncoder,
        png::{CompressionType, FilterType, PngEncoder},
    },
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

pub fn optimize_to_file(file_path: String, output_path: String, quality: Option<u8>) -> Result<()> {
    let src_img = ImageReader::open(file_path)?
        .with_guessed_format()?
        .decode()
        .map_err(|e| anyhow::anyhow!("Failed to decode image: {}", e))?;
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
    let mut src_img = ImageReader::open(file_path)?
        .with_guessed_format()?
        .decode()
        .map_err(|e| anyhow::anyhow!("Failed to decode image: {}", e))?;
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
    use super::optimize_dimensions;

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
}
