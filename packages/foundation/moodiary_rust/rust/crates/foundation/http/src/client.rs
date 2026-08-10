//! 两个坑收口在这里：
//! 1. reqwest 开的是 `rustls-no-provider`（避开 aws-lc-rs），建 client 时走
//!    `CryptoProvider::get_default()`，进程里没装就直接 panic。
//! 2. reqwest 默认的 rustls-platform-verifier **只有 Android** 需要平台 Context
//!    初始化，未初始化时首个 TLS 连接即 panic；其余平台开箱即用，且能认系统信任库
//!    里的自签 / 企业 CA（自建 NAS、公司代理），所以只在 Android 换内置 webpki 根。

use std::sync::{Arc, OnceLock};

use anyhow::Result;

fn ensure_provider() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        // 已装过返回 Err 属正常竞态。
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

/// s3 / webdav / assistant 共用，连接池共享。
pub fn shared() -> Result<reqwest::Client> {
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    if let Some(client) = CLIENT.get() {
        return Ok(client.clone());
    }
    let client = builder()?
        .build()
        .map_err(|e| anyhow::anyhow!("failed to build http client: {e}"))?;
    let _ = CLIENT.set(client.clone());
    Ok(CLIENT.get().unwrap().clone())
}

/// 给 api::http::HttpClient 用：UA / 超时 / 重定向上限在 reqwest 里是 client 级设置，
/// 做不到 per-request，所以它必须能按 Dart 传入的 settings 单独建。
pub fn builder() -> Result<reqwest::ClientBuilder> {
    ensure_provider();
    let builder = reqwest::Client::builder();
    if cfg!(target_os = "android") {
        Ok(builder.use_preconfigured_tls(android_tls_config()?.clone()))
    } else {
        Ok(builder)
    }
}

fn android_tls_config() -> Result<&'static rustls::ClientConfig> {
    static CONFIG: OnceLock<rustls::ClientConfig> = OnceLock::new();
    if let Some(config) = CONFIG.get() {
        return Ok(config);
    }
    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let config = rustls::ClientConfig::builder_with_provider(Arc::new(
        rustls::crypto::ring::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| anyhow::anyhow!("failed to init rustls config: {e}"))?
    .with_root_certificates(roots)
    .with_no_client_auth();
    let _ = CONFIG.set(config);
    Ok(CONFIG.get().unwrap())
}

/// 收响应体。不走 `Response::bytes()`：那条路先把分块拼进 `BytesMut`，再 `to_vec()`
/// 复制一遍整个 body。这里按 content-length 预分配后直接收进 `Vec`，整包只拷一次。
/// 响应体边收边落盘，不在内存里攒整份 —— 媒体对象走这条。
pub async fn write_body_to_file(resp: reqwest::Response, path: &str) -> anyhow::Result<()> {
    use tokio::io::AsyncWriteExt;

    let mut file = tokio::fs::File::create(path).await?;
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = futures::StreamExt::next(&mut stream).await {
        file.write_all(&chunk?).await?;
    }
    file.flush().await?;
    Ok(())
}

/// 本地文件作为请求体，边读边发。返回 (body, 字节数) —— 调用方要显式带
/// content-length，否则 reqwest 走 chunked，多数对象存储不收。
pub async fn file_body(path: &str) -> anyhow::Result<(reqwest::Body, u64)> {
    let file = tokio::fs::File::open(path).await?;
    let len = file.metadata().await?.len();
    Ok((
        reqwest::Body::wrap_stream(tokio_util::io::ReaderStream::new(file)),
        len,
    ))
}

pub async fn read_body(resp: reqwest::Response) -> reqwest::Result<Vec<u8>> {
    let mut out = Vec::with_capacity(resp.content_length().unwrap_or(0) as usize);
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = futures::StreamExt::next(&mut stream).await {
        out.extend_from_slice(&chunk?);
    }
    Ok(out)
}
