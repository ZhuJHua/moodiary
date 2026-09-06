use super::{kind_of_reqwest, kind_of_status, tagged};
use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};

use crate::http::client::shared as shared_http_client;

const SIGN_TTL: Duration = Duration::from_secs(300);

fn effective_style(url: &url::Url, bucket: &str, https: bool) -> UrlStyle {
    let host_forces_path = match url.host() {
        Some(url::Host::Domain(h)) => h.eq_ignore_ascii_case("localhost"),
        Some(url::Host::Ipv4(_) | url::Host::Ipv6(_)) => true,
        None => false,
    };
    if host_forces_path || (bucket.contains('.') && https) || !is_dns_compatible_bucket(bucket) {
        UrlStyle::Path
    } else {
        UrlStyle::VirtualHost
    }
}

fn is_dns_compatible_bucket(bucket: &str) -> bool {
    let b = bucket.as_bytes();
    if !(3..=63).contains(&b.len()) {
        return false;
    }
    let ok_char = |c: &u8| c.is_ascii_lowercase() || c.is_ascii_digit();
    if !ok_char(&b[0]) || !ok_char(&b[b.len() - 1]) {
        return false;
    }
    if !b.iter().all(|c| ok_char(c) || *c == b'-' || *c == b'.') {
        return false;
    }
    let no_dot_dash = !b
        .windows(2)
        .any(|w| matches!(w, [b'.', b'-'] | [b'-', b'.']));
    no_dot_dash && !bucket.contains("..") && !is_ipv4_shaped(b)
}

fn is_ipv4_shaped(bytes: &[u8]) -> bool {
    let (mut dots, mut has_digit) = (0, false);
    for &c in bytes {
        if c.is_ascii_digit() {
            has_digit = true;
        } else if c == b'.' {
            if !has_digit {
                return false;
            }
            dots += 1;
            has_digit = false;
        } else {
            return false;
        }
    }
    dots == 3 && has_digit
}

fn resolve_region(region: Option<String>) -> String {
    region
        .map(|r| r.trim().to_string())
        .filter(|r| !r.is_empty())
        .unwrap_or_else(|| "us-east-1".to_string())
}

pub struct S3Client {
    http: reqwest::Client,
    bucket: Bucket,
    bucket_path: Bucket,
    can_fall_back: bool,
    fell_back: AtomicBool,
    creds: Credentials,
    bucket_ensured: AtomicBool,
}

impl S3Client {
    pub fn new(
        endpoint: String,
        access_key: String,
        secret_key: String,
        bucket: String,
        use_ssl: bool,
        region: Option<String>,
    ) -> Result<S3Client> {
        let scheme = if use_ssl { "https" } else { "http" };
        let mut url: url::Url = format!("{scheme}://{endpoint}")
            .parse()
            .map_err(|e| anyhow::anyhow!("Invalid endpoint URL: {e}"))?;
        if !url.path().ends_with('/') {
            let path = format!("{}/", url.path());
            url.set_path(&path);
        }

        let region = resolve_region(region);
        let style = effective_style(&url, &bucket, use_ssl);

        let make = |style| {
            Bucket::new(url.clone(), style, bucket.clone(), region.clone())
                .map_err(|e| anyhow::anyhow!("Invalid bucket config: {e:?}"))
        };

        Ok(S3Client {
            http: shared_http_client()?,
            bucket: make(style)?,
            bucket_path: make(UrlStyle::Path)?,
            can_fall_back: matches!(style, UrlStyle::VirtualHost),
            fell_back: AtomicBool::new(false),
            creds: Credentials::new(access_key, secret_key),
            bucket_ensured: AtomicBool::new(false),
        })
    }

    fn active_bucket(&self) -> &Bucket {
        if self.fell_back.load(Ordering::Relaxed) {
            &self.bucket_path
        } else {
            &self.bucket
        }
    }

    async fn send_once(
        &self,
        method: reqwest::Method,
        url: url::Url,
        headers: &[(&str, &str)],
        body: Option<reqwest::Body>,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let mut req = self.http.request(method, url);
        for (key, value) in headers {
            req = req.header(*key, *value);
        }
        if let Some(body) = body {
            req = req.body(body);
        }
        req.send().await
    }

    async fn send(
        &self,
        method: reqwest::Method,
        sign: impl Fn(&Bucket) -> url::Url,
        headers: &[(&str, &str)],
        body: Option<reqwest::Body>,
    ) -> Result<reqwest::Response> {
        let retryable =
            self.can_fall_back && body.is_none() && !self.fell_back.load(Ordering::Relaxed);
        let url = sign(self.active_bucket());
        match self.send_once(method.clone(), url, headers, body).await {
            Ok(resp) => Ok(resp),
            Err(e) if retryable && e.is_connect() => {
                self.fell_back.store(true, Ordering::Relaxed);
                self.send_once(method, sign(&self.bucket_path), headers, None)
                    .await
                    .map_err(|e| tagged(kind_of_reqwest(&e), e))
            }
            Err(e) => Err(tagged(kind_of_reqwest(&e), e)),
        }
    }

    async fn fail(op: &str, resp: reqwest::Response) -> anyhow::Error {
        let status = resp.status().as_u16();
        let body = resp.text().await.unwrap_or_default();
        let body: String = body.chars().take(512).collect();
        let hint = if body.contains("AuthorizationHeaderMalformed") {
            "（若服务端有固定区域，请在同步设置里填写正确的 region）"
        } else if status == 403 {
            "（检查 Access Key 的权限：至少需要对象的读、写、删）"
        } else {
            ""
        };
        tagged(
            kind_of_status(status),
            format!("{op} failed: HTTP {status} {body}{hint}"),
        )
    }

    pub async fn test_connection(&self) -> Result<bool> {
        let resp = self
            .send(
                reqwest::Method::HEAD,
                |b| b.head_bucket(Some(&self.creds)).sign(SIGN_TTL),
                &[],
                None,
            )
            .await?;
        match resp.status().as_u16() {
            200..=299 => Ok(true),
            404 => Ok(false),
            403 => Ok(true),
            _ => Err(Self::fail("Connection", resp).await),
        }
    }

    pub async fn ensure_bucket(&self) -> Result<()> {
        if self.bucket_ensured.load(Ordering::Relaxed) {
            return Ok(());
        }
        if !self.test_connection().await? {
            let url = self.bucket_path.create_bucket(&self.creds).sign(SIGN_TTL);
            let resp = self
                .send_once(reqwest::Method::PUT, url, &[], None)
                .await
                .map_err(|e| tagged(kind_of_reqwest(&e), e))?;
            if !resp.status().is_success() && resp.status().as_u16() != 409 {
                return Err(Self::fail("Create bucket", resp).await);
            }
        }
        self.bucket_ensured.store(true, Ordering::Relaxed);
        Ok(())
    }

    pub async fn read_object(&self, key: String) -> Result<Option<Vec<u8>>> {
        let resp = self
            .send(
                reqwest::Method::GET,
                |b| b.get_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                None,
            )
            .await?;
        if resp.status().as_u16() == 404 {
            return Ok(None);
        }
        if !resp.status().is_success() {
            return Err(Self::fail(&format!("Read {key}"), resp).await);
        }
        crate::http::client::read_body(resp)
            .await
            .map(Some)
            .map_err(|e| tagged(kind_of_reqwest(&e), format!("Failed to read object content: {e}")))
    }

    pub async fn write_object(&self, key: String, data: Vec<u8>) -> Result<()> {
        self.ensure_bucket().await?;
        let resp = self
            .send(
                reqwest::Method::PUT,
                |b| b.put_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                Some(data.into()),
            )
            .await?;
        if !resp.status().is_success() {
            return Err(Self::fail(&format!("Write {key}"), resp).await);
        }
        Ok(())
    }

    pub async fn read_object_to_file(&self, key: String, file_path: String) -> Result<bool> {
        let resp = self
            .send(
                reqwest::Method::GET,
                |b| b.get_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                None,
            )
            .await?;
        if resp.status().as_u16() == 404 {
            return Ok(false);
        }
        if !resp.status().is_success() {
            return Err(Self::fail(&format!("Read {key}"), resp).await);
        }
        crate::http::client::write_body_to_file(resp, &file_path).await?;
        Ok(true)
    }

    pub async fn write_object_file(&self, key: String, file_path: String) -> Result<()> {
        self.ensure_bucket().await?;
        let (body, len) = crate::http::client::file_body(&file_path).await?;
        let len = len.to_string();
        let resp = self
            .send(
                reqwest::Method::PUT,
                |b| b.put_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[("content-length", len.as_str())],
                Some(body),
            )
            .await?;
        if resp.status().is_redirection() {
            let location = resp
                .headers()
                .get(reqwest::header::LOCATION)
                .and_then(|v| v.to_str().ok())
                .unwrap_or("(no location)")
                .to_owned();
            return Err(anyhow::anyhow!(
                "Write {key}: 服务端要求重定向到 {location}，通常是 endpoint / region 填错。\
                 预签名 URL 无法跟随重定向，请直接填写对象所在区域的 endpoint。"
            ));
        }
        if !resp.status().is_success() {
            return Err(Self::fail(&format!("Write {key}"), resp).await);
        }
        Ok(())
    }

    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.ensure_bucket().await?;
        let resp = self
            .send(
                reqwest::Method::PUT,
                |b| {
                    let mut action = b.put_object(Some(&self.creds), &key);
                    action.headers_mut().insert("if-none-match", "*");
                    action.sign(SIGN_TTL)
                },
                &[("if-none-match", "*")],
                Some(data.into()),
            )
            .await?;
        match resp.status().as_u16() {
            412 => Ok(false),
            200..=299 => Ok(true),
            _ => Err(Self::fail(&format!("Create {key}"), resp).await),
        }
    }

    pub async fn delete_object(&self, key: String) -> Result<()> {
        let resp = self
            .send(
                reqwest::Method::DELETE,
                |b| b.delete_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                None,
            )
            .await?;
        match resp.status().as_u16() {
            404 | 200..=299 => Ok(()),
            _ => Err(Self::fail(&format!("Delete {key}"), resp).await),
        }
    }

    pub async fn stat_object(&self, key: String) -> Result<String> {
        let resp = self
            .send(
                reqwest::Method::HEAD,
                |b| b.head_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                None,
            )
            .await
            .map_err(|e| anyhow::anyhow!("Stat request failed: {e:#}"))?;
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
            .get(reqwest::header::LAST_MODIFIED)
            .and_then(|v| v.to_str().ok())
            .unwrap_or_default()
            .to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn style(endpoint: &str, bucket: &str, https: bool) -> &'static str {
        let url: url::Url = endpoint.parse().unwrap();
        match effective_style(&url, bucket, https) {
            UrlStyle::VirtualHost => "virtual",
            UrlStyle::Path => "path",
        }
    }

    #[test]
    fn domains_default_to_virtual_host() {
        for endpoint in [
            "https://s3.eu-west-1.amazonaws.com",
            "https://oss-cn-hangzhou.aliyuncs.com",
            "https://minio.example.com",
            "https://abc.r2.cloudflarestorage.com",
        ] {
            assert_eq!(style(endpoint, "diary", true), "virtual", "{endpoint}");
        }
    }

    #[test]
    fn ip_and_localhost_force_path() {
        for endpoint in [
            "http://192.168.1.10:9000",
            "http://[::1]:9000",
            "http://localhost:9000",
        ] {
            assert_eq!(style(endpoint, "diary", false), "path", "{endpoint}");
        }
    }

    #[test]
    fn virtual_host_falls_back_when_bucket_cannot_be_a_hostname() {
        let aws = "https://s3.eu-west-1.amazonaws.com";
        assert_eq!(style(aws, "my.diary", true), "path");
        assert_eq!(style(aws, "my.diary", false), "virtual");
        for bad in [
            "MyDiary",
            "abC",
            "my_diary",
            "abc def",
            "ab",
            "-diary",
            "diary-",
            ".diary",
            "diary.",
            "bucket.-name",
            "bucket-.name",
            "192.168.1.1",
            "0.0.0.0",
        ] {
            assert_eq!(style(aws, bad, false), "path", "{bad}");
        }
        for good in ["a--b--x-s3", "abc.def.ghi.jkl", "1a2.2b3.3c4.4d5.5e6"] {
            assert_eq!(style(aws, good, false), "virtual", "{good}");
        }
        assert_eq!(
            style(aws, &format!("a{}b", "c".repeat(61)), false),
            "virtual"
        );
        assert_eq!(style(aws, &format!("a{}b", "c".repeat(62)), false), "path");
    }

    #[test]
    fn region_is_user_supplied() {
        assert_eq!(resolve_region(Some("eu-west-1".into())), "eu-west-1");
        assert_eq!(resolve_region(Some("auto".into())), "auto");
        assert_eq!(resolve_region(None), "us-east-1");
        assert_eq!(resolve_region(Some("".into())), "us-east-1");
        assert_eq!(resolve_region(Some("  ".into())), "us-east-1");
        assert_eq!(resolve_region(Some(" eu-west-1 ".into())), "eu-west-1");
    }

    #[test]
    fn path_style_keeps_endpoint_path_prefix() {
        let client = S3Client::new(
            "localhost/gateway".into(),
            "ak".into(),
            "sk".into(),
            "moodiary".into(),
            true,
            None,
        )
        .expect("client builds");
        assert_eq!(
            client.bucket.base_url().as_str(),
            "https://localhost/gateway/moodiary/"
        );
    }

    #[test]
    fn virtual_host_style_prefixes_bucket() {
        let client = S3Client::new(
            "s3.eu-west-1.amazonaws.com".into(),
            "ak".into(),
            "sk".into(),
            "moodiary".into(),
            true,
            Some("eu-west-1".into()),
        )
        .expect("client builds");
        assert_eq!(
            client.bucket.base_url().as_str(),
            "https://moodiary.s3.eu-west-1.amazonaws.com/"
        );
        assert_eq!(client.bucket.region(), "eu-west-1");
    }
}
