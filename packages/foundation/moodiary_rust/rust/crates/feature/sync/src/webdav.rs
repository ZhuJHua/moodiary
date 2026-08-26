use anyhow::Result;
use reqwest_dav::re_exports::reqwest::Method;
use reqwest_dav::{Auth, ClientBuilder, Dav2xx, Depth};
use std::collections::HashSet;
use std::sync::Mutex;

fn dav_status(e: &reqwest_dav::Error) -> Option<u16> {
    match e {
        reqwest_dav::Error::Decode(reqwest_dav::DecodeError::Server(se)) => Some(se.response_code),
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

pub struct DavClient {
    client: reqwest_dav::Client,
    root: String,
    created_dirs: Mutex<HashSet<String>>,
}

impl DavClient {
    pub fn new(base_url: String, username: String, password: String) -> Result<DavClient> {
        // 注入共享客户端：reqwest_dav 默认 agent 用 reqwest 0.13 的 rustls-platform-verifier，
        // 在 Android 上未初始化会 panic；client::shared 仅在 Android 换成内置 webpki 根。
        let client = ClientBuilder::new()
            .set_agent(moodiary_http::client::shared()?)
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
    /// 缓存则跳过以省 mkcol 往返。MKCOL 路径带尾斜杠 —— RFC 4918 两者皆可，但
    /// nginx dav 等实现要求集合以 `/` 结尾，否则直接 409。「已存在」（405）视作
    /// 成功；其它失败再用 PROPFIND 复核一次，目录确实不存在则**如实上抛** ——
    /// 吞掉错误并写入缓存会把一次创建失败固化成该目录后续所有 PUT 的 409
    /// （比 MKCOL 的原始错误难排查得多）。
    async fn ensure_dir_cached(&self, dir: &str) -> Result<()> {
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
            if let Err(e) = self.client.mkcol(&format!("{current}/")).await {
                let exists = dav_status(&e) == Some(405)
                    || self.client.list(&current, Depth::Number(0)).await.is_ok();
                if !exists {
                    return Err(anyhow::anyhow!("Failed to create dir {current}: {e}"));
                }
            }
            self.created_dirs.lock().unwrap().insert(current.clone());
        }
        Ok(())
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

    /// 仅 404（不存在）返回空 Vec；其它错误如实上抛 —— 调用方（同步引擎）必须能区分
    /// 「不存在」与「读取失败」，否则 push 会在网络抖动时把 manifest 从零重建、丢失远端独有条目。
    pub async fn read_object(&self, key: String) -> Result<Vec<u8>> {
        let path = self.full_path(&key);
        let resp = match self.client.get(&path).await {
            Ok(r) => r,
            Err(e) if dav_is_not_found(&e) => return Ok(Vec::new()),
            Err(e) => return Err(anyhow::anyhow!("Failed to read {key}: {e}")),
        };
        moodiary_http::client::read_body(resp)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to read {key}: {e}"))
    }

    /// [read_object] 的落盘版：响应体边收边写，整份不进内存。远端不存在返回 false。
    pub async fn read_object_to_file(&self, key: String, file_path: String) -> Result<bool> {
        let path = self.full_path(&key);
        let resp = match self.client.get(&path).await {
            Ok(r) => r,
            Err(e) if dav_is_not_found(&e) => return Ok(false),
            Err(e) => return Err(anyhow::anyhow!("Failed to read {key}: {e}")),
        };
        moodiary_http::client::write_body_to_file(resp, &file_path).await?;
        Ok(true)
    }

    /// [write_object] 的文件版：请求体边读边发，整份不进内存。
    ///
    /// 流式 body 不能 clone（`try_clone` 返回 None），重定向中间件会把 3xx 原样交回来，
    /// 所以这里重开文件手动跟一跳 —— 反代做 http→https 的 308 很常见。
    pub async fn write_object_file(&self, key: String, file_path: String) -> Result<()> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await?;
        }
        let resp = self.put_file_once(&path, &file_path, None).await?;
        let resp = match redirect_target(&resp) {
            Some(location) => {
                self.put_file_once(&path, &file_path, Some(&location))
                    .await?
            }
            None => resp,
        };
        resp.dav2xx()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to write {key}: {e}"))?;
        Ok(())
    }

    /// [override_url] 非空时直接 PUT 到该地址（跟随重定向用），否则走 dav 客户端的路径。
    async fn put_file_once(
        &self,
        path: &str,
        file_path: &str,
        override_url: Option<&str>,
    ) -> Result<reqwest::Response> {
        let (body, len) = moodiary_http::client::file_body(file_path).await?;
        let req = match override_url {
            Some(url) => moodiary_http::client::shared()?.put(url),
            None => self
                .client
                .start_request(Method::PUT, path)
                .await
                .map_err(|e| anyhow::anyhow!("Failed to build request: {e}"))?,
        };
        req.header(reqwest::header::CONTENT_LENGTH, len)
            .body(body)
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to write {path}: {e}"))
    }

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的服务器会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await?;
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
        if resp.status().as_u16() == 412 {
            return Ok(false);
        }
        resp.dav2xx()
            .await
            .map_err(|e| anyhow::anyhow!("Failed to create {key}: {e}"))?;
        Ok(true)
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await?;
        }
        self.client
            .put(&path, data)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to write {key}: {e}"))?;
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

    pub async fn stat_object(&self, key: String) -> Result<String> {
        let path = self.full_path(&key);
        let req = self
            .client
            .start_request(Method::HEAD, &path)
            .await
            .map_err(|e| anyhow::anyhow!("Failed to build request: {e}"))?;
        let resp = req
            .send()
            .await
            .map_err(|e| anyhow::anyhow!("Stat request failed: {e}"))?;
        // 只有 404 表示「不存在」（空串）；网络错误与 401/5xx 必须上抛，
        // 否则调用方把「远端不可达」误判成「远端没有」，已上传媒体会整体重传。
        if resp.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(String::new());
        }
        if !resp.status().is_success() {
            anyhow::bail!("Stat failed: HTTP {}", resp.status());
        }
        Ok(resp
            .headers()
            .get("last-modified")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string())
            .unwrap_or_default())
    }
}

/// 3xx 且带 Location 时返回目标地址。
fn redirect_target(resp: &reqwest::Response) -> Option<String> {
    if !resp.status().is_redirection() {
        return None;
    }
    resp.headers()
        .get(reqwest::header::LOCATION)?
        .to_str()
        .ok()
        .map(str::to_owned)
}
