pub mod s3;
pub mod webdav;

pub(crate) fn kind_of_status(status: u16) -> &'static str {
    match status {
        401 | 403 => "auth",
        404 => "not_found",
        500..=599 => "server",
        _ => "http",
    }
}

pub(crate) fn kind_of_reqwest(e: &reqwest::Error) -> &'static str {
    if let Some(status) = e.status() {
        return kind_of_status(status.as_u16());
    }
    if e.is_connect() || e.is_timeout() || e.is_request() {
        return "network";
    }
    "unknown"
}

pub(crate) fn tagged(kind: &str, msg: impl std::fmt::Display) -> anyhow::Error {
    anyhow::anyhow!("[{kind}] {msg}")
}

pub(crate) fn req_err(e: reqwest::Error, msg: impl std::fmt::Display) -> anyhow::Error {
    tagged(kind_of_reqwest(&e), format!("{msg}: {e}"))
}

fn next_open_tag(xml: &str) -> Option<(&str, bool, &str)> {
    let mut rest = xml;
    loop {
        rest = &rest[rest.find('<')? + 1..];
        let gt = rest.find('>')?;
        let tag = &rest[..gt];
        rest = &rest[gt + 1..];
        if tag.starts_with(['/', '?', '!']) {
            continue;
        }
        let name = tag
            .trim_end_matches('/')
            .split(char::is_whitespace)
            .next()
            .unwrap_or_default();
        return Some((name, tag.ends_with('/'), rest));
    }
}

pub(crate) fn xml_elements<'a>(xml: &'a str, local: &str) -> Vec<&'a str> {
    let mut out = Vec::new();
    let mut rest = xml;
    while let Some((name, self_closing, after)) = next_open_tag(rest) {
        rest = after;
        if self_closing || name.rsplit(':').next() != Some(local) {
            continue;
        }
        let close = format!("</{name}>");
        let Some(end) = rest.find(&close) else { break };
        out.push(&rest[..end]);
        rest = &rest[end + close.len()..];
    }
    out
}

pub(crate) fn xml_has_element(xml: &str, local: &str) -> bool {
    let mut rest = xml;
    while let Some((name, _, after)) = next_open_tag(rest) {
        if name.rsplit(':').next() == Some(local) {
            return true;
        }
        rest = after;
    }
    false
}

pub(crate) fn xml_text(raw: &str) -> String {
    let raw = raw.trim();
    let raw = raw
        .strip_prefix("<![CDATA[")
        .and_then(|s| s.strip_suffix("]]>"))
        .unwrap_or(raw);
    let mut out = String::with_capacity(raw.len());
    let mut rest = raw;
    while let Some(amp) = rest.find('&') {
        out.push_str(&rest[..amp]);
        rest = &rest[amp..];
        let decoded = rest.find(';').and_then(|semi| {
            let ch = match &rest[1..semi] {
                "amp" => '&',
                "lt" => '<',
                "gt" => '>',
                "quot" => '"',
                "apos" => '\'',
                n => {
                    let code = match n.strip_prefix("#x").or_else(|| n.strip_prefix("#X")) {
                        Some(hex) => u32::from_str_radix(hex, 16).ok(),
                        None => n.strip_prefix('#').and_then(|d| d.parse().ok()),
                    };
                    char::from_u32(code?)?
                }
            };
            Some((ch, semi))
        });
        match decoded {
            Some((ch, semi)) => {
                out.push(ch);
                rest = &rest[semi + 1..];
            }
            None => {
                out.push('&');
                rest = &rest[1..];
            }
        }
    }
    out.push_str(rest);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xml_helpers_ignore_namespace_prefixes() {
        let xml = "<?xml version=\"1.0\"?><d:a><d:b x=\"1\">1</d:b><b>2</b><c/></d:a>";
        assert_eq!(xml_elements(xml, "b"), vec!["1", "2"]);
        assert!(xml_has_element(xml, "c"));
        assert!(!xml_has_element(xml, "z"));
    }

    #[test]
    fn xml_text_unescapes_entities() {
        assert_eq!(xml_text(" a&amp;b&#x41;&#66;&lt; "), "a&bAB<");
        assert_eq!(xml_text("<![CDATA[a&b]]>"), "a&b");
        assert_eq!(xml_text("a & b"), "a & b");
    }
}
