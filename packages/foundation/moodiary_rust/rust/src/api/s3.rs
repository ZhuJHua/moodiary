use anyhow::Result;
use flutter_rust_bridge::frb;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use minio::s3::builders::{PutObject, UploadPart};
use minio::s3::creds::StaticProvider;
use minio::s3::error::{Error as MinioError, NetworkError, S3ServerError};
use minio::s3::http::BaseUrl;
use minio::s3::minio_error_response::MinioErrorCode;
use minio::s3::multimap_ext::{Multimap, MultimapExt};
use minio::s3::segmented_bytes::SegmentedBytes;
use minio::s3::types::{BucketName, ObjectKey, S3Api};
use minio::s3::MinioClient;

/// 条件写冲突（412 Precondition Failed，对象已存在）。不同 S3 实现把 412 包装成不同形态，全部覆盖。
fn s3_is_precondition_failed(e: &MinioError) -> bool {
    match e {
        MinioError::Network(NetworkError::ServerError(412)) => true,
        MinioError::S3Server(S3ServerError::HttpError(412, _)) => true,
        MinioError::S3Server(S3ServerError::InvalidServerResponse {
            http_status_code: 412,
            ..
        }) => true,
        MinioError::S3Server(S3ServerError::S3Error(resp)) => resp
            .code()
            .to_string()
            .eq_ignore_ascii_case("preconditionfailed"),
        _ => false,
    }
}

/// 「对象 / bucket 不存在」（而非网络 / 认证等真实故障）。
fn s3_is_not_found(e: &MinioError) -> bool {
    if let MinioError::S3Server(S3ServerError::S3Error(resp)) = e {
        matches!(
            resp.code(),
            MinioErrorCode::NoSuchKey
                | MinioErrorCode::NoSuchBucket
                | MinioErrorCode::ResourceNotFound
        )
    } else {
        false
    }
}

#[frb(opaque)]
pub struct S3Client {
    client: MinioClient,
    bucket: String,
    /// bucket 已确认存在的进程内缓存，省去每次 write 多一次 bucket_exists 往返。
    bucket_ensured: AtomicBool,
}

impl S3Client {
    pub fn new(
        endpoint: String,
        access_key: String,
        secret_key: String,
        bucket: String,
        use_ssl: bool,
        _region: Option<String>,
    ) -> Result<S3Client> {
        let scheme = if use_ssl { "https" } else { "http" };
        let base_url = format!("{scheme}://{endpoint}")
            .parse::<BaseUrl>()
            .map_err(|e| anyhow::anyhow!("Invalid endpoint URL: {e}"))?;

        let provider = StaticProvider::new(&access_key, &secret_key, None);
        let client = MinioClient::new(base_url, Some(provider), None, None)
            .map_err(|e| anyhow::anyhow!("Failed to create MinIO client: {e}"))?;

        Ok(S3Client {
            client,
            bucket,
            bucket_ensured: AtomicBool::new(false),
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        let resp = self
            .client
            .bucket_exists(&self.bucket)
            .map_err(|e| anyhow::anyhow!("Bucket name invalid: {e}"))?
            .build()
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("Connection failed: {e}"))?;
        Ok(resp.exists())
    }

    /// 确保 bucket 存在，不存在则创建；确认后缓存，之后的写不再重复往返。
    pub async fn ensure_bucket(&self) -> Result<()> {
        if self.bucket_ensured.load(Ordering::Relaxed) {
            return Ok(());
        }
        let exists = self.test_connection().await?;
        if !exists {
            self.client
                .create_bucket(&self.bucket)
                .map_err(|e| anyhow::anyhow!("Bucket name invalid: {e}"))?
                .build()
                .send()
                .await
                .map_err(|e| anyhow::anyhow!("Failed to create bucket: {e}"))?;
        }
        self.bucket_ensured.store(true, Ordering::Relaxed);
        Ok(())
    }

    /// 仅「不存在」（NoSuchKey 等）返回空 Vec；其它错误如实上抛 —— 调用方（同步引擎）
    /// 必须能区分「不存在」与「读取失败」，否则 push 会在网络抖动时把 manifest 从零重建。
    pub async fn read_object(&self, key: String) -> Result<Vec<u8>> {
        let resp = match self
            .client
            .get_object_fast(&self.bucket, &key, None)
            .await
        {
            Ok(resp) => resp,
            Err(e) if s3_is_not_found(&e) => return Ok(Vec::new()),
            Err(e) => return Err(anyhow::anyhow!("Failed to read {key}: {e}")),
        };

        let bytes = resp
            .bytes()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to read object content: {e}"))?;

        Ok(bytes.to_vec())
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        self.ensure_bucket().await?;

        let sb = SegmentedBytes::from(bytes::Bytes::from(data));
        self.client
            .put_object(&self.bucket, &key, sb)
            .map_err(|e| anyhow::anyhow!("Invalid params: {e}"))?
            .build()
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to write object: {e}"))?;
        Ok(())
    }

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的实现会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.ensure_bucket().await?;

        let mut headers = Multimap::new();
        headers.add("if-none-match", "*");
        let sb = SegmentedBytes::from(bytes::Bytes::from(data));
        // 公开 builder 不暴露 extra_headers，按其内部实现直接构造 UploadPart 以注入条件头。
        let inner = UploadPart::builder()
            .client(self.client.clone())
            .bucket(
                BucketName::new(&self.bucket)
                    .map_err(|e| anyhow::anyhow!("Invalid bucket: {e}"))?,
            )
            .object(
                ObjectKey::new(&key)
                    .map_err(|e| anyhow::anyhow!("Invalid key: {e}"))?,
            )
            .data(Arc::new(sb))
            .extra_headers(headers)
            .build();
        let result = PutObject::builder().inner(inner).build().send().await;
        match result {
            Ok(_) => Ok(true),
            Err(e) if s3_is_precondition_failed(&e) => Ok(false),
            Err(e) => Err(anyhow::anyhow!("Failed to create {key}: {e}")),
        }
    }

    /// 「不存在」视为成功；其它错误如实上抛 —— 引擎依赖删除结果决定 tombstone 是否已被远端接收。
    pub async fn delete_object(&self, key: String) -> Result<()> {
        let result = self
            .client
            .delete_object(&self.bucket, key.clone())
            .map_err(|e| anyhow::anyhow!("Invalid params: {e}"))?
            .build()
            .send()
            .await;
        match result {
            Ok(_) => Ok(()),
            Err(e) if s3_is_not_found(&e) => Ok(()),
            Err(e) => Err(anyhow::anyhow!("Failed to delete {key}: {e}")),
        }
    }

    /// HEAD 请求取 Last-Modified（ISO 8601），不存在返回空字符串。
    pub async fn stat_object(&self, key: String) -> Result<String> {
        let resp = match self
            .client
            .stat_object(&self.bucket, &key)
            .map_err(|e| anyhow::anyhow!("Invalid params: {e}"))?
            .build()
            .send()
            .await
        {
            Ok(r) => r,
            Err(_) => return Ok(String::new()),
        };
        match resp.last_modified() {
            Ok(Some(t)) => Ok(t.to_rfc3339()),
            _ => Ok(String::new()),
        }
    }
}
