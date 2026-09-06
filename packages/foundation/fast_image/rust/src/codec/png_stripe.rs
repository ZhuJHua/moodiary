use std::fs::File;
use std::io::{BufWriter, Write};

use anyhow::{Result, bail};

pub struct PngStripeWriter {
    inner: Option<png::StreamWriter<'static, BufWriter<File>>>,
    width: u32,
    height: u32,
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
        encoder.set_compression(png::Compression::Balanced);
        Ok(Self {
            inner: Some(encoder.write_header()?.into_stream_writer()?),
            width,
            height,
            written: 0,
        })
    }

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
        assert!(writer.finish().is_err());
        std::fs::remove_file(&path).ok();
    }
}
