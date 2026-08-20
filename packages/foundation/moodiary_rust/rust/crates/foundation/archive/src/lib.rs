use anyhow::{Context, Result};
use std::fs::File;
use std::io::Write;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use zip::{AesMode, CompressionMethod, ZipArchive, ZipWriter, write::SimpleFileOptions};

pub struct Zip {
    writer: Option<ZipWriter<File>>,
    file_options: SimpleFileOptions,
}

impl Zip {
    pub fn new(file_path: String) -> Result<Self> {
        let file = File::create(&file_path)
            .with_context(|| format!("Failed to create ZIP file at {}", file_path))?;

        // Deflate 而非 Zstd：系统自带解压工具普遍不支持 zip 内 Zstd 条目。
        let options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Deflated)
            .unix_permissions(0o755);

        Ok(Self {
            writer: Some(ZipWriter::new(file)),
            file_options: options,
        })
    }

    /// [stored] 为 true 时不压缩直接存储（媒体等已压缩格式），并允许单文件 >= 4GiB。
    pub fn add_file(
        &mut self,
        file_path: String,
        zip_path: String,
        password: Option<String>,
        stored: Option<bool>,
    ) -> Result<()> {
        let mut options = self.file_options;
        if stored == Some(true) {
            options = options
                .compression_method(CompressionMethod::Stored)
                .large_file(true);
        }
        if let Some(ref pwd) = password {
            options = options.with_aes_encryption(AesMode::Aes256, pwd.as_ref());
        }
        let writer = self
            .writer
            .as_mut()
            .ok_or_else(|| anyhow::Error::msg("Zip writer is None"))?;

        writer.start_file(zip_path, options)?;
        let mut file = File::open(Path::new(&file_path))
            .with_context(|| format!("Failed to open file {}", file_path))?;
        std::io::copy(&mut file, writer)?;

        Ok(())
    }

    pub fn add_bytes(
        &mut self,
        zip_path: String,
        data: Vec<u8>,
        password: Option<String>,
    ) -> Result<()> {
        let mut options = self.file_options;
        if let Some(ref pwd) = password {
            options = options.with_aes_encryption(AesMode::Aes256, pwd.as_ref());
        }
        let writer = self
            .writer
            .as_mut()
            .ok_or_else(|| anyhow::Error::msg("Zip writer is None"))?;

        writer.start_file(zip_path, options)?;
        writer.write_all(&data)?;

        Ok(())
    }

    pub fn finish(&mut self) -> Result<()> {
        if let Some(writer) = self.writer.take() {
            writer.finish()?;
        }
        Ok(())
    }

    pub fn extract(
        zip_path: String,
        dest_dir: String,
        password: Option<String>,
        cancelled: &dyn Fn() -> bool,
    ) -> Result<()> {
        let file = File::open(&zip_path)
            .with_context(|| format!("Failed to open ZIP file {}", zip_path))?;
        let mut archive = ZipArchive::new(file)?;

        for i in 0..archive.len() {
            if cancelled() {
                anyhow::bail!("cancelled");
            }
            let mut file = match &password {
                Some(pwd) => archive.by_index_decrypt(i, pwd.as_bytes())?,
                None => archive.by_index(i)?,
            };

            let Some(name) = file.enclosed_name() else {
                anyhow::bail!("unsafe entry path in archive: {}", file.name());
            };
            let out_path = Path::new(&dest_dir).join(name);

            if file.is_dir() {
                std::fs::create_dir_all(&out_path)?;
            } else {
                if let Some(p) = out_path.parent() {
                    std::fs::create_dir_all(p)?;
                }
                let mut outfile = File::create(&out_path)?;
                std::io::copy(&mut file, &mut outfile)?;
            }

            #[cfg(unix)]
            if let Some(mode) = file.unix_mode() {
                std::fs::set_permissions(&out_path, std::fs::Permissions::from_mode(mode))?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_bytes_and_stored_file() {
        let dir = std::env::temp_dir().join(format!("moodiary-zip-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();

        let src = dir.join("media.bin");
        std::fs::write(&src, b"media-bytes").unwrap();

        let zip_path = dir.join("backup.zip");
        let mut zip = Zip::new(zip_path.to_str().unwrap().to_string()).unwrap();
        zip.add_bytes(
            "manifest.json".to_string(),
            br#"{"version":4}"#.to_vec(),
            None,
        )
        .unwrap();
        zip.add_file(
            src.to_str().unwrap().to_string(),
            "media/image/a.png".to_string(),
            None,
            Some(true),
        )
        .unwrap();
        zip.finish().unwrap();

        let out = dir.join("out");
        Zip::extract(
            zip_path.to_str().unwrap().to_string(),
            out.to_str().unwrap().to_string(),
            None,
            &|| false,
        )
        .unwrap();

        assert_eq!(
            std::fs::read(out.join("manifest.json")).unwrap(),
            br#"{"version":4}"#
        );
        assert_eq!(
            std::fs::read(out.join("media/image/a.png")).unwrap(),
            b"media-bytes"
        );

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn roundtrip_aes_password_and_reject_wrong_password() {
        let dir =
            std::env::temp_dir().join(format!("moodiary-zip-aes-test-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();

        let src = dir.join("media.bin");
        std::fs::write(&src, b"secret-media").unwrap();

        let password = "0123456789abcdef".to_string();
        let zip_path = dir.join("enc.zip");
        let mut zip = Zip::new(zip_path.to_str().unwrap().to_string()).unwrap();
        zip.add_bytes(
            "manifest.json".to_string(),
            br#"{"version":4}"#.to_vec(),
            Some(password.clone()),
        )
        .unwrap();
        zip.add_file(
            src.to_str().unwrap().to_string(),
            "media/image/a.png".to_string(),
            Some(password.clone()),
            Some(true),
        )
        .unwrap();
        zip.finish().unwrap();

        let out = dir.join("out");
        Zip::extract(
            zip_path.to_str().unwrap().to_string(),
            out.to_str().unwrap().to_string(),
            Some(password),
            &|| false,
        )
        .unwrap();
        assert_eq!(
            std::fs::read(out.join("manifest.json")).unwrap(),
            br#"{"version":4}"#
        );
        assert_eq!(
            std::fs::read(out.join("media/image/a.png")).unwrap(),
            b"secret-media"
        );

        let out_bad = dir.join("out-bad");
        assert!(
            Zip::extract(
                zip_path.to_str().unwrap().to_string(),
                out_bad.to_str().unwrap().to_string(),
                Some("wrong-password".to_string()),
                &|| false,
            )
            .is_err()
        );

        std::fs::remove_dir_all(&dir).ok();
    }
}
