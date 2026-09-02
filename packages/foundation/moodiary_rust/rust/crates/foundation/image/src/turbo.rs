//! turbojpeg-sys（vendored libjpeg-turbo 3.1.0）的最小安全封装：读头、缩放解码、编码。
//! 句柄一次调用一个，不跨线程持有；每个入口都先钉 `TJPARAM_MAXPIXELS`，用户文件不可信。
//!
//! 缩放一律按 libjpeg 的口径 **N/8**（N = 1..=8）：turbojpeg 只认这 16 档系数，1/3、1/6
//! 这种分母会被 `tj3SetScalingFactor` 直接拒掉。

use std::ffi::{CStr, c_int, c_void};
use std::ptr;

use anyhow::{Result, bail};
use turbojpeg_sys as tj;

/// JPEG 头信息（原始朝向，EXIF 方向不在这里）。
#[derive(Clone, Copy, Debug)]
pub struct JpegHeader {
    pub width: u32,
    pub height: u32,
    pub progressive: bool,
    pub lossless: bool,
    pub arithmetic: bool,
    pub precision: u32,
    /// CMYK / YCCK：turbojpeg 不给 RGB 输出，交给引擎整解。
    pub cmyk: bool,
}

impl JpegHeader {
    /// 能走缩放 / 区域解码：8 位 Huffman 有损 YCbCr / 灰度 JPEG。progressive 要整幅系数缓冲，
    /// 无损不能缩放，算术编码没有 SIMD 路径，CMYK 转不了 RGB，都不算。
    pub fn region_decodable(&self) -> bool {
        self.precision == 8 && !self.progressive && !self.lossless && !self.arithmetic && !self.cmyk
    }
}

/// 源图像素数上限（宽 × 高）。内存由输出侧的预算兜着（缩略图解 N/8、区域解码按带），
/// 这里只挡真正的解压炸弹：24000² 的全景 / 天文照片（576MP）要能过。
const MAX_SOURCE_PIXELS: c_int = 1_000_000_000;

struct Handle(tj::tjhandle);

impl Handle {
    fn new(kind: tj::TJINIT) -> Result<Self> {
        let handle = unsafe { tj::tj3Init(kind as c_int) };
        if handle.is_null() {
            bail!("tj3Init failed");
        }
        Ok(Self(handle))
    }

    fn error(&self) -> String {
        let ptr = unsafe { tj::tj3GetErrorStr(self.0) };
        if ptr.is_null() {
            return "unknown turbojpeg error".into();
        }
        unsafe { CStr::from_ptr(ptr) }
            .to_string_lossy()
            .into_owned()
    }

    fn check(&self, rc: c_int, what: &str) -> Result<()> {
        if rc != 0 {
            bail!("{what}: {}", self.error());
        }
        Ok(())
    }

    fn get(&self, param: tj::TJPARAM) -> c_int {
        unsafe { tj::tj3Get(self.0, param as c_int) }
    }

    fn set(&self, param: tj::TJPARAM, value: c_int) -> Result<()> {
        self.check(
            unsafe { tj::tj3Set(self.0, param as c_int, value) },
            "tj3Set",
        )
    }

    fn read_header(&self, bytes: &[u8]) -> Result<JpegHeader> {
        self.set(tj::TJPARAM_TJPARAM_MAXPIXELS, MAX_SOURCE_PIXELS)?;
        self.check(
            unsafe { tj::tj3DecompressHeader(self.0, bytes.as_ptr(), bytes.len() as tj::size_t) },
            "tj3DecompressHeader",
        )?;
        Ok(JpegHeader {
            width: self.get(tj::TJPARAM_TJPARAM_JPEGWIDTH) as u32,
            height: self.get(tj::TJPARAM_TJPARAM_JPEGHEIGHT) as u32,
            progressive: self.get(tj::TJPARAM_TJPARAM_PROGRESSIVE) != 0,
            lossless: self.get(tj::TJPARAM_TJPARAM_LOSSLESS) != 0,
            arithmetic: self.get(tj::TJPARAM_TJPARAM_ARITHMETIC) != 0,
            precision: self.get(tj::TJPARAM_TJPARAM_PRECISION) as u32,
            cmyk: matches!(
                self.get(tj::TJPARAM_TJPARAM_COLORSPACE),
                x if x == tj::TJCS_TJCS_CMYK as c_int || x == tj::TJCS_TJCS_YCCK as c_int
            ),
        })
    }

    /// turbojpeg 按约分后的分数查表（4/8 要写成 1/2）。
    fn set_scale(&self, num: u8) -> Result<()> {
        let num = num.clamp(1, 8) as c_int;
        let gcd = (1..=8)
            .rev()
            .find(|g| num % g == 0 && 8 % g == 0)
            .unwrap_or(1);
        self.check(
            unsafe {
                tj::tj3SetScalingFactor(
                    self.0,
                    tj::tjscalingfactor {
                        num: num / gcd,
                        denom: 8 / gcd,
                    },
                )
            },
            "tj3SetScalingFactor",
        )
    }
}

impl Drop for Handle {
    fn drop(&mut self) {
        unsafe { tj::tj3Destroy(self.0) }
    }
}

pub fn read_header(bytes: &[u8]) -> Result<JpegHeader> {
    Handle::new(tj::TJINIT_TJINIT_DECOMPRESS)?.read_header(bytes)
}

/// libjpeg 的缩放尺寸公式（`TJSCALED`）：`dim × num / 8` 向上取整。
pub fn scaled(dim: u32, num: u8) -> u32 {
    (dim as u64 * num.clamp(1, 8) as u64).div_ceil(8) as u32
}

/// 1/`denom`（denom ∈ {1, 2, 4, 8}）对应的 N/8 分子。
pub fn numerator(denom: u8) -> Result<u8> {
    match denom {
        1 | 2 | 4 | 8 => Ok(8 / denom),
        _ => bail!("unsupported scale denominator {denom}"),
    }
}

/// 按 `num`/8 IDCT 缩放解码为 RGB8，**原始朝向**。无损 JPEG 不能缩放，强制 8/8。
pub fn decode_scaled(bytes: &[u8], num: u8) -> Result<image::RgbImage> {
    let handle = Handle::new(tj::TJINIT_TJINIT_DECOMPRESS)?;
    let header = handle.read_header(bytes)?;
    if header.precision != 8 {
        bail!("unsupported JPEG precision: {} bit", header.precision);
    }
    let num = if header.lossless { 8 } else { num.clamp(1, 8) };
    handle.set_scale(num)?;
    let width = scaled(header.width, num);
    let height = scaled(header.height, num);
    let mut buf = vec![0u8; width as usize * height as usize * 3];
    handle.check(
        unsafe {
            tj::tj3Decompress8(
                handle.0,
                bytes.as_ptr(),
                bytes.len() as tj::size_t,
                buf.as_mut_ptr(),
                0,
                tj::TJPF_TJPF_RGB as c_int,
            )
        },
        "tj3Decompress8",
    )?;
    image::RgbImage::from_raw(width, height, buf)
        .ok_or_else(|| anyhow::anyhow!("decoded buffer size mismatch"))
}

/// 缩放坐标系里的一块像素（原始朝向）。`channels` 是 3（RGB）或 4（RGBA）。
pub struct PixelRegion {
    pub x: u32,
    pub y: u32,
    pub width: u32,
    pub height: u32,
    pub channels: u8,
    pub pixels: Vec<u8>,
}

/// 各子采样的 iMCU 宽高（turbojpeg.h 的 `tjMCUWidth` / `tjMCUHeight`，按 TJSAMP 顺序）。
const MCU_WIDTH: [u32; 7] = [8, 16, 16, 8, 8, 32, 8];
const MCU_HEIGHT: [u32; 7] = [8, 8, 16, 8, 16, 8, 32];

/// 按 1/`denom` 缩放、只解缩放坐标系里的 `rect`，RGBA。见 [`decode_region_n8`]。
pub fn decode_region(bytes: &[u8], denom: u8, rect: crate::region::Rect) -> Result<PixelRegion> {
    decode_region_n8(bytes, numerator(denom)?, rect, true)
}

/// 按 `num`/8 缩放、只解缩放坐标系里的 `rect`（`tj3SetCroppingRegion`）。左边界会向左
/// 对齐到缩放后的 iMCU 宽（libjpeg 的硬要求），上边界对齐到 iMCU 高（省掉半个 MCU 的
/// 上采样边缘差异），矩形相应扩大；返回实际覆盖的矩形。**原始朝向**。
pub fn decode_region_n8(
    bytes: &[u8],
    num: u8,
    rect: crate::region::Rect,
    rgba: bool,
) -> Result<PixelRegion> {
    let handle = Handle::new(tj::TJINIT_TJINIT_DECOMPRESS)?;
    let header = handle.read_header(bytes)?;
    if !header.region_decodable() {
        bail!("JPEG is not region-decodable");
    }
    let num = num.clamp(1, 8);
    handle.set_scale(num)?;
    let scaled_w = scaled(header.width, num);
    let scaled_h = scaled(header.height, num);
    let subsamp = handle.get(tj::TJPARAM_TJPARAM_SUBSAMP);
    let (mcu_w, mcu_h) = match usize::try_from(subsamp) {
        Ok(i) if i < MCU_WIDTH.len() => (scaled(MCU_WIDTH[i], num), scaled(MCU_HEIGHT[i], num)),
        _ => (scaled(16, num), scaled(16, num)),
    };
    let x = (rect.x / mcu_w) * mcu_w;
    let y = (rect.y / mcu_h) * mcu_h;
    let right = (rect.x + rect.w).min(scaled_w);
    let bottom = (rect.y + rect.h).min(scaled_h);
    if right <= x || bottom <= y {
        bail!("empty region");
    }
    let (width, height) = (right - x, bottom - y);
    handle.check(
        unsafe {
            tj::tj3SetCroppingRegion(
                handle.0,
                tj::tjregion {
                    x: x as c_int,
                    y: y as c_int,
                    w: width as c_int,
                    h: height as c_int,
                },
            )
        },
        "tj3SetCroppingRegion",
    )?;
    let channels: u8 = if rgba { 4 } else { 3 };
    let mut buf = vec![0u8; width as usize * height as usize * channels as usize];
    handle.check(
        unsafe {
            tj::tj3Decompress8(
                handle.0,
                bytes.as_ptr(),
                bytes.len() as tj::size_t,
                buf.as_mut_ptr(),
                0,
                (if rgba {
                    tj::TJPF_TJPF_RGBA
                } else {
                    tj::TJPF_TJPF_RGB
                }) as c_int,
            )
        },
        "tj3Decompress8",
    )?;
    Ok(PixelRegion {
        x,
        y,
        width,
        height,
        channels,
        pixels: buf,
    })
}

/// RGB8 编成 JPEG。`chroma_444` 给截图类源图保文字边缘，照片用 4:2:0。
pub fn encode_jpeg(
    rgb: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    chroma_444: bool,
) -> Result<Vec<u8>> {
    encode_jpeg_with(rgb, width, height, quality, chroma_444, 0, false)
}

/// 同 [`encode_jpeg`]，每 `restart_rows` 行 MCU 写一个 restart marker（0 = 不写），
/// `progressive` 出多次扫描的文件（只有测试造样张用）。
pub fn encode_jpeg_with(
    rgb: &[u8],
    width: u32,
    height: u32,
    quality: u8,
    chroma_444: bool,
    restart_rows: u16,
    progressive: bool,
) -> Result<Vec<u8>> {
    if rgb.len() != width as usize * height as usize * 3 {
        bail!("encode buffer size mismatch");
    }
    let handle = Handle::new(tj::TJINIT_TJINIT_COMPRESS)?;
    handle.set(tj::TJPARAM_TJPARAM_QUALITY, quality.clamp(1, 100) as c_int)?;
    handle.set(
        tj::TJPARAM_TJPARAM_SUBSAMP,
        (if chroma_444 {
            tj::TJSAMP_TJSAMP_444
        } else {
            tj::TJSAMP_TJSAMP_420
        }) as c_int,
    )?;
    if restart_rows > 0 {
        handle.set(tj::TJPARAM_TJPARAM_RESTARTROWS, restart_rows as c_int)?;
    }
    if progressive {
        handle.set(tj::TJPARAM_TJPARAM_PROGRESSIVE, 1)?;
    }
    let mut out: *mut u8 = ptr::null_mut();
    let mut size: tj::size_t = 0;
    let rc = unsafe {
        tj::tj3Compress8(
            handle.0,
            rgb.as_ptr(),
            width as c_int,
            0,
            height as c_int,
            tj::TJPF_TJPF_RGB as c_int,
            &mut out,
            &mut size,
        )
    };
    let result = if rc == 0 && !out.is_null() {
        Ok(unsafe { std::slice::from_raw_parts(out, size as usize) }.to_vec())
    } else {
        Err(anyhow::anyhow!("tj3Compress8: {}", handle.error()))
    };
    if !out.is_null() {
        unsafe { tj::tj3Free(out as *mut c_void) };
    }
    result
}

/// 无损转码：把 progressive（或任意 Huffman 8 位）JPEG 重新熵编码成 baseline，每行 MCU 一个
/// restart marker（`restart_rows`，0 = 不写）。系数原样搬，像素逐字节相同；`tj3Transform` 要整幅
/// 系数缓冲（4:2:0 约 3 字节 / 像素），所以调用方按像素数把关。EXIF 等标记默认全部带过去
/// （`TJPARAM_SAVEMARKERS` = 2）。
pub fn to_baseline(bytes: &[u8], restart_rows: u16) -> Result<Vec<u8>> {
    let handle = Handle::new(tj::TJINIT_TJINIT_TRANSFORM)?;
    handle.set(tj::TJPARAM_TJPARAM_MAXPIXELS, MAX_SOURCE_PIXELS)?;
    if restart_rows > 0 {
        handle.set(tj::TJPARAM_TJPARAM_RESTARTROWS, restart_rows as c_int)?;
    }
    // SAFETY: tjtransform 是 C 的 POD，全零 = 无操作、无裁剪、无回调。
    let mut transform: tj::tjtransform = unsafe { std::mem::zeroed() };
    transform.op = tj::TJXOP_TJXOP_NONE as c_int;
    let mut out: *mut u8 = ptr::null_mut();
    let mut size: tj::size_t = 0;
    let rc = unsafe {
        tj::tj3Transform(
            handle.0,
            bytes.as_ptr(),
            bytes.len() as tj::size_t,
            1,
            &mut out,
            &mut size,
            &transform,
        )
    };
    let result = if rc == 0 && !out.is_null() {
        Ok(unsafe { std::slice::from_raw_parts(out, size as usize) }.to_vec())
    } else {
        Err(anyhow::anyhow!("tj3Transform: {}", handle.error()))
    };
    if !out.is_null() {
        unsafe { tj::tj3Free(out as *mut c_void) };
    }
    result
}
