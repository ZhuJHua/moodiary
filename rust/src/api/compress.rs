use std::io::BufWriter;

use anyhow::Result;
use fast_image_resize::images::Image;
use fast_image_resize::{IntoImageView, Resizer};

use flutter_rust_bridge::frb;
use image::{
    codecs::{
        jpeg::JpegEncoder,
        png::{CompressionType, FilterType, PngEncoder},
        webp::WebPEncoder,
    }, DynamicImage, GenericImageView, ImageEncoder,
    ImageReader,
};

use super::constants::CompressFormat;

pub fn compress(
    img: &DynamicImage,
    dst_height: u32,
    dst_width: u32,
    compress_format: CompressFormat,
    quality: u8,
) -> Result<Vec<u8>> {
    let pixel_type = img.pixel_type().unwrap();
    let mut dst_image = Image::new(dst_width, dst_height, pixel_type);
    let mut resizer = Resizer::new();

    // 调整大小
    resizer.resize(img, &mut dst_image, None)?;

    let mut result_buf = BufWriter::new(Vec::new());
    match compress_format {
        CompressFormat::WebP => {
            // 使用 WebP 编码
            WebPEncoder::new_lossless(&mut result_buf).write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                img.color().into(),
            )?;
        }
        CompressFormat::Png => {
            // 使用 PNG 编码
            PngEncoder::new_with_quality(
                &mut result_buf,
                CompressionType::Fast,
                FilterType::Adaptive,
            )
            .write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                img.color().into(),
            )?;
        }
        CompressFormat::Jpeg => {
            // 使用 JPEG 编码
            JpegEncoder::new_with_quality(&mut result_buf, quality).write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                img.color().into(),
            )?;
        }
    }

    Ok(result_buf.into_inner()?)
}

#[frb(opaque)]
pub struct ImageCompress;

impl ImageCompress {
    pub fn contain_with_options(
        file_path: String,
        compress_format: Option<CompressFormat>,
        target_width: Option<u32>,
        target_height: Option<u32>,
        min_width: Option<u32>,
        min_height: Option<u32>,
        max_width: Option<u32>,
        max_height: Option<u32>,
        quality: Option<u8>,
    ) -> Result<Vec<u8>> {
        let src_img = Self::load_image(&file_path)?;
        let compress_format = compress_format.unwrap_or(CompressFormat::Jpeg);
        let quality = quality.unwrap_or(80);

        let (img_width, img_height) = src_img.dimensions();
        let (dst_width, dst_height) = Self::calculate_target_dimensions(
            img_width,
            img_height,
            &ResizeOptions {
                target_width,
                target_height,
                min_width,
                min_height,
                max_width,
                max_height,
            },
        );

        compress(&src_img, dst_height, dst_width, compress_format, quality)
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

    fn load_image(file_path: &str) -> Result<DynamicImage> {
        ImageReader::open(file_path)?
            .with_guessed_format()?
            .decode()
            .map_err(|e| anyhow::anyhow!("Failed to decode image: {}", e))
    }
}
pub struct ResizeOptions {
    pub target_width: Option<u32>,
    pub target_height: Option<u32>,
    pub min_width: Option<u32>,
    pub min_height: Option<u32>,
    pub max_width: Option<u32>,
    pub max_height: Option<u32>,
}
