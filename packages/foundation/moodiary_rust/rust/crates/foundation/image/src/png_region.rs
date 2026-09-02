//! PNG 的区域解码后端：zlib 是串行的、每行滤波依赖上一行，没有随机访问；这里流式逐行解，
//! 窗口之上的行解完就丢，窗口内的行按 1/denom 盒式降采样后累进输出。内存 = 一行 + 输出块，
//! CPU 与「窗口底部以上的行数」成正比，同没有 restart marker 的 JPEG。
//!
//! Adam7 隔行的文件 `png` crate 不按整行吐（逐 pass 给子行），要整幅缓冲才能还原，这里不接，
//! 由上层退回引擎封顶路径。APNG 只解第一帧。

use std::io::Cursor;

use anyhow::{Result, anyhow, bail};
use image::metadata::Orientation;
use memmap2::Mmap;
use png::{BitDepth, ColorType, Decoder, Transformations};

use crate::region::{RawDecoder, Rect};
use crate::turbo::PixelRegion;
use crate::{ImageFormat, image_header};

pub struct PngRegion {
    bytes: Mmap,
    width: u32,
    height: u32,
    orientation: Orientation,
}

/// 源图像素数上限。没有随机访问，每条带都要从第一行 inflate 到带底：100MP 的 RGBA 一趟约
/// 400MB 的解压，已经是一秒量级；再大的交给引擎整解封顶，一次解完不再重复。
const MAX_PIXELS: u64 = 100_000_000;

fn accepts(info: &png::Info<'_>) -> bool {
    !info.interlaced && info.width as u64 * info.height as u64 <= MAX_PIXELS
}

/// 头一眼能判定的：不是 Adam7 隔行、像素数在上限内。
pub fn region_decodable(bytes: &[u8]) -> bool {
    Decoder::new(Cursor::new(bytes))
        .read_info()
        .is_ok_and(|r| accepts(r.info()))
}

impl PngRegion {
    pub fn open(bytes: Mmap) -> Result<Self> {
        let reader = Decoder::new(Cursor::new(&bytes[..])).read_info()?;
        let info = reader.info();
        if !accepts(info) {
            bail!("PNG is not region-decodable (interlaced or too large)");
        }
        let (width, height) = (info.width, info.height);
        drop(reader);
        let (_, _, orientation) = image_header(&bytes)?;
        Ok(Self {
            bytes,
            width,
            height,
            orientation,
        })
    }
}

impl RawDecoder for PngRegion {
    fn format(&self) -> ImageFormat {
        ImageFormat::Png
    }

    fn raw_size(&self) -> (u32, u32) {
        (self.width, self.height)
    }

    fn orientation(&self) -> Orientation {
        self.orientation
    }

    fn decode_raw(&self, denom: u8, rect: Rect) -> Result<PixelRegion> {
        let d = match denom {
            1 | 2 | 4 | 8 => denom as u32,
            _ => bail!("unsupported scale denominator {denom}"),
        };
        let shift = d.trailing_zeros();
        let scaled_w = self.width.div_ceil(d);
        let scaled_h = self.height.div_ceil(d);
        let right = (rect.x + rect.w).min(scaled_w);
        let bottom = (rect.y + rect.h).min(scaled_h);
        if rect.x >= right || rect.y >= bottom {
            bail!("empty region");
        }
        let (out_w, out_h) = (right - rect.x, bottom - rect.y);
        // 源像素窗口。
        let (x0, x1) = (rect.x * d, (right * d).min(self.width));
        let (y0, y1) = (rect.y * d, (bottom * d).min(self.height));

        let mut decoder = Decoder::new(Cursor::new(&self.bytes[..]));
        // 不用 STRIP_16：它是截断（v >> 8），而缩略图那条路（image 的 into_rgba8）是四舍五入，
        // 16 位源两层会差一个灰阶。这里自己按 16 位读、四舍五入。
        decoder.set_transformations(Transformations::EXPAND | Transformations::ALPHA);
        decoder.set_ignore_text_chunk(true);
        decoder.ignore_checksums(true);
        let mut reader = decoder.read_info()?;
        // ALPHA 之后只剩两种：RGBA，或灰度 + alpha（png 不会把灰扩成 RGB）。
        let (color, depth) = reader.output_color_type();
        let gray = match color {
            ColorType::Rgba => false,
            ColorType::GrayscaleAlpha => true,
            other => bail!("unexpected PNG output color type {other:?}"),
        };
        let wide = match depth {
            BitDepth::Eight => false,
            BitDepth::Sixteen => true,
            other => bail!("unexpected PNG output bit depth {other:?}"),
        };
        let layout = Layout {
            gray,
            wide,
            bytes_per_pixel: (if gray { 2 } else { 4 }) * if wide { 2 } else { 1 },
        };

        let mut pixels = Vec::with_capacity(out_w as usize * out_h as usize * 4);
        let mut acc = vec![0u32; out_w as usize * 4];
        let mut rows_in_block = 0u32;
        let mut y = 0u32;
        while y < y1 {
            let Some(row) = reader.next_row()? else {
                bail!("PNG ended at row {y} of {}", self.height);
            };
            if y >= y0 {
                let data = row.data();
                if d == 1 {
                    push_row(&mut pixels, data, x0, x1, layout);
                } else {
                    accumulate(&mut acc, data, x0, x1, shift, layout);
                    rows_in_block += 1;
                    if rows_in_block == d || y + 1 == y1 {
                        flush_block(&mut pixels, &mut acc, rows_in_block, x0, x1, d);
                        rows_in_block = 0;
                    }
                }
            }
            y += 1;
        }
        if pixels.len() != out_w as usize * out_h as usize * 4 {
            return Err(anyhow!("PNG region buffer size mismatch"));
        }
        Ok(PixelRegion {
            x: rect.x,
            y: rect.y,
            width: out_w,
            height: out_h,
            channels: 4,
            pixels,
        })
    }
}

/// 解出来的行长什么样：灰 + alpha 还是 RGBA，8 位还是 16 位。
#[derive(Clone, Copy)]
struct Layout {
    gray: bool,
    wide: bool,
    bytes_per_pixel: usize,
}

impl Layout {
    /// 一个像素的 RGBA8。16 位四舍五入到 8 位（与 image 的 `into_rgba8` 同一口径）。
    #[inline]
    fn rgba(self, px: &[u8]) -> [u8; 4] {
        let sample = |i: usize| -> u8 {
            if self.wide {
                let v = u16::from_be_bytes([px[i * 2], px[i * 2 + 1]]) as u32;
                ((v * 255 + 32767) / 65535) as u8
            } else {
                px[i]
            }
        };
        if self.gray {
            let g = sample(0);
            [g, g, g, sample(1)]
        } else {
            [sample(0), sample(1), sample(2), sample(3)]
        }
    }
}

fn push_row(out: &mut Vec<u8>, data: &[u8], x0: u32, x1: u32, layout: Layout) {
    let bpp = layout.bytes_per_pixel;
    let row = &data[x0 as usize * bpp..x1 as usize * bpp];
    if !layout.gray && !layout.wide {
        out.extend_from_slice(row);
        return;
    }
    for px in row.chunks_exact(bpp) {
        out.extend_from_slice(&layout.rgba(px));
    }
}

fn accumulate(acc: &mut [u32], data: &[u8], x0: u32, x1: u32, shift: u32, layout: Layout) {
    let bpp = layout.bytes_per_pixel;
    let row = &data[x0 as usize * bpp..x1 as usize * bpp];
    for (i, px) in row.chunks_exact(bpp).enumerate() {
        let o = (i >> shift) * 4;
        let rgba = layout.rgba(px);
        acc[o] += rgba[0] as u32;
        acc[o + 1] += rgba[1] as u32;
        acc[o + 2] += rgba[2] as u32;
        acc[o + 3] += rgba[3] as u32;
    }
}

/// 把累加好的 `rows` 行 × d 列的块平均成一行输出；右边缘的块列数不足 d 按实际算。
fn flush_block(out: &mut Vec<u8>, acc: &mut [u32], rows: u32, x0: u32, x1: u32, d: u32) {
    let out_w = acc.len() / 4;
    for ox in 0..out_w {
        let cols = d.min(x1 - (x0 + ox as u32 * d));
        let n = (rows * cols).max(1);
        for c in 0..4 {
            out.push(((acc[ox * 4 + c] + n / 2) / n) as u8);
        }
    }
    acc.fill(0);
}

#[cfg(test)]
mod tests {
    use image::DynamicImage;
    use memmap2::Mmap;

    use super::PngRegion;
    use crate::region::{RawDecoder, Rect};

    fn noisy(width: u32, height: u32) -> image::RgbaImage {
        let mut seed = 0x1234_5678u32;
        image::RgbaImage::from_fn(width, height, |x, y| {
            seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
            let n = (seed >> 24) as u8;
            image::Rgba([
                ((x * 255 / width) as u8).wrapping_add(n / 4),
                ((y * 255 / height) as u8).wrapping_add(n / 3),
                n,
                200u8.wrapping_add(n / 8),
            ])
        })
    }

    /// 真 16 位样本：低字节不是高字节的复制，截断与四舍五入会分道扬镳。
    fn noisy16(width: u32, height: u32) -> image::ImageBuffer<image::Rgba<u16>, Vec<u16>> {
        let mut seed = 0xBEEF_CAFEu32;
        image::ImageBuffer::from_fn(width, height, |x, y| {
            seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
            image::Rgba([
                ((x * 65535 / width) as u16).wrapping_add((seed >> 16) as u16),
                ((y * 65535 / height) as u16).wrapping_add((seed >> 8) as u16),
                seed as u16,
                65535u16.wrapping_sub((seed >> 20) as u16 & 0x0FFF),
            ])
        })
    }

    fn write(dir: &std::path::Path, name: &str, img: &DynamicImage) -> std::path::PathBuf {
        let path = dir.join(name);
        img.save(&path).unwrap();
        path
    }

    fn open(path: &std::path::Path) -> PngRegion {
        let file = std::fs::File::open(path).unwrap();
        PngRegion::open(unsafe { Mmap::map(&file).unwrap() }).unwrap()
    }

    /// 参考：整图 RGBA 上按同一套盒式平均算出的块。
    fn reference(full: &image::RgbaImage, d: u32, rect: Rect) -> Vec<u8> {
        let mut out = Vec::new();
        for oy in rect.y..rect.y + rect.h {
            for ox in rect.x..rect.x + rect.w {
                let mut sum = [0u32; 4];
                let mut n = 0;
                for sy in oy * d..((oy + 1) * d).min(full.height()) {
                    for sx in ox * d..((ox + 1) * d).min(full.width()) {
                        let p = full.get_pixel(sx, sy).0;
                        for c in 0..4 {
                            sum[c] += p[c] as u32;
                        }
                        n += 1;
                    }
                }
                for s in sum {
                    out.push(((s + n / 2) / n) as u8);
                }
            }
        }
        out
    }

    #[test]
    fn region_matches_full_decode_for_every_color_type() {
        let dir = std::env::temp_dir().join("moodiary_png_region_test");
        std::fs::create_dir_all(&dir).unwrap();
        let rgba = noisy(1000, 700);
        let variants: Vec<(&str, DynamicImage)> = vec![
            ("rgba8.png", DynamicImage::ImageRgba8(rgba.clone())),
            (
                "rgb8.png",
                DynamicImage::ImageRgb8(DynamicImage::ImageRgba8(rgba.clone()).into_rgb8()),
            ),
            (
                "gray8.png",
                DynamicImage::ImageLuma8(DynamicImage::ImageRgba8(rgba.clone()).into_luma8()),
            ),
            (
                "la8.png",
                DynamicImage::ImageLumaA8(
                    DynamicImage::ImageRgba8(rgba.clone()).into_luma_alpha8(),
                ),
            ),
            (
                "rgb16.png",
                DynamicImage::ImageRgb16(DynamicImage::ImageRgba8(rgba.clone()).into_rgb16()),
            ),
            ("real16.png", DynamicImage::ImageRgba16(noisy16(1000, 700))),
            (
                "la16.png",
                DynamicImage::ImageLumaA16(
                    DynamicImage::ImageRgba16(noisy16(1000, 700)).into_luma_alpha16(),
                ),
            ),
        ];
        for (name, img) in &variants {
            let path = write(&dir, name, img);
            let full = image::open(&path).unwrap().into_rgba8();
            let region = open(&path);
            assert_eq!(region.raw_size(), (1000, 700));
            for d in [1u8, 2, 4, 8] {
                let (w, h) = (1000u32.div_ceil(d as u32), 700u32.div_ceil(d as u32));
                for rect in [
                    Rect { x: 0, y: 0, w, h },
                    Rect {
                        x: 37 / d as u32,
                        y: 53 / d as u32,
                        w: w / 2,
                        h: h / 3,
                    },
                    Rect {
                        x: w - 5,
                        y: h - 3,
                        w: 5,
                        h: 3,
                    },
                    Rect {
                        x: 0,
                        y: h / 2,
                        w: 100,
                        h: 1,
                    },
                ] {
                    let got = region.decode_raw(d, rect).unwrap();
                    assert_eq!(
                        (got.x, got.y, got.width, got.height),
                        (rect.x, rect.y, rect.w, rect.h),
                        "{name} d={d} {rect:?}"
                    );
                    let want = reference(&full, d as u32, rect);
                    assert!(got.pixels == want, "{name} d={d} {rect:?}: 像素不一致");
                }
            }
        }
        let _ = std::fs::remove_dir_all(&dir);
    }
}
