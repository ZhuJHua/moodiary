//! rig 用的 reqwest Client。两个坑收口在这里（与 fast_http 的 client.rs 同一份逻辑）：
//! 1. reqwest 开的是 `rustls-no-provider`（避开 aws-lc-rs），建 client 时走
//!    `CryptoProvider::get_default()`，进程里没装就直接 panic。
//! 2. reqwest 默认的 rustls-platform-verifier **只有 Android** 需要平台 Context
//!    初始化，未初始化时首个 TLS 连接即 panic；其余平台开箱即用，且能认系统信任库
//!    里的自签 / 企业 CA（自建 NAS、公司代理），所以只在 Android 换内置 webpki 根。

use std::sync::OnceLock;

use anyhow::Result;

fn ensure_provider() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        // 已装过返回 Err 属正常竞态。
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

/// 进程内一个，连接池共享。
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

fn builder() -> Result<reqwest::ClientBuilder> {
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
    let config = rustls::ClientConfig::builder()
        .with_root_certificates(rustls::RootCertStore {
            roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
        })
        .with_no_client_auth();
    let _ = CONFIG.set(config);
    Ok(CONFIG.get().unwrap())
}
