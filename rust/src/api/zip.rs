use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::{Read, Write};
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use walkdir::WalkDir;
use zip::{write::SimpleFileOptions, AesMode, CompressionMethod, ZipArchive, ZipWriter};

#[frb(opaque)]
pub struct Zip {
    writer: Option<ZipWriter<File>>,
    file_options: SimpleFileOptions,
}

impl Zip {
    fn read_file_to_vec(path: &Path) -> Result<Vec<u8>> {
        let mut file =
            File::open(path).with_context(|| format!("Failed to open file {:?}", path))?;
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer)?;
        Ok(buffer)
    }

    #[frb(sync)]
    pub fn new(file_path: String) -> Result<Self> {
        let file = File::create(&file_path)
            .with_context(|| format!("Failed to create ZIP file at {}", file_path))?;

        let options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Zstd)
            .unix_permissions(0o755);

        Ok(Self {
            writer: Some(ZipWriter::new(file)),
            file_options: options,
        })
    }

    pub fn add_file(
        &mut self,
        file_path: String,
        zip_path: String,
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
        let buffer = Self::read_file_to_vec(Path::new(&file_path))?;
        writer.write_all(&buffer)?;

        Ok(())
    }

    pub fn add_dir(
        &mut self,
        dir_path: String,
        base_path: String,
        password: Option<String>,
    ) -> Result<()> {
        let mut options = self.file_options;
        if let Some(ref pwd) = password {
            options = options.with_aes_encryption(AesMode::Aes256, pwd.as_ref());
        }
        let mut writer = self
            .writer
            .take()
            .ok_or_else(|| anyhow::Error::msg("Zip writer is None"))?;

        for entry in WalkDir::new(&dir_path).into_iter().filter_map(Result::ok) {
            let path = entry.path();
            let relative_path = path.strip_prefix(&dir_path)?.to_str().unwrap();
            let zip_path = format!("{}/{}", base_path, relative_path);

            if path.is_dir() {
                writer.add_directory(zip_path, options)?;
            } else {
                writer.start_file(zip_path, options)?;
                let buffer = Self::read_file_to_vec(path)?;
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
                None => archive.by_index(i)?,
            };

            let out_path = Path::new(&dest_dir).join(file.mangled_name());

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
