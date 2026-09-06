use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct DavClient {
    inner: crate::sync::webdav::DavClient,
}

impl DavClient {
    pub fn new(base_url: String, username: String, password: String) -> Result<DavClient> {
        Ok(DavClient {
            inner: crate::sync::webdav::DavClient::new(base_url, username, password)?,
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        self.inner.test_connection().await
    }

    pub async fn read_object(&self, key: String) -> Result<Option<Vec<u8>>> {
        self.inner.read_object(key).await
    }

    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.inner.create_exclusive(key, data).await
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        self.inner.write_object(key, data).await
    }

    pub async fn read_object_to_file(&self, key: String, file_path: String) -> Result<bool> {
        self.inner.read_object_to_file(key, file_path).await
    }

    pub async fn write_object_file(&self, key: String, file_path: String) -> Result<()> {
        self.inner.write_object_file(key, file_path).await
    }

    pub async fn delete_object(&self, key: String) -> Result<()> {
        self.inner.delete_object(key).await
    }

    pub async fn stat_object(&self, key: String) -> Result<String> {
        self.inner.stat_object(key).await
    }
}
