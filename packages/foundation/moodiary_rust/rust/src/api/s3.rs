use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct S3Client {
    inner: crate::sync::s3::S3Client,
}

impl S3Client {
    pub fn new(
        endpoint: String,
        access_key: String,
        secret_key: String,
        bucket: String,
        use_ssl: bool,
        region: Option<String>,
    ) -> Result<S3Client> {
        Ok(S3Client {
            inner: crate::sync::s3::S3Client::new(
                endpoint, access_key, secret_key, bucket, use_ssl, region,
            )?,
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        self.inner.test_connection().await
    }

    pub async fn read_object(&self, key: String) -> Result<Option<Vec<u8>>> {
        self.inner.read_object(key).await
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

    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.inner.create_exclusive(key, data).await
    }

    pub async fn delete_object(&self, key: String) -> Result<()> {
        self.inner.delete_object(key).await
    }

    pub async fn stat_object(&self, key: String) -> Result<String> {
        self.inner.stat_object(key).await
    }
}
