use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::{Read, Write};
use std::path::Path;
use walkdir::WalkDir;
use zip::{write::SimpleFileOptions, AesMode, CompressionMethod, ZipArchive, ZipWriter};

#[frb(opaque)]
pub struct Zip {
    writer: Option<ZipWriter<File>>,
}

impl Zip {
    #[frb(sync)]
    pub fn new(file_path: String) -> Result<Self> {
        let file = File::create(&file_path)
            .with_context(|| format!("Failed to create ZIP file at {}", file_path))?;
        Ok(Self {
            writer: Some(ZipWriter::new(file)),
        })
    }

    pub fn add_file(
        &mut self,
        file_path: String,
        zip_path: String,
        password: Option<String>,
    ) -> Result<()> {
        let mut options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Zstd)
            .unix_permissions(0o755);

        if let Some(ref pwd) = password {
            options = options.with_aes_encryption(AesMode::Aes256, pwd.as_ref());
        }

        let writer = match self.writer.as_mut() {
            Some(writer) => writer,
            None => return Err(anyhow::Error::msg("Zip writer is None")),
        };

        writer.start_file(zip_path, options)?;

        let mut file =
            File::open(&file_path).with_context(|| format!("Failed to open file {}", file_path))?;
        let mut buffer = Vec::with_capacity(file.metadata()?.len() as usize);
        file.read_to_end(&mut buffer)?;
        writer.write_all(&buffer)?;

        Ok(())
    }

    pub fn add_dir(
        &mut self,
        dir_path: String,
        base_path: String,
        password: Option<String>,
    ) -> Result<()> {
        let walk_dir = WalkDir::new(&dir_path);
        let mut options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Zstd)
            .unix_permissions(0o755);

        if let Some(ref pwd) = password {
            options = options.with_aes_encryption(AesMode::Aes256, pwd.as_ref());
        }

        let mut writer = self
            .writer
            .take()
            .ok_or_else(|| anyhow::Error::msg("Zip writer is None"))?;

        for entry in walk_dir.into_iter().filter_map(|e| e.ok()) {
            let path = entry.path();
            let relative_path = path.strip_prefix(&dir_path)?.to_str().unwrap();
            let zip_path = format!("{}/{}", base_path, relative_path);

            if path.is_dir() {
                writer.add_directory(zip_path, options)?;
            } else {
                writer.start_file(zip_path, options)?;
                let mut file = File::open(path)?;
                let mut buffer = Vec::new();
                file.read_to_end(&mut buffer)?;
                writer.write_all(&buffer)?;
            }
        }

        self.writer = Some(writer);
        Ok(())
    }

    pub fn finish(&mut self) -> Result<()> {
        if let Some(writer) = self.writer.take() {
            writer.finish()?;
        }
        Ok(())
    }

    pub fn extract(zip_path: String, dest_dir: String, password: Option<String>) -> Result<()> {
        let file = File::open(&zip_path)
            .with_context(|| format!("Failed to open ZIP file {}", zip_path))?;
        let mut archive = ZipArchive::new(file)?;

        for i in 0..archive.len() {
            let mut file = match &password {
                Some(pwd) => archive.by_index_decrypt(i, pwd.as_bytes())?,
                None => archive.by_index(i).map_err(|e| anyhow::Error::new(e))?,
            };

            let out_path = Path::new(&dest_dir).join(file.mangled_name());

            if file.is_dir() {
                std::fs::create_dir_all(&out_path)?;
            } else {
                if let Some(p) = out_path.parent() {
                    if !p.exists() {
                        std::fs::create_dir_all(p)?;
                    }
                }
                let mut outfile = File::create(&out_path)?;
                std::io::copy(&mut file, &mut outfile)?;
            }

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                if let Some(mode) = file.unix_mode() {
                    std::fs::set_permissions(&out_path, std::fs::Permissions::from_mode(mode))?;
                }
            }
        }
        Ok(())
    }
}
