use std::fs::File;
use std::sync::Mutex;

use anyhow::{Result, anyhow, bail};
use image::{DynamicImage, metadata::Orientation};
use memmap2::Mmap;

use crate::codec::jpeg_region::JpegRegion;
use crate::codec::png_region::PngRegion;
use crate::codec::turbo::PixelRegion;
use crate::codec::webp_region::WebPRegion;
use crate::codec::{ImageFormat, ImageProbe, swaps_axes};

const BAND_BUDGET_BYTES: usize = 96 * 1024 * 1024;

const BAND_MAX_BYTES: usize = 48 * 1024 * 1024;

pub struct TilePixels {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub pixel_width: u32,
    pub pixel_height: u32,
    pub rgba: Vec<u8>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub x: u32,
    pub y: u32,
    pub w: u32,
    pub h: u32,
}

impl Rect {
    fn right(&self) -> u32 {
        self.x.saturating_add(self.w)
    }

    fn bottom(&self) -> u32 {
        self.y.saturating_add(self.h)
    }

    fn contains(&self, other: &Rect) -> bool {
        other.x >= self.x
            && other.y >= self.y
            && other.right() <= self.right()
            && other.bottom() <= self.bottom()
    }

    fn clamp(self, width: u32, height: u32) -> Rect {
        let x = self.x.min(width);
        let y = self.y.min(height);
        Rect {
            x,
            y,
            w: self.right().min(width).saturating_sub(x),
            h: self.bottom().min(height).saturating_sub(y),
        }
    }
}

fn map_point(orientation: Orientation, width: u32, height: u32, x: u32, y: u32) -> (u32, u32) {
    match orientation {
        Orientation::NoTransforms => (x, y),
        Orientation::FlipHorizontal => (width - 1 - x, y),
        Orientation::FlipVertical => (x, height - 1 - y),
        Orientation::Rotate180 => (width - 1 - x, height - 1 - y),
        Orientation::Rotate90 => (height - 1 - y, x),
        Orientation::Rotate270 => (y, width - 1 - x),
        Orientation::Rotate90FlipH => (y, x),
        Orientation::Rotate270FlipH => (height - 1 - y, width - 1 - x),
    }
}

fn inverse(orientation: Orientation) -> Orientation {
    match orientation {
        Orientation::Rotate90 => Orientation::Rotate270,
        Orientation::Rotate270 => Orientation::Rotate90,
        other => other,
    }
}

fn map_rect(orientation: Orientation, width: u32, height: u32, rect: Rect) -> Rect {
    let (ax, ay) = map_point(orientation, width, height, rect.x, rect.y);
    let (bx, by) = map_point(
        orientation,
        width,
        height,
        rect.right() - 1,
        rect.bottom() - 1,
    );
    let (x0, x1) = (ax.min(bx), ax.max(bx));
    let (y0, y1) = (ay.min(by), ay.max(by));
    Rect {
        x: x0,
        y: y0,
        w: x1 - x0 + 1,
        h: y1 - y0 + 1,
    }
}

struct Band {
    denom: u8,
    region: PixelRegion,
    whole: bool,
}

impl Band {
    fn bytes(&self) -> usize {
        self.region.pixels.len()
    }
}

pub trait RawDecoder: Send + Sync {
    fn format(&self) -> ImageFormat;
    fn raw_size(&self) -> (u32, u32);
    fn orientation(&self) -> Orientation;
    fn progressive(&self) -> bool {
        false
    }
    fn random_access(&self) -> bool {
        false
    }
    fn decode_raw(&self, denom: u8, rect: Rect) -> Result<PixelRegion>;
}

pub struct RegionDecoder {
    backend: Box<dyn RawDecoder>,
    bands: Mutex<Vec<Band>>,
}

impl RegionDecoder {
    pub fn open(file_path: &str) -> Result<Self> {
        let file = File::open(file_path)?;
        let bytes = unsafe { Mmap::map(&file)? };
        let backend: Box<dyn RawDecoder> = match crate::codec::sniff(&bytes) {
            ImageFormat::Jpeg => Box::new(JpegRegion::open(bytes)?),
            ImageFormat::Png => Box::new(PngRegion::open(bytes)?),
            ImageFormat::WebP => Box::new(WebPRegion::open(bytes)?),
            other => bail!("{other:?} is not region-decodable"),
        };
        Ok(Self {
            backend,
            bands: Mutex::new(Vec::new()),
        })
    }

    pub fn random_access(&self) -> bool {
        self.backend.random_access()
    }

    fn swaps(&self) -> bool {
        swaps_axes(self.backend.orientation())
    }

    pub fn upright_size(&self) -> (u32, u32) {
        let (w, h) = self.backend.raw_size();
        if self.swaps() { (h, w) } else { (w, h) }
    }

    pub fn probe(&self) -> ImageProbe {
        let (width, height) = self.upright_size();
        ImageProbe {
            format: self.backend.format(),
            width,
            height,
            progressive: self.backend.progressive(),
            region_decodable: true,
        }
    }

    fn want_for(&self, rect: Rect, denom: u8) -> Result<Rect> {
        let (up_w, up_h) = self.upright_size();
        let rect = rect.clamp(up_w, up_h);
        if rect.w == 0 || rect.h == 0 {
            bail!("empty tile");
        }
        let (raw_w, raw_h) = self.backend.raw_size();
        let raw = map_rect(inverse(self.backend.orientation()), up_w, up_h, rect);
        let d = denom as u32;
        Ok(Rect {
            x: raw.x / d,
            y: raw.y / d,
            w: raw.right().div_ceil(d) - raw.x / d,
            h: raw.bottom().div_ceil(d) - raw.y / d,
        }
        .clamp(scaled_down(raw_w, denom), scaled_down(raw_h, denom)))
    }

    fn finish(&self, want: Rect, slice: Vec<u8>, denom: u8) -> Result<TilePixels> {
        let (raw_w, raw_h) = self.backend.raw_size();
        let d = denom as u32;
        let mut img = DynamicImage::ImageRgba8(
            image::RgbaImage::from_raw(want.w, want.h, slice)
                .ok_or_else(|| anyhow!("tile buffer size mismatch"))?,
        );
        img.apply_orientation(self.backend.orientation());
        let (pixel_width, pixel_height) = (img.width(), img.height());
        let covered_raw = Rect {
            x: want.x * d,
            y: want.y * d,
            w: (want.right() * d).min(raw_w) - want.x * d,
            h: (want.bottom() * d).min(raw_h) - want.y * d,
        };
        let covered = map_rect(self.backend.orientation(), raw_w, raw_h, covered_raw);
        Ok(TilePixels {
            x: covered.x,
            y: covered.y,
            width: covered.w,
            height: covered.h,
            pixel_width,
            pixel_height,
            rgba: img.into_rgba8().into_raw(),
        })
    }

    pub fn decode_tile(&self, rect: Rect, denom: u8) -> Result<TilePixels> {
        let denom = denom.clamp(1, 8);
        let want = self.want_for(rect, denom)?;
        let (scaled_w, scaled_h) = self.scaled_size(denom);
        let slice = self.slice_for(want, denom, scaled_w, scaled_h)?;
        self.finish(want, slice, denom)
    }

    pub fn decode_tiles(&self, rects: &[Rect], denom: u8) -> Result<Vec<TilePixels>> {
        let denom = denom.clamp(1, 8);
        let (scaled_w, scaled_h) = self.scaled_size(denom);
        let wants: Vec<Rect> = rects
            .iter()
            .filter_map(|r| self.want_for(*r, denom).ok())
            .collect();
        if let Some(union) = wants.iter().copied().reduce(union_rect) {
            self.ensure_band(union, denom, scaled_w, scaled_h)?;
        }
        wants
            .into_iter()
            .map(|want| {
                let slice = self.slice_for(want, denom, scaled_w, scaled_h)?;
                self.finish(want, slice, denom)
            })
            .collect()
    }

    fn scaled_size(&self, denom: u8) -> (u32, u32) {
        let (w, h) = self.backend.raw_size();
        (scaled_down(w, denom), scaled_down(h, denom))
    }

    fn ensure_band(&self, rect: Rect, denom: u8, scaled_w: u32, scaled_h: u32) -> Result<()> {
        let rect = rect.clamp(scaled_w, scaled_h);
        if rect.w as usize * rect.h as usize * 4 > BAND_MAX_BYTES {
            return Ok(());
        }
        let mut bands = self
            .bands
            .lock()
            .map_err(|_| anyhow!("band cache poisoned"))?;
        if bands
            .iter()
            .any(|b| b.denom == denom && rect_of(&b.region).contains(&rect))
        {
            return Ok(());
        }
        let whole = rect.x == 0 && rect.y == 0 && rect.w == scaled_w && rect.h == scaled_h;
        let region = self.backend.decode_raw(denom, rect)?;
        bands.push(Band {
            denom,
            region,
            whole,
        });
        trim_bands(&mut bands);
        Ok(())
    }

    fn slice_for(&self, want: Rect, denom: u8, scaled_w: u32, scaled_h: u32) -> Result<Vec<u8>> {
        let mut bands = self
            .bands
            .lock()
            .map_err(|_| anyhow!("band cache poisoned"))?;
        if let Some(band) = bands
            .iter()
            .find(|b| b.denom == denom && rect_of(&b.region).contains(&want))
        {
            return Ok(slice_rgba(&band.region, want));
        }
        let whole_rect = Rect {
            x: 0,
            y: 0,
            w: scaled_w,
            h: scaled_h,
        };
        let band_rect = if whole_rect.w as usize * whole_rect.h as usize * 4 <= BAND_MAX_BYTES {
            whole_rect
        } else if self.swaps() {
            Rect {
                x: want.x,
                y: 0,
                w: want.w,
                h: scaled_h,
            }
        } else {
            Rect {
                x: 0,
                y: want.y,
                w: scaled_w,
                h: want.h,
            }
        };
        let band_bytes = band_rect.w as usize * band_rect.h as usize * 4;
        if band_bytes > BAND_MAX_BYTES {
            let region = self.backend.decode_raw(denom, want)?;
            return Ok(slice_rgba(&region, want));
        }
        let region = self.backend.decode_raw(denom, band_rect)?;
        let out = slice_rgba(&region, want);
        bands.push(Band {
            denom,
            region,
            whole: band_rect == whole_rect,
        });
        trim_bands(&mut bands);
        Ok(out)
    }
}

fn trim_bands(bands: &mut Vec<Band>) {
    let pinned = bands.iter().filter(|b| b.whole).map(|b| b.denom).max();
    let mut total: usize = bands.iter().map(Band::bytes).sum();
    while total > BAND_BUDGET_BYTES {
        let Some(i) = bands
            .iter()
            .position(|b| !(b.whole && Some(b.denom) == pinned))
        else {
            break;
        };
        total -= bands.remove(i).bytes();
    }
}

fn scaled_down(dim: u32, denom: u8) -> u32 {
    dim.div_ceil(denom.max(1) as u32)
}

fn union_rect(a: Rect, b: Rect) -> Rect {
    let x = a.x.min(b.x);
    let y = a.y.min(b.y);
    Rect {
        x,
        y,
        w: a.right().max(b.right()) - x,
        h: a.bottom().max(b.bottom()) - y,
    }
}

fn rect_of(region: &PixelRegion) -> Rect {
    Rect {
        x: region.x,
        y: region.y,
        w: region.width,
        h: region.height,
    }
}

fn slice_rgba(region: &PixelRegion, want: Rect) -> Vec<u8> {
    let stride = region.width as usize * 4;
    let mut out = Vec::with_capacity(want.w as usize * want.h as usize * 4);
    for row in 0..want.h as usize {
        let src_row = (want.y - region.y) as usize + row;
        let start = src_row * stride + (want.x - region.x) as usize * 4;
        out.extend_from_slice(&region.pixels[start..start + want.w as usize * 4]);
    }
    out
}

#[cfg(test)]
mod tests {
    use image::{ExtendedColorType, ImageEncoder, metadata::Orientation};

    use super::{Rect, RegionDecoder, inverse, map_rect};

    fn exif(orientation: u8) -> Vec<u8> {
        vec![
            b'I',
            b'I',
            0x2a,
            0x00,
            0x08,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x12,
            0x01,
            0x03,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            orientation,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
        ]
    }

    fn gradient(width: u32, height: u32) -> image::RgbImage {
        image::RgbImage::from_fn(width, height, |x, y| {
            let r = (x * 255 / width.max(1)) as u8;
            let g = (y * 255 / height.max(1)) as u8;
            let b = if x < width / 3 && y < height / 4 {
                230
            } else {
                30
            };
            image::Rgb([r, g, b])
        })
    }

    fn write_jpeg(path: &std::path::Path, img: &image::RgbImage, orientation: u8) {
        let mut file = std::fs::File::create(path).unwrap();
        let mut enc = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut file, 95);
        enc.set_exif_metadata(exif(orientation)).unwrap();
        enc.write_image(
            img.as_raw(),
            img.width(),
            img.height(),
            ExtendedColorType::Rgb8,
        )
        .unwrap();
    }

    #[test]
    fn map_rect_round_trips_through_inverse() {
        let (w, h) = (200, 120);
        let rect = Rect {
            x: 37,
            y: 20,
            w: 64,
            h: 50,
        };
        for o in [
            Orientation::NoTransforms,
            Orientation::FlipHorizontal,
            Orientation::FlipVertical,
            Orientation::Rotate180,
            Orientation::Rotate90,
            Orientation::Rotate270,
            Orientation::Rotate90FlipH,
            Orientation::Rotate270FlipH,
        ] {
            let mapped = map_rect(o, w, h, rect);
            let (mw, mh) = if super::swaps_axes(o) { (h, w) } else { (w, h) };
            assert_eq!(map_rect(inverse(o), mw, mh, mapped), rect, "{o:?}");
        }
    }

    #[test]
    fn tile_matches_full_decode_for_every_orientation() {
        let dir = std::env::temp_dir().join("moodiary_img_region_test");
        std::fs::create_dir_all(&dir).unwrap();
        let src_img = gradient(200, 120);
        for orientation in 1..=8u8 {
            let path = dir.join(format!("o{orientation}.jpg"));
            write_jpeg(&path, &src_img, orientation);

            let decoder = RegionDecoder::open(&path.to_string_lossy()).unwrap();
            let (up_w, up_h) = decoder.upright_size();
            let reference = crate::codec::decode_upright(&path.to_string_lossy())
                .unwrap()
                .into_rgba8();
            assert_eq!(reference.dimensions(), (up_w, up_h), "o{orientation}");

            let want = Rect {
                x: 37,
                y: 20,
                w: 64,
                h: 50,
            };
            let tile = decoder.decode_tile(want, 1).unwrap();
            assert!(
                tile.x <= want.x
                    && tile.y <= want.y
                    && tile.x + tile.width >= want.x + want.w
                    && tile.y + tile.height >= want.y + want.h,
                "o{orientation}: 覆盖矩形应包住请求 {:?}",
                (tile.x, tile.y, tile.width, tile.height)
            );
            assert_eq!(
                (tile.pixel_width, tile.pixel_height),
                (tile.width, tile.height)
            );
            let mut worst = 0i32;
            for ty in 0..tile.height {
                for tx in 0..tile.width {
                    let i = ((ty * tile.width + tx) * 4) as usize;
                    let r = reference.get_pixel(tile.x + tx, tile.y + ty).0;
                    for (got, want) in tile.rgba[i..i + 3].iter().zip(&r[..3]) {
                        worst = worst.max((*got as i32 - *want as i32).abs());
                    }
                }
            }
            assert!(worst <= 12, "o{orientation}: 最大色差 {worst}");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn batched_tiles_share_one_band() {
        let dir = std::env::temp_dir().join("moodiary_img_region_batch_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("src.jpg");
        write_jpeg(&path, &gradient(900, 700), 6);
        let decoder = RegionDecoder::open(&path.to_string_lossy()).unwrap();
        let rects = [
            Rect {
                x: 0,
                y: 0,
                w: 256,
                h: 256,
            },
            Rect {
                x: 256,
                y: 0,
                w: 256,
                h: 256,
            },
            Rect {
                x: 0,
                y: 256,
                w: 256,
                h: 256,
            },
            Rect {
                x: 256,
                y: 256,
                w: 256,
                h: 256,
            },
        ];
        let batch = decoder.decode_tiles(&rects, 1).unwrap();
        assert_eq!(decoder.bands.lock().unwrap().len(), 1, "并集一条带");
        let single: Vec<_> = rects
            .iter()
            .map(|r| decoder.decode_tile(*r, 1).unwrap())
            .collect();
        for (a, b) in batch.iter().zip(&single) {
            assert_eq!((a.x, a.y, a.width, a.height), (b.x, b.y, b.width, b.height));
            assert_eq!(a.rgba, b.rgba);
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn scaled_tile_and_band_reuse() {
        let dir = std::env::temp_dir().join("moodiary_img_region_scale_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("src.jpg");
        write_jpeg(&path, &gradient(640, 400), 1);
        let decoder = RegionDecoder::open(&path.to_string_lossy()).unwrap();

        let a = decoder
            .decode_tile(
                Rect {
                    x: 0,
                    y: 100,
                    w: 256,
                    h: 128,
                },
                2,
            )
            .unwrap();
        assert_eq!((a.pixel_width, a.pixel_height), (a.width / 2, a.height / 2));
        assert_eq!(decoder.bands.lock().unwrap().len(), 1);

        let b = decoder
            .decode_tile(
                Rect {
                    x: 256,
                    y: 100,
                    w: 256,
                    h: 128,
                },
                2,
            )
            .unwrap();
        assert_eq!(b.x, 256);
        assert_eq!(decoder.bands.lock().unwrap().len(), 1, "同一行应复用带");

        let _ = std::fs::remove_dir_all(&dir);
    }
}
