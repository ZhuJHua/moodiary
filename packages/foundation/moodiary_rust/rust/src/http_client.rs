//! 共享 HTTP 客户端。reqwest 0.13（rig / reqwest_dav 用）默认用 rustls-platform-verifier
//! 校验证书；该校验器**只有 Android** 需要用平台 Context 初始化，未初始化时首个 TLS 连接
//! 即 panic。iOS/macOS/Windows/Linux 的平台校验器开箱即用，且能认系统信任库里的自签 /
//! 企业 CA（自建 NAS、公司代理等），所以**只在 Android** 改用内置 webpki 根证书绕开，其余
//! 平台保持默认（等价于不注入）。minio 走 reqwest 0.12（默认即 webpki），不受影响。

use std::sync::{Arc, OnceLock};

use anyhow::Result;

/// 供 assistant（rig）/ webdav（reqwest_dav）注入的 HTTP 客户端。
/// Android 走内置 webpki 根证书；其余平台返回默认客户端（== 二者内部默认，行为不变）。
pub(crate) fn platform_http_client() -> Result<reqwest::Client> {
    if cfg!(target_os = "android") {
        webpki_client()
    } else {
        Ok(reqwest::Client::default())
    }
}

/// 自定义 client（超时 / 重定向 / UA 等）的基础 builder（供 api::http::HttpClient 用）。
/// 与 [platform_http_client] 同源：Android 预置内置 webpki 根的 TLS，其余平台用 reqwest
/// 默认 TLS。
pub(crate) fn platform_client_builder() -> Result<reqwest::ClientBuilder> {
    let builder = reqwest::Client::builder();
    if cfg!(target_os = "android") {
        Ok(builder.use_preconfigured_tls(android_tls_config()?.clone()))
    } else {
        Ok(builder)
    }
}

/// 走内置 webpki 根证书、绕开平台校验器的 rustls 配置，只构造一次。
fn android_tls_config() -> Result<&'static rustls::ClientConfig> {
    static CONFIG: OnceLock<rustls::ClientConfig> = OnceLock::new();
    if let Some(config) = CONFIG.get() {
        return Ok(config);
    }
    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let config = rustls::ClientConfig::builder_with_provider(Arc::new(
        rustls::crypto::aws_lc_rs::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| anyhow::anyhow!("failed to init rustls config: {e}"))?
    .with_root_certificates(roots)
    .with_no_client_auth();
    let _ = CONFIG.set(config);
    Ok(CONFIG.get().unwrap())
}

/// 走内置 webpki 根证书的 reqwest 客户端，只构造一次并复用连接池。
fn webpki_client() -> Result<reqwest::Client> {
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    if let Some(client) = CLIENT.get() {
        return Ok(client.clone());
    }
    let client = reqwest::Client::builder()
        .use_preconfigured_tls(android_tls_config()?.clone())
        .build()
        .map_err(|e| anyhow::anyhow!("failed to build http client: {e}"))?;
    let _ = CLIENT.set(client.clone());
    Ok(client)
}
