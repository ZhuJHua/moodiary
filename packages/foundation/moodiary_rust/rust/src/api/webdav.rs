use anyhow::Result;
use flutter_rust_bridge::frb;
use futures::stream::{self, StreamExt};
use reqwest_dav::{Auth, ClientBuilder, Depth};
use reqwest_dav::re_exports::reqwest::Method;
use std::collections::HashSet;
use std::sync::Mutex;

pub struct BatchWriteEntry {
    pub path: String,
    pub data: Vec<u8>,
}

/// 从 reqwest_dav 错误中提取 HTTP 状态码（提取不到则 None）。
fn dav_status(e: &reqwest_dav::Error) -> Option<u16> {
    match e {
        reqwest_dav::Error::Decode(reqwest_dav::DecodeError::Server(se)) => {
            Some(se.response_code)
        }
        reqwest_dav::Error::Decode(reqwest_dav::DecodeError::StatusMismatched(sm)) => {
            Some(sm.response_code)
        }
        reqwest_dav::Error::Reqwest(re) => re.status().map(|s| s.as_u16()),
        _ => None,
    }
}

fn dav_is_not_found(e: &reqwest_dav::Error) -> bool {
    dav_status(e) == Some(404)
}

#[frb(opaque)]
pub struct DavClient {
    client: reqwest_dav::Client,
    root: String,
    /// 本进程已确认 / 创建过的远端目录集合，用于去重 mkcol 往返。
    created_dirs: Mutex<HashSet<String>>,
}

impl DavClient {
    pub fn new(
        base_url: String,
        username: String,
        password: String,
    ) -> Result<DavClient> {
        // 注入 HTTP 客户端：reqwest_dav 默认 agent 用 reqwest 0.13 的 rustls-platform-verifier，
        // 在 Android 上未初始化会 panic；platform_http_client 仅在 Android 换成内置 webpki 根。
        let client = ClientBuilder::new()
            .set_agent(crate::http_client::platform_http_client()?)
            .set_host(base_url)
            .set_auth(Auth::Basic(username, password))
            .build()
            .map_err(|e| anyhow::anyhow!("Failed to create WebDAV client: {e}"))?;

        Ok(DavClient {
            client,
            root: "moodiary".to_string(),
            created_dirs: Mutex::new(HashSet::new()),
        })
    }

    fn full_path(&self, key: &str) -> String {
        format!("{}/{}", self.root, key)
    }

    /// 逐级确保目录存在（深层目录如 `moodiary/media/image` 需中间层先存在），命中进程内
    /// 缓存则跳过以省 mkcol 往返。错误（已存在 / 405 / 409 等）一律忽略。
    async fn ensure_dir_cached(&self, dir: &str) {
        let parts: Vec<&str> = dir.split('/').filter(|s| !s.is_empty()).collect();
        let mut current = String::new();
        for (i, part) in parts.iter().enumerate() {
            if i > 0 {
                current.push('/');
            }
            current.push_str(part);
            // 锁绝不跨 await，避免 std::Mutex 的 Send 问题。
            let known = self.created_dirs.lock().unwrap().contains(&current);
            if known {
                continue;
            }
            let _ = self.client.mkcol(&current).await;
            self.created_dirs.lock().unwrap().insert(current.clone());
        }
    }

    pub async fn test_connection(&self) -> Result<bool> {
        match self.client.list(&self.root, Depth::Number(0)).await {
            Ok(_) => Ok(true),
            Err(e) => {
                // 404 表示目录不存在但服务器可达，也算连通
                if dav_is_not_found(&e) {
                    Ok(true)
                } else {
                    Err(anyhow::anyhow!("Connection failed: {e}"))
                }
            }
        }
    }

    pub async fn ensure_dir(&self, key: &str) -> Result<()> {
        let path = self.full_path(key);
        let parts: Vec<&str> = path.split('/').filter(|s| !s.is_empty()).collect();
        let mut current = String::new();
        for part in parts {
            current.push('/');
            current.push_str(part);
            let _ = self.client.mkcol(&current).await;
        }
        Ok(())
    }

    /// 仅 404（不存在）返回空 Vec；其它错误如实上抛 —— 调用方（同步引擎）必须能区分
    /// 「不存在」与「读取失败」，否则 push 会在网络抖动时把 manifest 从零重建、丢失远端独有条目。
    pub async fn read_object(&self, key: String) -> Result<Vec<u8>> {
        let path = self.full_path(&key);
        let resp = match self.client.get(&path).await {
            Ok(r) => r,
            Err(e) if dav_is_not_found(&e) => return Ok(Vec::new()),
            Err(e) => return Err(anyhow::anyhow!("Failed to read {key}: {e}")),
        };
        let bytes = resp
            .bytes()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to read {key}: {e}"))?;
        Ok(bytes.to_vec())
    }

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的服务器会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await;
        }
        let req = self
            .client
            .start_request(Method::PUT, &path)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to build request: {e}"))?;
        let resp = req
            .header("If-None-Match", "*")
            .body(data)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to create {key}: {e}"))?;
        let status = resp.status();
        if status.as_u16() == 412 {
            return Ok(false);
        }
        if !status.is_success() {
            return Err(anyhow::anyhow!("Failed to create {key}: HTTP {status}"));
        }
        Ok(true)
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await;
        }
        self.client
            .put(&path, data)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to write: {e}"))?;
        Ok(())
    }

    /// 404（不存在）视为成功；其它错误如实上抛 —— 引擎依赖删除结果决定 tombstone 是否已被远端接收。
    pub async fn delete_object(&self, key: String) -> Result<()> {
        let path = self.full_path(&key);
        match self.client.delete(&path).await {
            Ok(_) => Ok(()),
            Err(e) if dav_is_not_found(&e) => Ok(()),
            Err(e) => Err(anyhow::anyhow!("Failed to delete {key}: {e}")),
        }
    }

    /// HEAD 请求取 Last-Modified，不存在返回空字符串。
    pub async fn stat_object(&self, key: String) -> Result<String> {
        let path = self.full_path(&key);
        let req = self
            .client
            .start_request(Method::HEAD, &path)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to build request: {e}"))?;
        let resp = match req.send().await {
            Ok(r) => r,
            Err(_) => return Ok(String::new()),
        };
        if !resp.status().is_success() {
            return Ok(String::new());
        }
        Ok(resp
            .headers()
            .get("last-modified")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string())
            .unwrap_or_default())
    }

    /// 批量写入，最多 [concurrency] 个并发。
    pub async fn write_objects_batch(
        &self,
        entries: Vec<BatchWriteEntry>,
        concurrency: usize,
    ) -> Result<()> {
        // 先把父目录去重、逐级创建，再并发 PUT —— 不在每个 put 前各自 mkcol。
        let mut dirs: HashSet<String> = HashSet::new();
        for entry in &entries {
            let path = self.full_path(&entry.path);
            if let Some(pos) = path.rfind('/') {
                dirs.insert(path[..pos].to_string());
            }
        }
        for dir in &dirs {
            self.ensure_dir_cached(dir).await;
        }

        let client = &self.client;
        let root = &self.root;

        stream::iter(entries)
            .map(|entry| {
                let path = format!("{}/{}", root, entry.path);
                async move { client.put(&path, entry.data).await }
            })
            .buffer_unordered(concurrency)
            .collect::<Vec<_>>()
            .await;

        Ok(())
    }
}
