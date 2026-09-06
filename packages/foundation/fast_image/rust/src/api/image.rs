use anyhow::Result;
use flutter_rust_bridge::frb;

pub use crate::codec::{
    CompressFormat as FastCompressFormat, CompressSpec as FastCompressSpec,
    ImageFormat as FastImageFormat, ImageMeta as FastImageMeta, ImageProbe as FastImageProbe,
    ThumbnailTarget as FastThumbnailTarget, TilePixels as FastTilePixels,
};

#[frb(mirror(FastCompressFormat))]
pub enum _FastCompressFormat {
    Jpeg,
    Png,
}

#[frb(mirror(FastCompressSpec))]
pub struct _FastCompressSpec {
    pub compress_format: Option<FastCompressFormat>,
    pub target_width: Option<u32>,
    pub target_height: Option<u32>,
    pub min_width: Option<u32>,
    pub min_height: Option<u32>,
    pub max_width: Option<u32>,
    pub max_height: Option<u32>,
    pub quality: Option<u8>,
}

#[frb(mirror(FastImageFormat))]
pub enum _FastImageFormat {
    Jpeg,
    Png,
    WebP,
    Gif,
    Bmp,
    Other,
}

#[frb(mirror(FastImageProbe))]
pub struct _FastImageProbe {
    pub format: FastImageFormat,
    pub width: u32,
    pub height: u32,
    pub progressive: bool,
    pub region_decodable: bool,
}

#[frb(mirror(FastThumbnailTarget))]
pub struct _FastThumbnailTarget {
    pub width: u32,
    pub output_stem: String,
}

#[frb(mirror(FastImageMeta))]
pub struct _FastImageMeta {
    pub width: u32,
    pub height: u32,
    pub ext: String,
}

#[frb(mirror(FastTilePixels))]
pub struct _FastTilePixels {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub pixel_width: u32,
    pub pixel_height: u32,
    pub rgba: Vec<u8>,
}

pub struct FastTileRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

impl From<&FastTileRect> for crate::codec::Rect {
    fn from(r: &FastTileRect) -> Self {
        Self {
            x: r.x,
            y: r.y,
            w: r.width,
            h: r.height,
        }
    }
}

#[frb(opaque)]
pub struct FastRegionDecoder(crate::codec::RegionDecoder);

impl FastRegionDecoder {
    pub fn open(file_path: String) -> Result<FastRegionDecoder> {
        Ok(FastRegionDecoder(crate::codec::RegionDecoder::open(
            &file_path,
        )?))
    }

    pub fn random_access(&self) -> bool {
        self.0.random_access()
    }

    #[frb(sync)]
    pub fn probe(&self) -> FastImageProbe {
        self.0.probe()
    }

    pub fn decode_tiles(&self, rects: Vec<FastTileRect>, denom: u8) -> Result<Vec<FastTilePixels>> {
        let rects: Vec<crate::codec::Rect> = rects.iter().map(Into::into).collect();
        self.0.decode_tiles(&rects, denom)
    }

    pub fn decode_tile(
        &self,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
        denom: u8,
    ) -> Result<FastTilePixels> {
        self.0.decode_tile(
            crate::codec::Rect {
                x,
                y,
                w: width,
                h: height,
            },
            denom,
        )
    }
}

#[frb(opaque)]
pub struct FastImageCodec {}

impl FastImageCodec {
    pub fn probe(file_path: String) -> Result<FastImageProbe> {
        crate::codec::probe(&file_path)
    }

    pub fn to_baseline_file(file_path: String, output_path: String) -> Result<()> {
        crate::codec::to_baseline_file(&file_path, &output_path)
    }

    pub fn contain_to_file(
        file_path: String,
        output_path: String,
        spec: FastCompressSpec,
    ) -> Result<()> {
        crate::codec::contain_to_file(file_path, output_path, spec)
    }

    pub fn make_thumbnails(
        file_path: String,
        targets: Vec<FastThumbnailTarget>,
        quality: Option<u8>,
    ) -> Result<FastImageMeta> {
        crate::codec::make_thumbnails(&file_path, &targets, quality.unwrap_or(82))
    }
}

#[frb(opaque)]
pub struct FastPngWriter(crate::codec::PngStripeWriter);

impl FastPngWriter {
    pub fn create(output_path: String, width: u32, height: u32) -> Result<FastPngWriter> {
        Ok(FastPngWriter(crate::codec::PngStripeWriter::create(
            &output_path,
            width,
            height,
        )?))
    }

    pub fn push(&mut self, rgba: Vec<u8>) -> Result<()> {
        self.0.push(&rgba)
    }

    pub fn finish(&mut self) -> Result<()> {
        self.0.finish()
    }
}
