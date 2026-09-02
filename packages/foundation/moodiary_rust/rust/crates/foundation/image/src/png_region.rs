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
use png::{ColorType, Decoder, Transformations};

use crate::region::{RawDecoder, Rect};
use crate::turbo::PixelRegion;
use crate::{ImageFormat, image_header};

pub struct PngRegion {
    bytes: Mmap,
    width: u32,
    height: u32,
    orientation: Orientation,
}

/// 头一眼能判定的：不是 Adam7 隔行。
pub fn region_decodable(bytes: &[u8]) -> bool {
    Decoder::new(Cursor::new(bytes))
        .read_info()
        .is_ok_and(|r| !r.info().interlaced)
}

impl PngRegion {
    pub fn open(bytes: Mmap) -> Result<Self> {
        let reader = Decoder::new(Cursor::new(&bytes[..])).read_info()?;
        let info = reader.info();
        if info.interlaced {
            bail!("interlaced PNG is not region-decodable");
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
        decoder.set_transformations(
            Transformations::EXPAND | Transformations::STRIP_16 | Transformations::ALPHA,
        );
        decoder.set_ignore_text_chunk(true);
        decoder.ignore_checksums(true);
        let mut reader = decoder.read_info()?;
        // ALPHA 之后只剩两种：RGBA，或灰度 + alpha（png 不会把灰扩成 RGB）。
        let gray = match reader.output_color_type().0 {
            ColorType::Rgba => false,
            ColorType::GrayscaleAlpha => true,
            other => bail!("unexpected PNG output color type {other:?}"),
        };
        let channels = if gray { 2 } else { 4 };

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
                    push_row(&mut pixels, data, x0, x1, channels, gray);
                } else {
                    accumulate(&mut acc, data, x0, x1, shift, channels, gray);
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

fn push_row(out: &mut Vec<u8>, data: &[u8], x0: u32, x1: u32, channels: usize, gray: bool) {
    let row = &data[x0 as usize * channels..x1 as usize * channels];
    if gray {
        for px in row.chunks_exact(2) {
            out.extend_from_slice(&[px[0], px[0], px[0], px[1]]);
        }
    } else {
        out.extend_from_slice(row);
    }
}

fn accumulate(
    acc: &mut [u32],
    data: &[u8],
    x0: u32,
    x1: u32,
    shift: u32,
    channels: usize,
    gray: bool,
) {
    let row = &data[x0 as usize * channels..x1 as usize * channels];
    for (i, px) in row.chunks_exact(channels).enumerate() {
        let o = (i >> shift) * 4;
        if gray {
            acc[o] += px[0] as u32;
            acc[o + 1] += px[0] as u32;
            acc[o + 2] += px[0] as u32;
            acc[o + 3] += px[1] as u32;
        } else {
            acc[o] += px[0] as u32;
            acc[o + 1] += px[1] as u32;
            acc[o + 2] += px[2] as u32;
            acc[o + 3] += px[3] as u32;
        }
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
