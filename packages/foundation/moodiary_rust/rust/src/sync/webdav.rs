use super::{kind_of_reqwest, kind_of_status, tagged};
use crate::api::ExclusiveCreate;
use anyhow::Result;
use bytes::Bytes;
use reqwest_dav::re_exports::reqwest::Method;
use reqwest_dav::{Auth, ClientBuilder, Dav2xx, Depth};
use std::collections::HashSet;
use tokio::sync::Mutex;

const OCTET_STREAM: &str = "application/octet-stream";

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

fn wants_repair(status: Option<u16>) -> bool {
    matches!(status, Some(404) | Some(409))
}

fn dav_kind(e: &reqwest_dav::Error) -> &'static str {
    match (dav_status(e), e) {
        (Some(status), _) => kind_of_status(status),
        (None, reqwest_dav::Error::Reqwest(re)) => kind_of_reqwest(re),
        _ => "unknown",
    }
}

fn dav_err(e: reqwest_dav::Error, msg: impl std::fmt::Display) -> anyhow::Error {
    tagged(dav_kind(&e), format!("{msg}: {e}"))
}

fn req_err(e: reqwest::Error, msg: impl std::fmt::Display) -> anyhow::Error {
    tagged(kind_of_reqwest(&e), format!("{msg}: {e}"))
}

pub struct DavClient {
    client: reqwest_dav::Client,
    root: String,
    created_dirs: Mutex<HashSet<String>>,
}

impl DavClient {
    pub fn new(base_url: String, username: String, password: String) -> Result<DavClient> {
        let client = ClientBuilder::new()
            .set_agent(crate::http::client::shared()?)
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

    async fn ensure_dir(&self, dir: &str, force: bool) -> bool {
        let mut known = self.created_dirs.lock().await;
        let mut current = String::new();
        let mut created = false;
        for (i, part) in dir.split('/').filter(|s| !s.is_empty()).enumerate() {
            if i > 0 {
                current.push('/');
            }
            current.push_str(part);
            if force {
                known.remove(&current);
            } else if known.contains(&current) {
                continue;
            }
            match self.client.mkcol(&format!("{current}/")).await {
                Ok(_) => {
                    created = true;
                    known.insert(current.clone());
                }
                Err(e) if dav_status(&e) == Some(405) => {
                    known.insert(current.clone());
                }
                Err(_) => {
                    if self.client.list(&current, Depth::Number(0)).await.is_ok() {
                        known.insert(current.clone());
                    }
                }
            }
        }
        created
    }

    fn parent_dir(path: &str) -> &str {
        match path.rfind('/') {
            Some(pos) => &path[..pos],
            None => "",
        }
    }

    pub async fn test_connection(&self) -> Result<bool> {
        match self.client.list(&self.root, Depth::Number(0)).await {
            Ok(_) => Ok(true),
            Err(e) => {
                if dav_is_not_found(&e) {
                    Ok(true)
                } else {
                    Err(dav_err(e, "Connection failed"))
                }
            }
        }
    }

    pub async fn read_object(&self, key: String) -> Result<Option<Vec<u8>>> {
        let path = self.full_path(&key);
        let resp = match self.client.get(&path).await {
            Ok(r) => r,
            Err(e) if dav_is_not_found(&e) => return Ok(None),
            Err(e) => return Err(dav_err(e, format!("Failed to read {key}"))),
        };
        crate::http::client::read_body(resp)
            .await
            .map(Some)
            .map_err(|e| req_err(e, format!("Failed to read {key}")))
    }

    pub async fn read_object_to_file(&self, key: String, file_path: String) -> Result<bool> {
        let path = self.full_path(&key);
        let resp = match self.client.get(&path).await {
            Ok(r) => r,
            Err(e) if dav_is_not_found(&e) => return Ok(false),
            Err(e) => return Err(dav_err(e, format!("Failed to read {key}"))),
        };
        crate::http::client::write_body_to_file(resp, &file_path).await?;
        Ok(true)
    }

    pub async fn write_object_file(&self, key: String, file_path: String) -> Result<()> {
        let path = self.full_path(&key);
        let dir = Self::parent_dir(&path).to_owned();
        self.ensure_dir(&dir, false).await;
        let mut resp = self.put_file_once(&path, &file_path, None).await?;
        if wants_repair(Some(resp.status().as_u16())) && self.ensure_dir(&dir, true).await {
            resp = self.put_file_once(&path, &file_path, None).await?;
        }
        let resp = match redirect_target(&resp) {
            Some(location) => {
                self.put_file_once(&path, &file_path, Some(&location))
                    .await?
            }
            None => resp,
        };
        resp.dav2xx()
            .await
            .map_err(|e| dav_err(e, format!("Failed to write {key}")))?;
        Ok(())
    }

    async fn put_file_once(
        &self,
        path: &str,
        file_path: &str,
        override_url: Option<&str>,
    ) -> Result<reqwest::Response> {
        let (body, len) = crate::http::client::file_body(file_path).await?;
        let req = match override_url {
            Some(url) => crate::http::client::shared()?.put(url),
            None => self
                .client
                .start_request(Method::PUT, path)
                .await
                .map_err(|e| dav_err(e, "Failed to build request"))?,
        };
        req.header(reqwest::header::CONTENT_TYPE, OCTET_STREAM)
            .header(reqwest::header::CONTENT_LENGTH, len)
            .body(body)
            .send()
            .await
            .map_err(|e| req_err(e, format!("Failed to write {path}")))
    }

    async fn put_conditional(
        &self,
        path: &str,
        body: Bytes,
        key: &str,
    ) -> Result<reqwest::Response> {
        let req = self
            .client
            .start_request(Method::PUT, path)
            .await
            .map_err(|e| dav_err(e, "Failed to build request"))?;
        req.header(reqwest::header::CONTENT_TYPE, OCTET_STREAM)
            .header("If-None-Match", "*")
            .body(body)
            .send()
            .await
            .map_err(|e| req_err(e, format!("Failed to create {key}")))
    }

    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<ExclusiveCreate> {
        let path = self.full_path(&key);
        let dir = Self::parent_dir(&path).to_owned();
        self.ensure_dir(&dir, false).await;
        let body = Bytes::from(data);
        let mut resp = self.put_conditional(&path, body.clone(), &key).await?;
        if wants_repair(Some(resp.status().as_u16())) && self.ensure_dir(&dir, true).await {
            resp = self.put_conditional(&path, body, &key).await?;
        }
        match resp.status().as_u16() {
            412 => return Ok(ExclusiveCreate::Exists),
            400 | 405 | 501 => return Ok(ExclusiveCreate::Unsupported),
            _ => {}
        }
        resp.dav2xx()
            .await
            .map_err(|e| dav_err(e, format!("Failed to create {key}")))?;
        Ok(ExclusiveCreate::Created)
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        let path = self.full_path(&key);
        let dir = Self::parent_dir(&path).to_owned();
        self.ensure_dir(&dir, false).await;
        let body = Bytes::from(data);
        match self.client.put(&path, body.clone()).await {
            Ok(_) => Ok(()),
            Err(e) if wants_repair(dav_status(&e)) && self.ensure_dir(&dir, true).await => self
                .client
                .put(&path, body)
                .await
                .map_err(|e| dav_err(e, format!("Failed to write {key}"))),
            Err(e) => Err(dav_err(e, format!("Failed to write {key}"))),
        }
    }

    pub async fn delete_object(&self, key: String) -> Result<()> {
        let path = self.full_path(&key);
        match self.client.delete(&path).await {
            Ok(_) => Ok(()),
            Err(e) if dav_is_not_found(&e) => Ok(()),
            Err(e) => Err(dav_err(e, format!("Failed to delete {key}"))),
        }
    }

    pub async fn stat_object(&self, key: String) -> Result<String> {
        let path = self.full_path(&key);
        let req = self
            .client
            .start_request(Method::HEAD, &path)
            .await
            .map_err(|e| dav_err(e, "Failed to build request"))?;
        let resp = req
            .send()
            .await
            .map_err(|e| req_err(e, "Stat request failed"))?;
        if resp.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(String::new());
        }
        if !resp.status().is_success() {
            return Err(tagged(
                kind_of_status(resp.status().as_u16()),
                format!("Stat failed: HTTP {}", resp.status()),
            ));
        }
        Ok(resp
            .headers()
            .get("last-modified")
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string())
            .unwrap_or_default())
    }
}

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::http::server::{HandlerFn, HttpServer, HttpServerRequest, HttpServerResponse};
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct FakeDav {
        collections: Mutex<HashSet<String>>,
        mkcols: AtomicUsize,
    }

    impl FakeDav {
        fn new() -> Arc<FakeDav> {
            Arc::new(FakeDav {
                collections: Mutex::new(HashSet::new()),
                mkcols: AtomicUsize::new(0),
            })
        }

        fn handler(state: Arc<FakeDav>) -> HandlerFn {
            Arc::new(move |req: HttpServerRequest| {
                let state = state.clone();
                Box::pin(async move {
                    let path = req.path.trim_matches('/').to_string();
                    let status = match req.method.as_str() {
                        "MKCOL" => {
                            state.mkcols.fetch_add(1, Ordering::Relaxed);
                            if state.collections.lock().await.insert(path) {
                                201
                            } else {
                                405
                            }
                        }
                        "PUT" => {
                            let parent = DavClient::parent_dir(&path).to_string();
                            if state.collections.lock().await.contains(&parent) {
                                201
                            } else {
                                409
                            }
                        }
                        _ => 200,
                    };
                    HttpServerResponse {
                        status,
                        headers: vec![],
                        body: vec![],
                        body_file_path: None,
                    }
                })
            })
        }
    }

    async fn serve(handler: HandlerFn, tag: &str) -> (HttpServer, DavClient) {
        let dir = std::env::temp_dir().join(format!("moodiary-dav-{tag}-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let server = HttpServer::start(
            0,
            true,
            dir.to_string_lossy().into_owned(),
            handler,
            Arc::new(|_, _| Box::pin(async {})),
        )
        .await
        .unwrap();
        let client = DavClient::new(
            format!("http://127.0.0.1:{}", server.port()),
            "u".into(),
            "p".into(),
        )
        .unwrap();
        (server, client)
    }

    #[tokio::test]
    async fn concurrent_first_writes_share_one_ladder() {
        let state = FakeDav::new();
        let (mut server, client) = serve(FakeDav::handler(state.clone()), "ladder").await;
        let client = Arc::new(client);
        let mut tasks = Vec::new();
        for i in 0..8 {
            let client = client.clone();
            tasks.push(tokio::spawn(async move {
                client
                    .write_object(format!("diary/{i}.json"), vec![1])
                    .await
            }));
        }
        for t in tasks {
            t.await.unwrap().unwrap();
        }
        assert_eq!(state.mkcols.load(Ordering::Relaxed), 2);
        server.stop();
    }

    #[tokio::test]
    async fn a_collection_dropped_on_the_server_is_rebuilt() {
        let state = FakeDav::new();
        let (mut server, client) = serve(FakeDav::handler(state.clone()), "rebuild").await;
        client
            .write_object("diary/a.json".into(), vec![1])
            .await
            .unwrap();
        state.collections.lock().await.clear();
        client
            .write_object("diary/b.json".into(), vec![1])
            .await
            .unwrap();
        server.stop();
    }

    #[tokio::test]
    async fn a_collection_that_refuses_mkcol_is_cached_once_confirmed() {
        let mkcols = Arc::new(AtomicUsize::new(0));
        let seen = mkcols.clone();
        let handler: HandlerFn = Arc::new(move |req: HttpServerRequest| {
            let seen = seen.clone();
            Box::pin(async move {
                let (status, body) = match req.method.as_str() {
                    "MKCOL" => {
                        seen.fetch_add(1, Ordering::Relaxed);
                        (403, String::new())
                    }
                    "PROPFIND" => (
                        207,
                        format!(
                            r#"<?xml version="1.0" encoding="utf-8"?>
<multistatus xmlns="DAV:"><response><href>{}</href><propstat>
<status>HTTP/1.1 200 OK</status>
<prop><getlastmodified>Mon, 01 Jan 2024 00:00:00 GMT</getlastmodified>
<resourcetype><collection/></resourcetype>
<getetag>"x"</getetag><getcontenttype>httpd/unix-directory</getcontenttype>
</prop></propstat></response></multistatus>"#,
                            req.path
                        ),
                    ),
                    _ => (201, String::new()),
                };
                HttpServerResponse {
                    status,
                    headers: vec![],
                    body: body.into_bytes(),
                    body_file_path: None,
                }
            })
        });
        let (mut server, client) = serve(handler, "cached").await;
        client
            .write_object("diary/a.json".into(), vec![1])
            .await
            .unwrap();
        let after_first = mkcols.load(Ordering::Relaxed);
        client
            .write_object("diary/b.json".into(), vec![1])
            .await
            .unwrap();
        assert_eq!(mkcols.load(Ordering::Relaxed), after_first);
        server.stop();
    }

    #[tokio::test]
    async fn a_server_that_refuses_mkcol_can_still_write() {
        let handler: HandlerFn = Arc::new(move |req: HttpServerRequest| {
            Box::pin(async move {
                HttpServerResponse {
                    status: if req.method == "MKCOL" { 403 } else { 201 },
                    headers: vec![],
                    body: vec![],
                    body_file_path: None,
                }
            })
        });
        let (mut server, client) = serve(handler, "nomkcol").await;
        client
            .write_object("diary/a.json".into(), vec![1])
            .await
            .unwrap();
        server.stop();
    }
}
