use std::sync::OnceLock;

use anyhow::Result;

fn ensure_provider() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

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
    let config = rustls::ClientConfig::builder()
        .with_root_certificates(rustls::RootCertStore {
            roots: webpki_roots::TLS_SERVER_ROOTS.to_vec(),
        })
        .with_no_client_auth();
    let _ = CONFIG.set(config);
    Ok(CONFIG.get().unwrap())
}

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

pub async fn file_body(path: &str) -> anyhow::Result<(reqwest::Body, u64)> {
    let file = tokio::fs::File::open(path).await?;
    let len = file.metadata().await?.len();
    Ok((
        reqwest::Body::wrap_stream(tokio_util::io::ReaderStream::with_capacity(file, 64 * 1024)),
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
