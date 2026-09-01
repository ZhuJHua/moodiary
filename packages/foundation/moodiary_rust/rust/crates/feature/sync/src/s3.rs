//! rusty-s3 是 Sans-IO 的：只算 SigV4 签名给出预签名 URL，请求走共享 reqwest 客户端。

use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use rusty_s3::{Bucket, Credentials, S3Action, UrlStyle};

use moodiary_http::client::shared as shared_http_client;

const SIGN_TTL: Duration = Duration::from_secs(300);

/// 寻址方式：默认子域名式，只在**结构上不可能**时回退路径式。判定全是结构性的，
/// 不含任何厂商域名白名单（规则取自 s3-rs 的 `resolve_addressing_style`）。
///
/// - IP / IPv6 / localhost 主机：`bucket.192.168.1.10` 不是合法主机名，`Bucket::new`
///   直接报 InvalidIpv4Address。
/// - 桶名带点 + HTTPS：通配证书按 RFC 6125 只匹配一级标签，`a.b.s3.amazonaws.com`
///   验不过，TLS 握手就失败。
/// - 桶名不是合法 DNS 标签：根本进不了主机名。
///
/// 另有一条按操作强制路径式：CreateBucket（AWS 要求，见 minio-rs 同名注释）。
/// minio 还为 GetBucketLocation 强制过，我们不调那个 API。
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

/// 桶名能否做 DNS 标签。规则对齐 aws-sdk-s3 的 `is_virtual_hostable_s3_bucket`
/// （`^[a-z\d][a-z\d\-.]{1,61}[a-z\d]$` 且非 IPv4 形状、无 `.-` / `-.` 相邻）。
/// AWS 早年允许过大写 / 下划线 / 超长的桶名，那些进不了主机名。
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
    // `.-` / `-.` 相邻会产生非法 DNS 标签；IPv4 形状的桶名不能做子域名。
    let no_dot_dash = !b
        .windows(2)
        .any(|w| matches!(w, [b'.', b'-'] | [b'-', b'.']));
    no_dot_dash && !bucket.contains("..") && !is_ipv4_shaped(b)
}

/// `^(\d+\.){3}\d+$`
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

/// region 是 SigV4 凭据域的一部分（`AK/日期/<region>/s3/aws4_request`），服务端会用它
/// 重算签名比对——它不是地址的一部分，所以除了 AWS 之外没法从 endpoint 推断
/// （R2 要求填 `auto`，域名里根本没有）。一律以用户填的为准，留空按 MinIO 默认的
/// us-east-1 处理。
fn resolve_region(region: Option<String>) -> String {
    region
        .map(|r| r.trim().to_string())
        .filter(|r| !r.is_empty())
        .unwrap_or_else(|| "us-east-1".to_string())
}

pub struct S3Client {
    http: reqwest::Client,
    /// 首选寻址方式的 Bucket，由 [`effective_style`] 定。
    bucket: Bucket,
    /// 路径式副本：CreateBucket 固定用它，子域名式连不上时也降级到它。
    bucket_path: Bucket,
    /// 首选是否为子域名式 —— 只有它才有降级余地。
    can_fall_back: bool,
    /// 已降级。子域名式要求服务端配了泛域名 DNS（自建 MinIO 默认没有），
    /// 连不上时锁定路径式，本进程后续请求不再重试。
    fell_back: AtomicBool,
    creds: Credentials,
    /// bucket 已确认存在的进程内缓存，省去每次 write 多一次 head_bucket 往返。
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
        // path-style 靠 Url::join 拼 bucket，末段不带 `/` 会被当成文件名替换掉，
        // 于是 `https://host/s3` 会拼成 `https://host/bucket/` —— 前缀路径整个丢失。
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

    /// 发请求；子域名式在**连接层**失败（DNS 解不出 `bucket.host`、证书不匹配）时，
    /// 锁定路径式并重签重试一次。
    ///
    /// 只重试无 body 的请求 —— 带 body 的写必定先经 `ensure_bucket` 的 HEAD 探测，
    /// 降级在那时就已决定；这里再重试既无必要，也要多复制一份 payload。
    ///
    /// 只认连接层错误：HTTP 状态码错（403 / 404）说明服务端已收到请求、寻址是通的，
    /// 那是凭据或对象的问题，重试只会再错一次。
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
                    .map_err(|e| anyhow::anyhow!("{e}"))
            }
            Err(e) => Err(anyhow::anyhow!("{e}")),
        }
    }

    /// 非预期状态码统一在这里成文：带上状态码与截断的响应体（S3 的错误是 XML），
    /// 比旧实现的 typed error 更好定位。403 顺带提示 region —— 它是最常见的错配。
    async fn fail(op: &str, resp: reqwest::Response) -> anyhow::Error {
        let status = resp.status().as_u16();
        let body = resp.text().await.unwrap_or_default();
        let body: String = body.chars().take(512).collect();
        let hint = if status == 403 || body.contains("AuthorizationHeaderMalformed") {
            "（若服务端有固定区域，请在同步设置里填写正确的 region）"
        } else {
            ""
        };
        anyhow::anyhow!("{op} failed: HTTP {status} {body}{hint}")
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
            _ => Err(Self::fail("Connection", resp).await),
        }
    }

    /// 确保 bucket 存在，不存在则创建；确认后缓存，之后的写不再重复往返。
    pub async fn ensure_bucket(&self) -> Result<()> {
        if self.bucket_ensured.load(Ordering::Relaxed) {
            return Ok(());
        }
        if !self.test_connection().await? {
            let url = self.bucket_path.create_bucket(&self.creds).sign(SIGN_TTL);
            let resp = self
                .send_once(reqwest::Method::PUT, url, &[], None)
                .await
                .map_err(|e| anyhow::anyhow!("{e}"))?;
            // 409 = BucketAlreadyOwnedByYou：并发创建撞上了，等价于成功。
            if !resp.status().is_success() && resp.status().as_u16() != 409 {
                return Err(Self::fail("Create bucket", resp).await);
            }
        }
        self.bucket_ensured.store(true, Ordering::Relaxed);
        Ok(())
    }

    /// 不存在（404）返回 `None`；其它错误如实上抛 —— 调用方（同步引擎）
    /// 必须能区分「不存在」与「读取失败」，否则 push 会在网络抖动时把 manifest 从零重建。
    ///
    /// **返回 `Option` 而不是空 Vec**：理由同 webdav 侧 —— 空 Vec 会让「不存在」与
    /// 「存在但 0 字节」在 Dart 那层不可区分，0 字节 manifest 即触发远端墓碑全丢。
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
        moodiary_http::client::read_body(resp)
            .await
            .map(Some)
            .map_err(|e| anyhow::anyhow!("Failed to read object content: {e}"))
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

    /// [read_object] 的落盘版：响应体边收边写，整份不进内存。媒体对象走这条。
    /// 远端不存在（404）返回 false 且不建文件。
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
        moodiary_http::client::write_body_to_file(resp, &file_path).await?;
        Ok(true)
    }

    /// [write_object] 的文件版：请求体边读边发，整份不进内存。
    pub async fn write_object_file(&self, key: String, file_path: String) -> Result<()> {
        self.ensure_bucket().await?;
        let (body, len) = moodiary_http::client::file_body(&file_path).await?;
        let len = len.to_string();
        let resp = self
            .send(
                reqwest::Method::PUT,
                |b| b.put_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[("content-length", len.as_str())],
                Some(body),
            )
            .await?;
        // 流式 body 不能 clone，重定向中间件会把 3xx 原样交回；而预签名 URL 换了 host
        // 签名即失效（跨区 307 要求按新区重签），盲目重发只会 403 —— 直说是配置问题。
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

    /// 条件创建：仅当远端不存在时写入（`If-None-Match: *`）。返回 true=创建成功，
    /// false=远端已存在（412）。不支持条件 PUT 的实现会忽略该头、直接覆盖并返回 true ——
    /// 调用方（Dart 租约层）必须用「写后回读校验」兜底。
    pub async fn create_exclusive(&self, key: String, data: Vec<u8>) -> Result<bool> {
        self.ensure_bucket().await?;
        let resp = self
            .send(
                reqwest::Method::PUT,
                |b| {
                    let mut action = b.put_object(Some(&self.creds), &key);
                    // 进 SignedHeaders，所以请求里必须原样再带一次，否则签名对不上。
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

    /// 「不存在」视为成功；其它错误如实上抛 —— 引擎依赖删除结果决定 tombstone 是否已被远端接收。
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

    /// HEAD 请求取 Last-Modified：404（不存在）返回空字符串；网络与其它 HTTP 错误上抛。
    /// 调用方只判空/非空，不解析格式。
    pub async fn stat_object(&self, key: String) -> Result<String> {
        let resp = self
            .send(
                reqwest::Method::HEAD,
                |b| b.head_object(Some(&self.creds), &key).sign(SIGN_TTL),
                &[],
                None,
            )
            .await
            .map_err(|e| anyhow::anyhow!("Stat request failed: {e}"))?;
        // 同 webdav：只有 404 是「不存在」，其余错误上抛。
        if resp.status() == reqwest::StatusCode::NOT_FOUND {
            return Ok(String::new());
        }
        if !resp.status().is_success() {
            anyhow::bail!("Stat failed: HTTP {}", resp.status());
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
        // 带点 + HTTPS：通配证书只匹配一级标签。
        assert_eq!(style(aws, "my.diary", true), "path");
        // 同样带点但走 HTTP，没有证书问题。
        assert_eq!(style(aws, "my.diary", false), "virtual");
        // 非法 DNS 标签。用例取自 aws-sdk-s3 的 is_virtual_hostable_s3_bucket 测试。
        for bad in [
            "MyDiary",  // 大写
            "abC",      // 大写
            "my_diary", // 下划线
            "abc def",  // 空格
            "ab",       // 过短
            "-diary",   // 首字符非字母数字
            "diary-",   // 尾字符非字母数字
            ".diary",
            "diary.",
            "bucket.-name", // `.-` 相邻
            "bucket-.name", // `-.` 相邻
            "192.168.1.1",  // IPv4 形状
            "0.0.0.0",
        ] {
            assert_eq!(style(aws, bad, false), "path", "{bad}");
        }
        // 合法：双连字符、IPv4 形似但含字母、超过 4 段。
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
        // R2 要求填 auto —— 这就是不能从 endpoint 推断 region 的原因。
        assert_eq!(resolve_region(Some("auto".into())), "auto");
        // 空 / 纯空白 / 未填 → MinIO 的默认区域。
        assert_eq!(resolve_region(None), "us-east-1");
        assert_eq!(resolve_region(Some("".into())), "us-east-1");
        assert_eq!(resolve_region(Some("  ".into())), "us-east-1");
        assert_eq!(resolve_region(Some(" eu-west-1 ".into())), "eu-west-1");
    }

    /// 反代后面的自建（endpoint 带路径前缀）会因为 IP/localhost 之外的原因走 vhost，
    /// 这里用 localhost 触发路径式，验证前缀不会被 Url::join 吃掉。
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
