use std::sync::OnceLock;

use anyhow::{Result, bail};
use image::metadata::Orientation;
use memmap2::Mmap;

use crate::codec::region::{RawDecoder, Rect};
use crate::codec::restart::{self, RestartIndex};
use crate::codec::turbo::{self, JpegHeader, PixelRegion};
use crate::codec::{ImageFormat, image_header};

pub struct JpegRegion {
    bytes: Mmap,
    header: JpegHeader,
    orientation: Orientation,
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
        // DontNeed 只让页不再计入本进程 RSS，页缓存仍在，下次访问是软缺页
        let _ = unsafe {
            self.bytes
                .unchecked_advise(memmap2::UncheckedAdvice::DontNeed)
        };
        Ok(region)
    }
}
