use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct Zip {
    inner: moodiary_archive::Zip,
}

impl Zip {
    #[frb(sync)]
    pub fn new(file_path: String) -> Result<Self> {
        Ok(Self {
            inner: moodiary_archive::Zip::new(file_path)?,
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
        self.inner.add_file(file_path, zip_path, password, stored)
    }

    pub fn add_bytes(
        &mut self,
        zip_path: String,
        data: Vec<u8>,
        password: Option<String>,
    ) -> Result<()> {
        self.inner.add_bytes(zip_path, data, password)
    }

    pub fn finish(&mut self) -> Result<()> {
        self.inner.finish()
    }

    pub fn extract(zip_path: String, dest_dir: String, password: Option<String>) -> Result<()> {
        moodiary_archive::Zip::extract(zip_path, dest_dir, password)
    }
}
