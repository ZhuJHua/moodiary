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
    },
    DynamicImage, GenericImageView, ImageEncoder, ImageReader,
};

use super::constants::CompressFormat;

pub fn compress(
    img: &DynamicImage,
    dst_height: u32,
    dst_width: u32,
    compress_format: CompressFormat,
    quality: u8,
) -> Result<Vec<u8>> {
    // 创建一个待填充的图片
    let pixel_type = img.pixel_type().unwrap(); // 获取像素类型
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

    // 返回压缩结果
    Ok(result_buf.into_inner()?)
}

#[frb(opaque)]
pub struct ImageCompress;

impl ImageCompress {
    pub fn contain(
        file_path: String,
        compress_format: Option<CompressFormat>,
        max_width: Option<i32>,
        max_height: Option<i32>,
        quality: Option<u8>,
    ) -> Result<Vec<u8>> {
        let src_img = Self::load_image(&file_path)?;
        let compress_format = compress_format.unwrap_or(CompressFormat::Jpeg);
        let quality = quality.unwrap_or(80);

        let (img_width, img_height) = src_img.dimensions();
        let (dst_width, dst_height) = Self::calculate_target_dimensions(
            img_width,
            img_height,
            max_width.unwrap_or(1024) as u32,
            max_height.unwrap_or(1024) as u32,
        );

        compress(&src_img, dst_height, dst_width, compress_format, quality)
    }

    fn load_image(file_path: &str) -> Result<DynamicImage> {
        ImageReader::open(file_path)?
            .with_guessed_format()?
            .decode()
            .map_err(|e| anyhow::anyhow!("Failed to decode image: {}", e))
    }

    fn calculate_target_dimensions(
        img_width: u32,
        img_height: u32,
        max_width: u32,
        max_height: u32,
    ) -> (u32, u32) {
        // 确保浮点计算
        let aspect_ratio = img_width as f64 / img_height as f64;

        if aspect_ratio > 1.0 {
            // 横图，根据 max_height 缩放
            let ratio = max_height as f64 / img_height as f64;
            let dst_width = (img_width as f64 * ratio).round() as u32;
            let dst_height = max_height;
            (dst_width, dst_height)
        } else {
            // 竖图，根据 max_width 缩放
            let ratio = max_width as f64 / img_width as f64;
            let dst_width = max_width;
            let dst_height = (img_height as f64 * ratio).round() as u32;
            (dst_width, dst_height)
        }
    }
}
