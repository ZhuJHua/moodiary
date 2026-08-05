use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct DavClient {
    inner: moodiary_sync::webdav::DavClient,
}

impl DavClient {
    pub fn new(base_url: String, username: String, password: String) -> Result<DavClient> {
        Ok(DavClient {
            inner: moodiary_sync::webdav::DavClient::new(base_url, username, password)?,
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        self.inner.test_connection().await
    }

    pub async fn read_object(&self, key: String) -> Result<Vec<u8>> {
        self.inner.read_object(key).await
    }

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的服务器会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.inner.create_exclusive(key, data).await
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        self.inner.write_object(key, data).await
    }

    pub async fn delete_object(&self, key: String) -> Result<()> {
        self.inner.delete_object(key).await
    }

    pub async fn stat_object(&self, key: String) -> Result<String> {
        self.inner.stat_object(key).await
    }
}
