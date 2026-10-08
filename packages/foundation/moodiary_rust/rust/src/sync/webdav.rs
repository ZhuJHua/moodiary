use super::{
    kind_of_reqwest, kind_of_status, req_err, tagged, xml_elements, xml_has_element, xml_text,
};
use crate::api::ExclusiveCreate;
use anyhow::Result;
use bytes::Bytes;
use percent_encoding::{AsciiSet, NON_ALPHANUMERIC, percent_decode_str, utf8_percent_encode};
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

const PATH_KEEP: &AsciiSet = &NON_ALPHANUMERIC
    .remove(b'/')
    .remove(b'-')
    .remove(b'_')
    .remove(b'.')
    .remove(b'~');

fn percent_decode(s: &str) -> String {
    percent_decode_str(s).decode_utf8_lossy().into_owned()
}

fn percent_encode_path(path: &str) -> String {
    utf8_percent_encode(path, PATH_KEEP).to_string()
}

fn parse_multistatus(xml: &str) -> Vec<(String, bool)> {
    xml_elements(xml, "response")
        .into_iter()
        .filter_map(|r| {
            let href = xml_text(xml_elements(r, "href").first()?);
            Some((href, xml_has_element(r, "collection")))
        })
        .collect()
}

fn root_prefix(base: &url::Url, root: &str) -> String {
    format!(
        "{}/{}",
        percent_decode(base.path()).trim_end_matches('/'),
        root
    )
}

fn href_to_rel(base: &url::Url, prefix: &str, href: &str) -> Option<String> {
    let path = percent_decode(base.join(href).ok()?.path());
    let rest = path.strip_prefix(prefix)?;
    if !rest.is_empty() && !rest.starts_with('/') {
        return None;
    }
    Some(rest.trim_matches('/').to_owned())
}

pub struct DavClient {
    client: reqwest_dav::Client,
    base: url::Url,
    root: String,
    created_dirs: Mutex<HashSet<String>>,
}

impl DavClient {
    pub fn new(base_url: String, username: String, password: String) -> Result<DavClient> {
        let base: url::Url = base_url
            .parse()
            .map_err(|e| anyhow::anyhow!("Invalid WebDAV URL: {e}"))?;
        let client = ClientBuilder::new()
            .set_agent(crate::http::client::shared()?)
            .set_host(base_url)
            .set_auth(Auth::Basic(username, password))
            .build()
            .map_err(|e| anyhow::anyhow!("Failed to create WebDAV client: {e}"))?;

        Ok(DavClient {
            client,
            base,
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

    pub async fn list_objects(&self) -> Result<Vec<String>> {
        let mut keys = Vec::new();
        let mut seen = HashSet::from([String::new()]);
        let mut pending = vec![String::new()];
        let prefix = root_prefix(&self.base, &self.root);
        while let Some(dir) = pending.pop() {
            let path = if dir.is_empty() {
                format!("{}/", self.root)
            } else {
                format!("{}/{}/", self.root, percent_encode_path(&dir))
            };
            let resp = self
                .client
                .list_raw(&path, Depth::Number(1))
                .await
                .map_err(|e| dav_err(e, "Failed to list"))?;
            let status = resp.status().as_u16();
            if status == 404 {
                continue;
            }
            if !resp.status().is_success() {
                return Err(tagged(
                    kind_of_status(status),
                    format!("List failed: HTTP {status}"),
                ));
            }
            let body = resp
                .text()
                .await
                .map_err(|e| req_err(e, "Failed to read list response"))?;
            for (href, is_collection) in parse_multistatus(&body) {
                let Some(rel) = href_to_rel(&self.base, &prefix, &href) else {
                    continue;
                };
                if rel.is_empty() || rel == dir {
                    continue;
                }
                if !is_collection {
                    keys.push(rel);
                } else if seen.insert(rel.clone()) {
                    pending.push(rel);
                }
            }
        }
        Ok(keys)
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

    #[test]
    fn multistatus_hrefs_resolve_against_the_base() {
        let xml = r#"<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
<d:response><d:href>/dav/moodiary/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>
<d:response><d:href>http://h:80/dav/moodiary/diary/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>
<d:response><d:href>/dav/moodiary/manifest.json</d:href><d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat></d:response>
<d:response><d:href>/dav/moodiary/media/a%20b%26c.png</d:href><d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat></d:response>
<d:response><d:href>/dav/moodiary-other/x.json</d:href><d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat></d:response>
</d:multistatus>"#;
        let base: url::Url = "http://h/dav".parse().unwrap();
        let prefix = root_prefix(&base, "moodiary");
        let rels: Vec<_> = parse_multistatus(xml)
            .into_iter()
            .map(|(h, c)| (href_to_rel(&base, &prefix, &h), c))
            .collect();
        assert_eq!(
            rels,
            vec![
                (Some(String::new()), true),
                (Some("diary".into()), true),
                (Some("manifest.json".into()), false),
                (Some("media/a b&c.png".into()), false),
                (None, false),
            ]
        );
    }

    #[test]
    fn percent_codec_round_trips_paths() {
        assert_eq!(percent_decode("a%20b%E4%B8%AD%zz%"), "a b中%zz%");
        assert_eq!(percent_decode("%e4%b8%ad%4"), "中%4");
        for c in 0u8..=0x7f {
            let s = (c as char).to_string();
            let want = if c.is_ascii_alphanumeric() || b"/-_.~".contains(&c) {
                s.clone()
            } else {
                format!("%{c:02X}")
            };
            assert_eq!(percent_encode_path(&s), want);
        }
        assert_eq!(
            percent_encode_path("media/a b&中.png"),
            "media/a%20b%26%E4%B8%AD.png"
        );
        assert_eq!(percent_decode(&percent_encode_path("x y/中")), "x y/中");
    }

    #[tokio::test]
    async fn list_objects_walks_collections_depth_one() {
        let handler: HandlerFn = Arc::new(move |req: HttpServerRequest| {
            Box::pin(async move {
                let entry = |href: &str, dir: bool| {
                    format!(
                        "<response><href>{href}</href><propstat><prop><resourcetype>{}</resourcetype></prop></propstat></response>",
                        if dir { "<collection/>" } else { "" }
                    )
                };
                let depth_one = req
                    .headers
                    .iter()
                    .any(|kv| kv.key.eq_ignore_ascii_case("depth") && kv.value == "1");
                let body = match (req.method.as_str(), req.path.trim_end_matches('/')) {
                    ("PROPFIND", _) if !depth_one => None,
                    ("PROPFIND", "/moodiary") => Some(format!(
                        "{}{}{}",
                        entry("/moodiary/", true),
                        entry("/moodiary/manifest.json", false),
                        entry("/moodiary/diary/", true)
                    )),
                    ("PROPFIND", "/moodiary/diary") => Some(format!(
                        "{}{}",
                        entry("/moodiary/diary/", true),
                        entry("/moodiary/diary/a%201.json", false)
                    )),
                    _ => None,
                };
                match body {
                    Some(b) => HttpServerResponse {
                        status: 207,
                        headers: vec![],
                        body: format!("<multistatus xmlns=\"DAV:\">{b}</multistatus>").into_bytes(),
                        body_file_path: None,
                    },
                    None => HttpServerResponse {
                        status: 404,
                        headers: vec![],
                        body: vec![],
                        body_file_path: None,
                    },
                }
            })
        });
        let (mut server, client) = serve(handler, "list").await;
        let mut keys = client.list_objects().await.unwrap();
        keys.sort();
        assert_eq!(keys, vec!["diary/a 1.json", "manifest.json"]);
        server.stop();
    }

    #[tokio::test]
    async fn list_objects_on_a_missing_root_is_empty() {
        let handler: HandlerFn = Arc::new(move |_| {
            Box::pin(async move {
                HttpServerResponse {
                    status: 404,
                    headers: vec![],
                    body: vec![],
                    body_file_path: None,
                }
            })
        });
        let (mut server, client) = serve(handler, "list404").await;
        assert!(client.list_objects().await.unwrap().is_empty());
        server.stop();
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
