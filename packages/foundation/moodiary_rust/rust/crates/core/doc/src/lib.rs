//! 导出中间表示。三条导出链（Dart 的 Markdown、Rust 的 PDF / DOCX）共用这一份文档模型。
//! 用 IR 而不是 tiptap 文档，是因为 tiptap 的 schema 随上游升级会变。

// 个别字段当前 docx / pdf 两条链都还用不到（tags、media.path），但删掉会让契约与 Dart
// 漂移，将来加功能时又得补回来。
#![allow(dead_code)]

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
    pub href: Option<String>,
    /// 双链目标日记 id；非空时 [text] 是链接标签。
    pub diary_link_id: Option<String>,
}

pub struct IrListItem {
    pub children: Vec<IrBlock>,
    /// 非空表示这是任务项。
    pub checked: Option<bool>,
}

pub struct IrCell {
    pub children: Vec<IrBlock>,
    pub colspan: u32,
    pub rowspan: u32,
    pub align: Option<String>,
    pub header: bool,
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
    Divider,
    Image {
        path: String,
        alt: Option<String>,
        /// 正文列宽百分比上限（25/50/75/100）。
        width_percent: Option<u32>,
        /// 粘贴进来的外链图，导出时不下载、只当链接处理。
        external: bool,
    },
    Media {
        kind: String,
        filename: String,
        path: String,
        cover_path: Option<String>,
    },
    Table {
        rows: Vec<Vec<IrCell>>,
    },
}

impl IrDoc {
    /// 「日期 · 天气 · 位置 · 分类」摘要行。
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
