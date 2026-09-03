//! WebP 的区域解码后端：libwebp 的 `use_cropping` + `use_scaling`。VP8 / VP8L 都没有随机访问，
//! 裁剪省的是滤波、上采样与输出（内存按裁剪块算），熵解析仍是整幅；WebP 最大 16383²，
//! 有损的一趟最多几秒。VP8L 内部要整幅 ARGB 缓冲，超过 [`LOSSLESS_MAX_PIXELS`] 不接；动图不接。

use std::mem::MaybeUninit;

use anyhow::{Result, bail};
use image::metadata::Orientation;
use libwebp_sys as webp;
use memmap2::Mmap;

use crate::codec::region::{RawDecoder, Rect};
use crate::codec::turbo::PixelRegion;
use crate::codec::{ImageFormat, image_header};

/// 无损 WebP 解码时整幅 ARGB 都在内存里（4 字节 / 像素），16MP 就是 64MB。
const LOSSLESS_MAX_PIXELS: u64 = 16 * 1024 * 1024;

/// 有损 WebP 没有随机访问，每条带都是整幅 VP8 熵解析；64MP 一趟已是秒级，再大交给引擎封顶。
const LOSSY_MAX_PIXELS: u64 = 64 * 1024 * 1024;

pub struct WebPRegion {
    bytes: Mmap,
    width: u32,
    height: u32,
    orientation: Orientation,
}

struct Features {
    width: u32,
    height: u32,
    animated: bool,
    lossless: bool,
}

fn features(bytes: &[u8]) -> Result<Features> {
    let mut f = MaybeUninit::<webp::WebPBitstreamFeatures>::uninit();
    let status = unsafe { webp::WebPGetFeatures(bytes.as_ptr(), bytes.len(), f.as_mut_ptr()) };
    if status != webp::VP8StatusCode::VP8_STATUS_OK {
        bail!("WebPGetFeatures: {status:?}");
    }
    let f = unsafe { f.assume_init() };
    Ok(Features {
        width: f.width as u32,
        height: f.height as u32,
        animated: f.has_animation != 0,
        lossless: f.format == 2,
    })
}

fn accepts(f: &Features) -> bool {
    let pixels = f.width as u64 * f.height as u64;
    !f.animated
        && pixels
            <= if f.lossless {
                LOSSLESS_MAX_PIXELS
            } else {
                LOSSY_MAX_PIXELS
            }
}

/// 头一眼能判定的：非动图、像素数在该编码的上限内。
pub fn region_decodable(bytes: &[u8]) -> bool {
    features(bytes).is_ok_and(|f| accepts(&f))
}

impl WebPRegion {
    pub fn open(bytes: Mmap) -> Result<Self> {
        let f = features(&bytes)?;
        if !accepts(&f) {
            bail!("WebP is not region-decodable (animated or too large)");
        }
        let (_, _, orientation) = image_header(&bytes)?;
        Ok(Self {
            bytes,
            width: f.width,
            height: f.height,
            orientation,
        })
    }
}

impl RawDecoder for WebPRegion {
    fn format(&self) -> ImageFormat {
        ImageFormat::WebP
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
        let scaled_w = self.width.div_ceil(d);
        let scaled_h = self.height.div_ceil(d);
        let right = (rect.x + rect.w).min(scaled_w);
        let bottom = (rect.y + rect.h).min(scaled_h);
        if rect.x >= right || rect.y >= bottom {
            bail!("empty region");
        }
        let (out_w, out_h) = (right - rect.x, bottom - rect.y);
        // 裁剪框在源坐标里、起点是 d 的倍数：整数倍缩放正好是 d×d 的盒式平均，块与块之间无缝。
        // 只有贴着右 / 下边缘、裁剪尺寸不是 d 的整倍数时，libwebp 的面积平均会有不到一个输出
        // 像素的漂移，屏幕上看不出来。
        let (x0, y0) = (rect.x * d, rect.y * d);
        let crop_w = (right * d).min(self.width) - x0;
        let crop_h = (bottom * d).min(self.height) - y0;
        // 有损 WebP 的解码走 YUV 4:2:0，libwebp 会把裁剪起点向下对齐到偶数；1/1 时起点可能是奇数，
        // 自己对齐后多解一行一列再裁掉（d ≥ 2 时起点天然是偶数）。
        let (ax, ay) = (x0 & !1, y0 & !1);
        let (dx, dy) = (x0 - ax, y0 - ay);
        let (dec_w, dec_h) = if d == 1 {
            (out_w + dx, out_h + dy)
        } else {
            (out_w, out_h)
        };

        let mut config = webp::WebPDecoderConfig::new()
            .map_err(|_| anyhow::anyhow!("WebPInitDecoderConfig failed"))?;
        config.options.use_cropping = 1;
        config.options.crop_left = ax as i32;
        config.options.crop_top = ay as i32;
        config.options.crop_width = (crop_w + dx) as i32;
        config.options.crop_height = (crop_h + dy) as i32;
        if d > 1 {
            config.options.use_scaling = 1;
            config.options.scaled_width = out_w as i32;
            config.options.scaled_height = out_h as i32;
        }
        let stride = dec_w as usize * 4;
        let mut pixels = vec![0u8; stride * dec_h as usize];
        config.output.colorspace = webp::WEBP_CSP_MODE::MODE_RGBA;
        config.output.is_external_memory = 1;
        config.output.u.RGBA = webp::WebPRGBABuffer {
            rgba: pixels.as_mut_ptr(),
            stride: stride as i32,
            size: pixels.len(),
        };
        let status =
            unsafe { webp::WebPDecode(self.bytes.as_ptr(), self.bytes.len(), &mut config) };
        // 外部内存：libwebp 不会释放我们的 Vec，但仍要走一遍 FreeDecBuffer 清理它自己的私有块。
        unsafe { webp::WebPFreeDecBuffer(&mut config.output) };
        if status != webp::VP8StatusCode::VP8_STATUS_OK {
            bail!("WebPDecode: {status:?}");
        }
        if config.output.width as u32 != dec_w || config.output.height as u32 != dec_h {
            bail!(
                "WebP region size mismatch: got {}x{}, want {dec_w}x{dec_h}",
                config.output.width,
                config.output.height
            );
        }
        if (dec_w, dec_h) != (out_w, out_h) {
            let out_stride = out_w as usize * 4;
            let mut trimmed = Vec::with_capacity(out_stride * out_h as usize);
            for row in dy..dec_h {
                let start = row as usize * stride + dx as usize * 4;
                trimmed.extend_from_slice(&pixels[start..start + out_stride]);
            }
            pixels = trimmed;
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

#[cfg(test)]
mod tests {
    use memmap2::Mmap;

    use super::{WebPRegion, region_decodable};
    use crate::codec::region::{RawDecoder, Rect};

    fn noisy(width: u32, height: u32) -> image::RgbaImage {
        let mut seed = 0x5EED_1234u32;
        image::RgbaImage::from_fn(width, height, |x, y| {
            seed = seed.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
            let n = (seed >> 24) as u8;
            image::Rgba([
                ((x * 255 / width) as u8).wrapping_add(n / 4),
                ((y * 255 / height) as u8).wrapping_add(n / 3),
                n,
                255,
            ])
        })
    }

    /// image 的 WebP 编码器是无损的（VP8L）；有损样张用 libwebp 自己编。
    fn write_lossy(path: &std::path::Path, img: &image::RgbaImage) {
        let mut out: *mut u8 = std::ptr::null_mut();
        let size = unsafe {
            libwebp_sys::WebPEncodeRGBA(
                img.as_raw().as_ptr(),
                img.width() as i32,
                img.height() as i32,
                (img.width() * 4) as i32,
                85.0,
                &mut out,
            )
        };
        assert!(size > 0 && !out.is_null());
        let bytes = unsafe { std::slice::from_raw_parts(out, size) }.to_vec();
        unsafe { libwebp_sys::WebPFree(out as *mut _) };
        std::fs::write(path, bytes).unwrap();
    }

    fn open(path: &std::path::Path) -> WebPRegion {
        let file = std::fs::File::open(path).unwrap();
        WebPRegion::open(unsafe { Mmap::map(&file).unwrap() }).unwrap()
    }

    #[test]
    fn lossless_region_matches_full_decode() {
        let dir = std::env::temp_dir().join("moodiary_webp_region_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("lossless.webp");
        let img = noisy(1024, 704);
        img.save(&path).unwrap();
        assert!(region_decodable(&std::fs::read(&path).unwrap()));
        let region = open(&path);
        assert_eq!(region.raw_size(), (1024, 704));
        // 1/1：逐字节等于裁剪。
        let rect = Rect {
            x: 37,
            y: 53,
            w: 300,
            h: 200,
        };
        let got = region.decode_raw(1, rect).unwrap();
        let want = image::imageops::crop_imm(&img, 37, 53, 300, 200).to_image();
        assert!(got.pixels == want.as_raw()[..], "1/1 裁剪应逐字节一致");
        // 缩放档：尺寸是 d 的整倍数时，分块缩放与整图缩放同一块一致（都是 d×d 盒式平均）。
        for d in [2u8, 4, 8] {
            let (w, h) = (1024u32 / d as u32, 704u32 / d as u32);
            let whole = region.decode_raw(d, Rect { x: 0, y: 0, w, h }).unwrap();
            let part = region
                .decode_raw(
                    d,
                    Rect {
                        x: w / 3,
                        y: h / 4,
                        w: w / 2,
                        h: h / 3,
                    },
                )
                .unwrap();
            assert_eq!((whole.width, whole.height), (w, h));
            assert_eq!((part.width, part.height), (w / 2, h / 3));
            let mut worst = 0i32;
            for y in 0..part.height {
                for x in 0..part.width {
                    let a = ((y * part.width + x) * 4) as usize;
                    let b = (((y + h / 4) * w + x + w / 3) * 4) as usize;
                    for c in 0..3 {
                        worst = worst
                            .max((part.pixels[a + c] as i32 - whole.pixels[b + c] as i32).abs());
                    }
                }
            }
            assert!(worst <= 2, "d={d}: 分块缩放与整图缩放最大差 {worst}");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// 尺寸不是 8 的整倍数：贴边的块尺寸按向上取整给，允许不到一个输出像素的漂移。
    #[test]
    fn odd_sized_lossless_edges_have_ceil_sizes() {
        let dir = std::env::temp_dir().join("moodiary_webp_odd_region_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("odd.webp");
        noisy(1000, 700).save(&path).unwrap();
        let region = open(&path);
        for d in [2u8, 4, 8] {
            let (w, h) = (1000u32.div_ceil(d as u32), 700u32.div_ceil(d as u32));
            let whole = region.decode_raw(d, Rect { x: 0, y: 0, w, h }).unwrap();
            assert_eq!((whole.width, whole.height), (w, h));
            let corner = region
                .decode_raw(
                    d,
                    Rect {
                        x: w - 3,
                        y: h - 2,
                        w: 3,
                        h: 2,
                    },
                )
                .unwrap();
            assert_eq!(
                (corner.x, corner.y, corner.width, corner.height),
                (w - 3, h - 2, 3, 2)
            );
        }
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn lossy_region_decodes_with_alignment_free_origin() {
        let dir = std::env::temp_dir().join("moodiary_webp_lossy_region_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("lossy.webp");
        write_lossy(&path, &noisy(640, 400));
        let region = open(&path);
        let full = region
            .decode_raw(
                1,
                Rect {
                    x: 0,
                    y: 0,
                    w: 640,
                    h: 400,
                },
            )
            .unwrap();
        let rect = Rect {
            x: 33,
            y: 17,
            w: 200,
            h: 150,
        };
        let part = region.decode_raw(1, rect).unwrap();
        assert_eq!((part.width, part.height), (200, 150));
        let mut worst = 0i32;
        for y in 0..150u32 {
            for x in 0..200u32 {
                let a = ((y * 200 + x) * 4) as usize;
                let b = (((y + 17) * 640 + x + 33) * 4) as usize;
                for c in 0..3 {
                    worst =
                        worst.max((part.pixels[a + c] as i32 - full.pixels[b + c] as i32).abs());
                }
            }
        }
        assert!(
            worst <= 2,
            "奇数起点的裁剪应与整图同位置一致，最大差 {worst}"
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}

#[cfg(test)]
mod samples {
    //! `MOODIARY_SAMPLES_DIR=/path cargo test --release -p moodiary-image samples -- --ignored`
    //! 造真机 / 模拟器验收用的大图：PNG、有损 WebP、无损 WebP、progressive JPEG。
    use crate::codec::turbo;

    fn scene(width: u32, height: u32) -> image::RgbaImage {
        image::RgbaImage::from_fn(width, height, |x, y| {
            // 细网格 + 大渐变 + 对角条纹：放大后看得出 tile 是否对齐、缩放是否糊。
            let grid = if x % 100 < 2 || y % 100 < 2 { 255 } else { 0 };
            let stripe = ((x + y) / 37 % 2) as u8 * 40;
            image::Rgba([
                ((x * 255 / width) as u8).saturating_add(stripe).max(grid),
                ((y * 255 / height) as u8).saturating_add(stripe).max(grid),
                (((x ^ y) & 0xFF) as u8 / 2 + 60).max(grid),
                255,
            ])
        })
    }

    #[test]
    #[ignore]
    fn generate() {
        let Ok(dir) = std::env::var("MOODIARY_SAMPLES_DIR") else {
            return;
        };
        let dir = std::path::Path::new(&dir);
        std::fs::create_dir_all(dir).unwrap();
        let big = scene(6000, 4500);
        big.save(dir.join("sample_png_27mp.png")).unwrap();
        let rgb = image::DynamicImage::ImageRgba8(big.clone()).into_rgb8();
        std::fs::write(
            dir.join("sample_progressive_27mp.jpg"),
            turbo::encode_jpeg_with(rgb.as_raw(), 6000, 4500, 90, false, 0, true).unwrap(),
        )
        .unwrap();
        let mut out: *mut u8 = std::ptr::null_mut();
        let size = unsafe {
            libwebp_sys::WebPEncodeRGBA(big.as_raw().as_ptr(), 6000, 4500, 6000 * 4, 80.0, &mut out)
        };
        assert!(size > 0);
        std::fs::write(dir.join("sample_lossy_27mp.webp"), unsafe {
            std::slice::from_raw_parts(out, size)
        })
        .unwrap();
        unsafe { libwebp_sys::WebPFree(out as *mut _) };
        scene(3000, 2000)
            .save(dir.join("sample_lossless_6mp.webp"))
            .unwrap();
    }
}
