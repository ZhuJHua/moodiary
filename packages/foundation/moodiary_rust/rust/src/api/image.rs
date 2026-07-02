use std::fs::{self, File};
use std::io::{BufWriter, Write};

use anyhow::{anyhow, Result};
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
        CompressFormat::WebP => {
            WebPEncoder::new_lossless(writer).write_image(
                dst_image.buffer(),
                dst_width,
                dst_height,
                img.color().into(),
            )?;
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

#[frb(opaque)]
pub struct ImageCompressor {}

impl ImageCompressor {
    pub fn contain_to_file(
        file_path: String,
        output_path: String,
        spec: CompressSpec,
    ) -> Result<()> {
        let (src_img, dst_width, dst_height, format, quality) =
            Self::prepare(file_path, spec)?;

        if let Some(parent) = std::path::Path::new(&output_path).parent()
            && !parent.as_os_str().is_empty()
        {
            fs::create_dir_all(parent)?;
        }

        let mut writer = BufWriter::new(File::create(&output_path)?);
        compress(&src_img, dst_height, dst_width, format, quality, &mut writer)?;
        writer.flush()?;
        Ok(())
    }

    fn prepare(
        file_path: String,
        spec: CompressSpec,
    ) -> Result<(DynamicImage, u32, u32, CompressFormat, u8)> {
        let src_img = ImageReader::open(file_path)?
            .with_guessed_format()?
            .decode()
            .map_err(|e| anyhow::anyhow!("Failed to decode image: {}", e))?;
        let format = spec.compress_format.unwrap_or(CompressFormat::Jpeg);
        let quality = spec.quality.unwrap_or(80);

        let (img_width, img_height) = src_img.dimensions();
        let (dst_width, dst_height) = Self::calculate_target_dimensions(
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
}

struct ResizeOptions {
    target_width: Option<u32>,
    target_height: Option<u32>,
    min_width: Option<u32>,
    min_height: Option<u32>,
    max_width: Option<u32>,
    max_height: Option<u32>,
}
