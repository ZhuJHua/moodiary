//! JPEG 的区域解码后端：turbojpeg 裁剪 + 缩放，有对齐 restart marker 时走 [`RestartIndex`]
//! 随机访问并行解。

use std::sync::OnceLock;

use anyhow::{Result, bail};
use image::metadata::Orientation;
use memmap2::Mmap;

use crate::region::{RawDecoder, Rect};
use crate::restart::{self, RestartIndex};
use crate::turbo::{self, JpegHeader, PixelRegion};
use crate::{ImageFormat, image_header};

pub struct JpegRegion {
    /// mmap：313MB 的原图不整个读进内存，turbojpeg 按需翻页。
    bytes: Mmap,
    header: JpegHeader,
    orientation: Orientation,
    /// restart marker 索引，第一次解码时才扫（313MB 扫一遍要几十毫秒，open 是同步的）。
    index: OnceLock<Option<RestartIndex>>,
}

impl JpegRegion {
    pub fn open(bytes: Mmap) -> Result<Self> {
        let header = turbo::read_header(&bytes)?;
        if !header.region_decodable() {
            bail!("JPEG is not region-decodable");
        }
        let (_, _, orientation) = image_header(&bytes)?;
        Ok(Self {
            bytes,
            header,
            orientation,
            index: OnceLock::new(),
        })
    }

    fn index(&self) -> Option<&RestartIndex> {
        self.index
            .get_or_init(|| RestartIndex::build(&self.bytes))
            .as_ref()
    }
}

impl RawDecoder for JpegRegion {
    fn format(&self) -> ImageFormat {
        ImageFormat::Jpeg
    }

    fn raw_size(&self) -> (u32, u32) {
        (self.header.width, self.header.height)
    }

    fn orientation(&self) -> Orientation {
        self.orientation
    }

    fn progressive(&self) -> bool {
        self.header.progressive
    }

    fn random_access(&self) -> bool {
        self.index().is_some()
    }

    /// 有 restart 索引只解覆盖它的段，否则整趟。
    fn decode_raw(&self, denom: u8, rect: Rect) -> Result<PixelRegion> {
        let region = match self.index() {
            Some(index) => index.decode(
                &self.bytes,
                turbo::numerator(denom)?,
                rect,
                true,
                restart::threads(),
            ),
            None => turbo::decode_region(&self.bytes, denom, rect),
        }?;
        // 熵解码把映射的文件页摸了一遍，解完立刻还给内核：页缓存里还在，下次再摸是软缺页，
        // 但不再算在本进程头上。
        let _ = unsafe {
            self.bytes
                .unchecked_advise(memmap2::UncheckedAdvice::DontNeed)
        };
        Ok(region)
    }
}
