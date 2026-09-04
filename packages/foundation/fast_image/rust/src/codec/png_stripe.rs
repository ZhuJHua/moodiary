//! 逐行流式写一张 PNG。
//!
//! 给「日记导出成一张长图」用：Flutter 侧受 GPU 纹理上限约束，只能一带一带地光栅化
//! （见 `ImageComposer`），但产物必须是**一张**图。整张图的位图从不存在于任何一侧 ——
//! 每带的 RGBA 过桥即写、写完即丢，峰值只跟带高有关，与篇幅无关。
//!
//! 用 `into_stream_writer` 而不是 `stream_writer(&mut self)`：后者借用 `Writer`，
//! 存进结构体就成了自引用，FRB 的 opaque 类型扛不住。

use std::fs::File;
use std::io::{BufWriter, Write};

use anyhow::{Result, bail};

pub struct PngStripeWriter {
    /// finish() 之后置空；Drop 时若还在，说明调用方没收尾，PNG 会缺 IEND。
    inner: Option<png::StreamWriter<'static, BufWriter<File>>>,
    width: u32,
    height: u32,
    /// 已写字节数，用来在 finish 时校验行数对得上。
    written: u64,
}

impl PngStripeWriter {
    pub fn create(output_path: &str, width: u32, height: u32) -> Result<Self> {
        if width == 0 || height == 0 {
            bail!("png size must be non-zero, got {width}x{height}");
        }
        let file = BufWriter::new(File::create(output_path)?);
        let mut encoder = png::Encoder::new(file, width, height);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        // 长图几乎全是文字与纯色底，Up/Paeth 预测后压得很好；Balanced 已够，
        // High 在 4 万像素高上要多花几秒而只小几个百分点。
        encoder.set_compression(png::Compression::Balanced);
        Ok(Self {
            inner: Some(encoder.write_header()?.into_stream_writer()?),
            width,
            height,
            written: 0,
        })
    }

    /// 追加若干整行像素。`rgba` 长度必须是 `width * 4` 的整数倍。
    pub fn push(&mut self, rgba: &[u8]) -> Result<()> {
        let Some(writer) = self.inner.as_mut() else {
            bail!("png stripe writer already finished");
        };
        let row = self.width as usize * 4;
        if !rgba.len().is_multiple_of(row) {
            bail!(
                "stripe must be whole rows: {} bytes is not a multiple of {row}",
                rgba.len()
            );
        }
        let total = self.width as u64 * self.height as u64 * 4;
        if self.written + rgba.len() as u64 > total {
            bail!(
                "stripe overflows declared height: {} + {} > {total}",
                self.written,
                rgba.len()
            );
        }
        writer.write_all(rgba)?;
        self.written += rgba.len() as u64;
        Ok(())
    }

    /// 收尾并落盘。行数不足会报错而不是写出半张图 —— 半张 PNG 在相册里能打开，
    /// 用户不会发现自己的日记被截断了。
    pub fn finish(&mut self) -> Result<()> {
        let Some(writer) = self.inner.take() else {
            bail!("png stripe writer already finished");
        };
        let total = self.width as u64 * self.height as u64 * 4;
        if self.written != total {
            bail!(
                "png is short: wrote {} of {total} bytes ({}x{})",
                self.written,
                self.width,
                self.height
            );
        }
        writer.finish()?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp(name: &str) -> String {
        std::env::temp_dir()
            .join(name)
            .to_string_lossy()
            .into_owned()
    }

    #[test]
    fn writes_a_tall_png_in_stripes() {
        let path = temp("fastimage_stripe.png");
        let width = 64u32;
        let height = 500u32;
        let mut writer = PngStripeWriter::create(&path, width, height).unwrap();
        // 10 带，每带 50 行。
        for band in 0..10u8 {
            let rows = vec![band.wrapping_mul(20); width as usize * 4 * 50];
            writer.push(&rows).unwrap();
        }
        writer.finish().unwrap();

        let decoded = image::open(&path).unwrap();
        assert_eq!(decoded.width(), width);
        assert_eq!(decoded.height(), height);
        std::fs::remove_file(&path).ok();
    }

    #[test]
    fn rejects_partial_rows_and_short_images() {
        let path = temp("fastimage_stripe_bad.png");
        let mut writer = PngStripeWriter::create(&path, 8, 4).unwrap();
        assert!(writer.push(&[0u8; 3]).is_err());
        writer.push(&[0u8; 8 * 4 * 2]).unwrap();
        // 只写了一半的行，收尾必须报错。
        assert!(writer.finish().is_err());
        std::fs::remove_file(&path).ok();
    }
}
