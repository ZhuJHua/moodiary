pub struct IrDoc {
    pub id: String,
    pub title: String,
    pub time: String,
    pub weather: Vec<String>,
    pub position: Vec<String>,
    pub tags: Vec<String>,
    pub category_name: Option<String>,
    pub blocks: Vec<IrBlock>,
}

#[derive(Default, Clone)]
pub struct IrSpan {
    pub text: String,
    pub bold: bool,
    pub italic: bool,
    pub strike: bool,
    pub underline: bool,
    pub code: bool,
    pub highlight: bool,
    pub href: Option<String>,
    pub diary_link_id: Option<String>,
}

pub struct IrListItem {
    pub children: Vec<IrBlock>,
    pub checked: Option<bool>,
}

pub struct IrRow {
    pub cells: Vec<IrCell>,
}

pub struct IrCell {
    pub children: Vec<IrBlock>,
    pub colspan: u32,
    pub rowspan: u32,
    pub align: Option<String>,
    pub header: bool,
}

#[derive(Clone, Copy, Debug)]
pub enum IrDividerVariant {
    Solid,
    Dashed,
    Dotted,
    Double,
    Wavy,
    Text,
}

pub enum IrBlock {
    Paragraph {
        spans: Vec<IrSpan>,
    },
    Heading {
        level: u32,
        spans: Vec<IrSpan>,
    },
    List {
        ordered: bool,
        start: u32,
        items: Vec<IrListItem>,
    },
    Quote {
        children: Vec<IrBlock>,
    },
    Code {
        language: Option<String>,
        text: String,
    },
    Divider {
        variant: IrDividerVariant,
        label: Option<String>,
    },
    Image {
        path: String,
        alt: Option<String>,
        width_percent: Option<u32>,
        is_external: bool,
    },
    Media {
        kind: String,
        name: Option<String>,
        filename: String,
        path: String,
        cover_path: Option<String>,
        width_percent: Option<u32>,
    },
    Attachment {
        name: String,
        filename: String,
        path: String,
        mime: Option<String>,
        size: Option<i64>,
    },
    Table {
        rows: Vec<IrRow>,
    },
}

impl IrDoc {
    pub fn meta_line(&self) -> String {
        let mut parts: Vec<&str> = Vec::new();
        if !self.time.is_empty() {
            parts.push(&self.time);
        }
        let weather = self.weather.join(" ");
        if !weather.is_empty() {
            parts.push(&weather);
        }
        if let Some(last) = self.position.last() {
            parts.push(last);
        }
        if let Some(category) = self.category_name.as_deref() {
            parts.push(category);
        }
        parts.join(" · ")
    }
}

pub fn divider_label(variant: IrDividerVariant, label: Option<&str>) -> Option<&str> {
    match variant {
        IrDividerVariant::Text => label.map(str::trim).filter(|l| !l.is_empty()),
        _ => None,
    }
}

fn human_size(bytes: i64) -> String {
    const UNITS: [&str; 4] = ["KB", "MB", "GB", "TB"];
    if bytes < 1024 {
        return format!("{} B", bytes.max(0));
    }
    let mut value = bytes as f64 / 1024.0;
    let mut unit = 0;
    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if value < 10.0 {
        format!("{value:.1} {}", UNITS[unit])
    } else {
        format!("{value:.0} {}", UNITS[unit])
    }
}

pub fn attachment_line(label: &str, name: &str, size: Option<i64>) -> String {
    match size {
        Some(size) => format!("[{label}] {name} · {}", human_size(size)),
        None => format!("[{label}] {name}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn human_size_picks_unit_and_precision() {
        assert_eq!(human_size(0), "0 B");
        assert_eq!(human_size(1023), "1023 B");
        assert_eq!(human_size(1024), "1.0 KB");
        assert_eq!(human_size(1536), "1.5 KB");
        assert_eq!(human_size(10 * 1024), "10 KB");
        assert_eq!(human_size(5 * 1024 * 1024 + 300 * 1024), "5.3 MB");
        assert_eq!(human_size(3 * 1024 * 1024 * 1024), "3.0 GB");
        assert_eq!(human_size(-5), "0 B");
    }

    #[test]
    fn only_text_dividers_keep_a_label() {
        assert_eq!(
            divider_label(IrDividerVariant::Text, Some(" 第二天 ")),
            Some("第二天")
        );
        assert_eq!(divider_label(IrDividerVariant::Text, Some("  ")), None);
        assert_eq!(divider_label(IrDividerVariant::Wavy, Some("x")), None);
    }

    #[test]
    fn attachment_line_omits_unknown_size() {
        assert_eq!(
            attachment_line("附件", "a.pdf", Some(2048)),
            "[附件] a.pdf · 2.0 KB"
        );
        assert_eq!(attachment_line("附件", "a.pdf", None), "[附件] a.pdf");
    }
}
