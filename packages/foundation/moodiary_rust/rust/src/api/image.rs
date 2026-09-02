use anyhow::Result;
use flutter_rust_bridge::frb;

pub use moodiary_image::{CompressFormat, CompressSpec, ImageMeta, ThumbnailTarget};

#[frb(mirror(CompressFormat))]
pub enum _CompressFormat {
    Jpeg,
    WebP,
    Png,
}

#[frb(mirror(CompressSpec))]
pub struct _CompressSpec {
    pub compress_format: Option<CompressFormat>,
    pub target_width: Option<u32>,
    pub target_height: Option<u32>,
    pub min_width: Option<u32>,
    pub min_height: Option<u32>,
    pub max_width: Option<u32>,
    pub max_height: Option<u32>,
    pub quality: Option<u8>,
}

#[frb(mirror(ThumbnailTarget))]
pub struct _ThumbnailTarget {
    pub width: u32,
    pub output_path: String,
}

#[frb(mirror(ImageMeta))]
pub struct _ImageMeta {
    pub width: u32,
    pub height: u32,
}

#[frb(opaque)]
pub struct ImageCompressor {}

impl ImageCompressor {
    /// 统一图片优化：按 1280 尺寸规则缩放 + 有损 WebP 编码（默认 q80）。
    pub fn optimize_to_file(
        file_path: String,
        output_path: String,
        quality: Option<u8>,
    ) -> Result<()> {
        moodiary_image::optimize_to_file(file_path, output_path, quality)
    }

    pub fn contain_to_file(
        file_path: String,
        output_path: String,
        spec: CompressSpec,
    ) -> Result<()> {
        moodiary_image::contain_to_file(file_path, output_path, spec)
    }

    /// 一次解码、链式缩出多个宽度档位的 WebP；不比档位宽的档位跳过不写。
    /// 返回源图（EXIF 转正后）尺寸。
    pub fn make_thumbnails(
        file_path: String,
        targets: Vec<ThumbnailTarget>,
        quality: Option<u8>,
    ) -> Result<ImageMeta> {
        moodiary_image::make_thumbnails(&file_path, &targets, quality.unwrap_or(78))
    }
}
