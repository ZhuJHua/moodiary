use anyhow::Result;
use flutter_rust_bridge::frb;

#[frb(opaque)]
pub struct S3Client {
    inner: moodiary_sync::s3::S3Client,
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
            inner: moodiary_sync::s3::S3Client::new(
                endpoint, access_key, secret_key, bucket, use_ssl, region,
            )?,
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        self.inner.test_connection().await
    }

    /// 仅「不存在」（404）返回空 Vec；其它错误如实上抛 —— 调用方（同步引擎）
    /// 必须能区分「不存在」与「读取失败」，否则 push 会在网络抖动时把 manifest 从零重建。
    pub async fn read_object(&self, key: String) -> Result<Vec<u8>> {
        self.inner.read_object(key).await
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        self.inner.write_object(key, data).await
    }

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的实现会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.inner.create_exclusive(key, data).await
    }

    /// 「不存在」视为成功；其它错误如实上抛 —— 引擎依赖删除结果决定 tombstone 是否已被远端接收。
    pub async fn delete_object(&self, key: String) -> Result<()> {
        self.inner.delete_object(key).await
    }

    /// HEAD 请求取 Last-Modified，不存在返回空字符串。调用方只判空/非空，不解析格式。
    pub async fn stat_object(&self, key: String) -> Result<String> {
        self.inner.stat_object(key).await
    }
}
