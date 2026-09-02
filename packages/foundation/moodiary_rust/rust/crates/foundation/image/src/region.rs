//! 看图页的 tile 解码：一个看图会话一个 [`RegionDecoder`]，文件只读一次；tile 用**转正后**的
//! 源像素坐标请求，内部按 EXIF 方向映射回原始朝向，只解那一块，解完再把小块转正。
//!
//! 格式差异全部收在 [`RawDecoder`] 后面（JPEG 走 turbojpeg 裁剪 + restart 随机访问，PNG 流式
//! 逐行、WebP 走 libwebp 裁剪），这层只管坐标映射与**带缓存**：tile 模型参考 pixa（2 的幂
//! sampleSize、512 源像素 tile、按距离排序），但串行码流跳过的行照样要解，同一行的 12 个 tile
//! 就是 12 趟；所以一次解整条带（未旋转的图是「全宽 × tile 高」，旋转过的图是「全高 × tile
//! 宽」，都对应上层的一行 tile），后续同一行的 tile 直接从带里切，一行一趟。

use std::fs::File;
use std::sync::Mutex;

use anyhow::{Result, anyhow, bail};
use image::{DynamicImage, metadata::Orientation};
use memmap2::Mmap;

use crate::jpeg_region::JpegRegion;
use crate::png_region::PngRegion;
use crate::turbo::PixelRegion;
use crate::webp_region::WebPRegion;
use crate::{ImageFormat, ImageProbe, swaps_axes};

/// 缓存的带最多占这么多字节。整图带（fit 比例那条）不参与淘汰：缩回去要再用，重解是一趟
/// 全图熵解码。
const BAND_BUDGET_BYTES: usize = 96 * 1024 * 1024;

/// 单条带超过这个字节数就不缓存，只解请求的那一块。fit 比例下整张缩放图放得下就整张当一条带
/// （24000² 的图解 1/8 是 3000²、36MB，一趟熵解码出全部 tile）；放不下退回一行一带；再放不下
/// （24000 宽在 1/1 下一行就是 49MB）才逐块解，那是 JPEG 没有随机访问的代价。
const BAND_MAX_BYTES: usize = 48 * 1024 * 1024;

/// 一块解出来的 tile：`x/y/width/height` 是它实际覆盖的**转正后源像素**矩形（对齐 iMCU 后
/// 可能比请求的大），`pixel_width/height` 是 RGBA 的像素尺寸（= 覆盖矩形 / denom）。
pub struct TilePixels {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub pixel_width: u32,
    pub pixel_height: u32,
    pub rgba: Vec<u8>,
}

/// 整数矩形 `[x, x+w) × [y, y+h)`。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub x: u32,
    pub y: u32,
    pub w: u32,
    pub h: u32,
}

impl Rect {
    fn right(&self) -> u32 {
        self.x + self.w
    }

    fn bottom(&self) -> u32 {
        self.y + self.h
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

/// image crate 的 `apply_orientation` 语义：原始像素 (x, y) 在 `width × height` 的图上，
/// 转正后落到哪。8 种方向都是轴对齐变换，矩形只要映两个对角。
fn map_point(orientation: Orientation, width: u32, height: u32, x: u32, y: u32) -> (u32, u32) {
    match orientation {
        Orientation::NoTransforms => (x, y),
        Orientation::FlipHorizontal => (width - 1 - x, y),
        Orientation::FlipVertical => (x, height - 1 - y),
        Orientation::Rotate180 => (width - 1 - x, height - 1 - y),
        Orientation::Rotate90 => (height - 1 - y, x),
        Orientation::Rotate270 => (y, width - 1 - x),
        // rotate90 再水平翻 = 转置。
        Orientation::Rotate90FlipH => (y, x),
        // rotate270 再水平翻 = 反转置。
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

/// 把 `width × height` 图上的矩形按方向映过去（非空矩形）。
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
    /// 覆盖整张缩放图的带，钉住不淘汰。
    whole: bool,
}

impl Band {
    fn bytes(&self) -> usize {
        self.region.pixels.len()
    }
}

/// 一种格式的区域解码：只认**原始朝向**、缩放后的坐标，返回的块要覆盖请求（对齐后可以更大）。
pub trait RawDecoder: Send + Sync {
    fn format(&self) -> ImageFormat;
    /// 原始朝向的尺寸。
    fn raw_size(&self) -> (u32, u32);
    fn orientation(&self) -> Orientation;
    fn progressive(&self) -> bool {
        false
    }
    /// 能随机访问：解一块的代价只与块有关，不与它上方的数据量有关。
    fn random_access(&self) -> bool {
        false
    }
    /// 按 1/`denom`（1 / 2 / 4 / 8）缩放，解缩放坐标系里的 `rect`，RGBA。
    fn decode_raw(&self, denom: u8, rect: Rect) -> Result<PixelRegion>;
}

pub struct RegionDecoder {
    backend: Box<dyn RawDecoder>,
    bands: Mutex<Vec<Band>>,
}

impl RegionDecoder {
    pub fn open(file_path: &str) -> Result<Self> {
        let file = File::open(file_path)?;
        // 原件不可变（这是全库的约定），映射期间不会被改写。
        let bytes = unsafe { Mmap::map(&file)? };
        let backend: Box<dyn RawDecoder> = match crate::sniff(&bytes) {
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

    /// 文件能随机访问（JPEG 带对齐的 restart marker 等）：解一块的代价只与块有关。
    pub fn random_access(&self) -> bool {
        self.backend.random_access()
    }

    fn swaps(&self) -> bool {
        swaps_axes(self.backend.orientation())
    }

    /// 转正后的尺寸。
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

    /// 转正坐标的 tile 矩形 → 缩放后原始朝向坐标的矩形（`want`）。
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

    /// 切好的原始朝向小块 → 转正 + 覆盖矩形换算。
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

    /// 解一块 tile。`rect` 是转正后的源像素矩形，`denom` 是 1 / 2 / 4 / 8。
    pub fn decode_tile(&self, rect: Rect, denom: u8) -> Result<TilePixels> {
        let denom = denom.clamp(1, 8);
        let want = self.want_for(rect, denom)?;
        let (scaled_w, scaled_h) = self.scaled_size(denom);
        let slice = self.slice_for(want, denom, scaled_w, scaled_h)?;
        self.finish(want, slice, denom)
    }

    /// 一批 tile（同一 denom）：先把它们的并集当一条带一次解出来（放得下的话），再逐块切。
    /// 视口跨几行 tile 就省几趟熵解码 —— 313MB 的图一趟就是两三秒，系统相册用
    /// `BitmapRegionDecoder` 也是整个可见区域一次解。
    pub fn decode_tiles(&self, rects: &[Rect], denom: u8) -> Result<Vec<TilePixels>> {
        let denom = denom.clamp(1, 8);
        let (scaled_w, scaled_h) = self.scaled_size(denom);
        let wants = rects
            .iter()
            .map(|r| self.want_for(*r, denom))
            .collect::<Result<Vec<_>>>()?;
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

    /// 没有覆盖 `rect` 的带、且它放得下时，把它当一条带解出来缓存。放不下就什么都不做，
    /// 交给 [`slice_for`] 的行带 / 逐块路径。
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

    /// 从缓存带里切出 `want`；没有覆盖它的带就解一条新带（放得下就缓存），或直接解这一块。
    /// 整段持锁：上层两路并发请求同一行的两块时，第二路等第一路把带解完再切，而不是各解一条。
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
        // 整张缩放图放得下就整张当一条带（fit 比例下一趟熵解码出全部 tile）。否则带的走向
        // 跟上层 tile 行一致：没旋转的图一行 tile 是原始坐标的一横条，转了 90° 的图一行 tile
        // 是原始坐标的一竖条。
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

/// 超预算时从最老的开始淘汰，整图带不动。
fn trim_bands(bands: &mut Vec<Band>) {
    let mut total: usize = bands.iter().map(Band::bytes).sum();
    while total > BAND_BUDGET_BYTES {
        let Some(i) = bands.iter().position(|b| !b.whole) else {
            break;
        };
        total -= bands.remove(i).bytes();
    }
}

/// 1/`denom` 缩放后的尺寸（libjpeg 口径，向上取整）。
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

/// 从 `region` 里切出 `want`（`region` 必须覆盖 `want`）。
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

    /// EXIF Orientation 1..=8 的最小 TIFF。
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

    /// 平滑渐变 + 一个色块，方向搞错了立刻能看出来。
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

    /// 八种 EXIF 方向：tile 解出来的像素与「整图解码转正后裁同一块」一致。
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
            // 参照物必须转正：`image::open` 不看 EXIF。
            let reference = crate::decode_upright(&path.to_string_lossy())
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
            // 两个解码器（turbojpeg / zune-jpeg）的 IDCT 与上采样实现不同，允许几个灰阶。
            assert!(worst <= 12, "o{orientation}: 最大色差 {worst}");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 一批 tile 合成一条带一次解：结果与逐块解一致，且只多一条带。
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

    /// 1/2 缩放：像素尺寸减半，覆盖矩形仍按全分辨率给；第二块同一行走带缓存。
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
