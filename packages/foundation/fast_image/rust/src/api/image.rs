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

/// 转正后源像素坐标里的一个 tile 矩形。
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

/// 看图页的 tile 解码器：一个看图会话一个，文件只读一次，带缓存跟着它走。
#[frb(opaque)]
pub struct FastRegionDecoder(crate::codec::RegionDecoder);

impl FastRegionDecoder {
    pub fn open(file_path: String) -> Result<FastRegionDecoder> {
        Ok(FastRegionDecoder(crate::codec::RegionDecoder::open(
            &file_path,
        )?))
    }

    /// 文件带对齐的 restart marker：tile 只解覆盖它的段、还能并行。第一次调用会扫一遍文件。
    pub fn random_access(&self) -> bool {
        self.0.random_access()
    }

    #[frb(sync)]
    pub fn probe(&self) -> FastImageProbe {
        self.0.probe()
    }

    /// 一批同 denom 的 tile：并集一次解出来当带，再逐块切。视口里的可见 tile 一次全要，
    /// 313MB 的图就只跑一趟熵解码。
    pub fn decode_tiles(&self, rects: Vec<FastTileRect>, denom: u8) -> Result<Vec<FastTilePixels>> {
        let rects: Vec<crate::codec::Rect> = rects.iter().map(Into::into).collect();
        self.0.decode_tiles(&rects, denom)
    }

    /// `x/y/width/height` 是转正后源像素坐标，`denom` 是 1..=8 的缩放分母。
    /// 返回实际覆盖的矩形（对齐 iMCU 后可能比请求大）与转正后的 RGBA。
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
    /// 只读头不解像素：格式、转正后宽高、是否能走 turbojpeg 缩放 / 区域解码。
    pub fn probe(file_path: String) -> Result<FastImageProbe> {
        crate::codec::probe(&file_path)
    }

    /// progressive JPEG 无损转 baseline（带 restart marker）落盘，给看图页 tile 用；
    /// 超过 64MP 的报错（要整幅系数缓冲）。先写 `.part` 再 rename。
    pub fn to_baseline_file(file_path: String, output_path: String) -> Result<()> {
        crate::codec::to_baseline_file(&file_path, &output_path)
    }

    /// 导出用：整图转正、按 spec 定尺寸、编成 JPEG / PNG。
    pub fn contain_to_file(
        file_path: String,
        output_path: String,
        spec: FastCompressSpec,
    ) -> Result<()> {
        crate::codec::contain_to_file(file_path, output_path, spec)
    }

    /// 一次解码、链式缩出多个宽度档位；不比档位宽的档位跳过不写。派生物后缀按内容定
    /// （`jpg`，带 alpha 的源 `png`），写在返回的 `ext` 里。
    pub fn make_thumbnails(
        file_path: String,
        targets: Vec<FastThumbnailTarget>,
        quality: Option<u8>,
    ) -> Result<FastImageMeta> {
        crate::codec::make_thumbnails(&file_path, &targets, quality.unwrap_or(82))
    }
}
