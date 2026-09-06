use super::{kind_of_reqwest, kind_of_status, tagged};
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

    async fn ensure_dir_cached(&self, dir: &str) -> Result<()> {
        let parts: Vec<&str> = dir.split('/').filter(|s| !s.is_empty()).collect();
        let mut current = String::new();
        for (i, part) in parts.iter().enumerate() {
            if i > 0 {
                current.push('/');
            }
            current.push_str(part);
            let known = self.created_dirs.lock().unwrap().contains(&current);
            if known {
                continue;
            }
            if let Err(e) = self.client.mkcol(&format!("{current}/")).await {
                let exists = dav_status(&e) == Some(405)
                    || self.client.list(&current, Depth::Number(0)).await.is_ok();
                if !exists {
                    return Err(dav_err(e, format!("Failed to create dir {current}")));
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
        req.header(reqwest::header::CONTENT_LENGTH, len)
            .body(body)
            .send()
            .await
            .map_err(|e| req_err(e, format!("Failed to write {path}")))
    }

    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        let path = self.full_path(&key);
        if let Some(pos) = path.rfind('/') {
            self.ensure_dir_cached(&path[..pos]).await?;
        }
        let req = self
            .client
            .start_request(Method::PUT, &path)
            .await
            .map_err(|e| dav_err(e, "Failed to build request"))?;
        let resp = req
            .header("If-None-Match", "*")
            .body(data)
            .send()
            .await
            .map_err(|e| req_err(e, format!("Failed to create {key}")))?;
        if resp.status().as_u16() == 412 {
            return Ok(false);
        }
        resp.dav2xx()
            .await
            .map_err(|e| dav_err(e, format!("Failed to create {key}")))?;
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
            .map_err(|e| dav_err(e, format!("Failed to write {key}")))?;
        Ok(())
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
