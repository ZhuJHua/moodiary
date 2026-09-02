use anyhow::Result;
use flutter_rust_bridge::frb;

pub use moodiary_image::{
    CompressFormat, CompressSpec, ImageFormat, ImageMeta, ImageProbe, ThumbnailTarget, TilePixels,
};

#[frb(mirror(CompressFormat))]
pub enum _CompressFormat {
    Jpeg,
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

#[frb(mirror(ImageFormat))]
pub enum _ImageFormat {
    Jpeg,
    Png,
    WebP,
    Gif,
    Bmp,
    Other,
}

#[frb(mirror(ImageProbe))]
pub struct _ImageProbe {
    pub format: ImageFormat,
    pub width: u32,
    pub height: u32,
    pub progressive: bool,
    pub region_decodable: bool,
}

#[frb(mirror(ThumbnailTarget))]
pub struct _ThumbnailTarget {
    pub width: u32,
    pub output_stem: String,
}

#[frb(mirror(ImageMeta))]
pub struct _ImageMeta {
    pub width: u32,
    pub height: u32,
    pub ext: String,
}

#[frb(mirror(TilePixels))]
pub struct _TilePixels {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub pixel_width: u32,
    pub pixel_height: u32,
    pub rgba: Vec<u8>,
}

/// 转正后源像素坐标里的一个 tile 矩形。
pub struct TileRect {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
}

impl From<&TileRect> for moodiary_image::Rect {
    fn from(r: &TileRect) -> Self {
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
pub struct RegionDecoder(moodiary_image::RegionDecoder);

impl RegionDecoder {
    pub fn open(file_path: String) -> Result<RegionDecoder> {
        Ok(RegionDecoder(moodiary_image::RegionDecoder::open(
            &file_path,
        )?))
    }

    /// 文件带对齐的 restart marker：tile 只解覆盖它的段、还能并行。第一次调用会扫一遍文件。
    pub fn random_access(&self) -> bool {
        self.0.random_access()
    }

    #[frb(sync)]
    pub fn probe(&self) -> ImageProbe {
        self.0.probe()
    }

    /// 一批同 denom 的 tile：并集一次解出来当带，再逐块切。视口里的可见 tile 一次全要，
    /// 313MB 的图就只跑一趟熵解码。
    pub fn decode_tiles(&self, rects: Vec<TileRect>, denom: u8) -> Result<Vec<TilePixels>> {
        let rects: Vec<moodiary_image::Rect> = rects.iter().map(Into::into).collect();
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
    ) -> Result<TilePixels> {
        self.0.decode_tile(
            moodiary_image::Rect {
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
pub struct ImageCompressor {}

impl ImageCompressor {
    /// 只读头不解像素：格式、转正后宽高、是否能走 turbojpeg 缩放 / 区域解码。
    pub fn probe(file_path: String) -> Result<ImageProbe> {
        moodiary_image::probe(&file_path)
    }

    /// progressive JPEG 无损转 baseline（带 restart marker）落盘，给看图页 tile 用；
    /// 超过 64MP 的报错（要整幅系数缓冲）。先写 `.part` 再 rename。
    pub fn to_baseline_file(file_path: String, output_path: String) -> Result<()> {
        moodiary_image::to_baseline_file(&file_path, &output_path)
    }

    /// 导出用：整图转正、按 spec 定尺寸、编成 JPEG / PNG。
    pub fn contain_to_file(
        file_path: String,
        output_path: String,
        spec: CompressSpec,
    ) -> Result<()> {
        moodiary_image::contain_to_file(file_path, output_path, spec)
    }

    /// 一次解码、链式缩出多个宽度档位；不比档位宽的档位跳过不写。派生物后缀按内容定
    /// （`jpg`，带 alpha 的源 `png`），写在返回的 `ext` 里。
    pub fn make_thumbnails(
        file_path: String,
        targets: Vec<ThumbnailTarget>,
        quality: Option<u8>,
    ) -> Result<ImageMeta> {
        moodiary_image::make_thumbnails(&file_path, &targets, quality.unwrap_or(82))
    }
}
