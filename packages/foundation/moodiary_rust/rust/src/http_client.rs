//! 共享 HTTP 客户端。reqwest 0.13 默认用 rustls-platform-verifier 校验证书，该校验器在
//! Android 上需平台上下文初始化、否则首个 TLS 连接即 panic。这里改用内置 webpki 根证书
//! 自建 rustls 配置绕开它，assistant（rig）与 webdav（reqwest_dav）复用同一个客户端。
//! minio 走的是 reqwest 0.12（默认即 webpki 根），不受影响、无需注入。

use std::sync::{Arc, OnceLock};

use anyhow::Result;

/// 走内置 webpki 根证书的 reqwest 客户端，只构造一次并复用连接池。
pub(crate) fn webpki_client() -> Result<reqwest::Client> {
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    if let Some(client) = CLIENT.get() {
        return Ok(client.clone());
    }
    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let tls = rustls::ClientConfig::builder_with_provider(Arc::new(
        rustls::crypto::aws_lc_rs::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| anyhow::anyhow!("failed to init rustls config: {e}"))?
    .with_root_certificates(roots)
    .with_no_client_auth();
    let client = reqwest::Client::builder()
        .use_preconfigured_tls(tls)
        .build()
        .map_err(|e| anyhow::anyhow!("failed to build http client: {e}"))?;
    let _ = CLIENT.set(client.clone());
    Ok(client)
}
