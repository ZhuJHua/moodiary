//! 导出中间表示（IR）的 Rust 镜像。
//!
//! 与 Dart 侧 `moodiary_utils` 的 `export_doc.dart` 一一对应，**JSON 形状即 FFI 契约**：
//! 改这里的字段名要同步改那边的 `toJson()`，反之亦然。
//!
//! 放在 `api/` 之外是有意的：这些类型不跨桥（跨桥的只有一个 JSON 字符串），
//! 放进 `api/` 会被 flutter_rust_bridge 扫到并生成一堆没用的绑定，还容易和别的模块重名。
//!
//! 输入的是 IR 而不是 tiptap 文档：tiptap 的 schema 随上游升级会变，IR 是我们自己的契约。

// IR 是与 Dart 侧对齐的**完整**契约。个别字段当前 docx / pdf 两条链都还用不到
// （tags、media.path），但删掉会让契约与 Dart 漂移，将来加功能时又得补回来。
#![allow(dead_code)]

use serde::Deserialize;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IrDoc {
    pub id: String,
    #[serde(default)]
    pub title: String,
    /// 已格式化好的展示用时间串（Dart 侧格式化，Rust 侧只照抄）。
    #[serde(default)]
    pub time: String,
    #[serde(default)]
    pub weather: Vec<String>,
    #[serde(default)]
    pub position: Vec<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub category_name: Option<String>,
    #[serde(default)]
    pub blocks: Vec<IrBlock>,
}

#[derive(Deserialize, Default, Clone)]
#[serde(rename_all = "camelCase")]
pub struct IrSpan {
    #[serde(default)]
    pub text: String,
    #[serde(default)]
    pub bold: bool,
    #[serde(default)]
    pub italic: bool,
    #[serde(default)]
    pub strike: bool,
    #[serde(default)]
    pub underline: bool,
    #[serde(default)]
    pub code: bool,
    #[serde(default)]
    pub href: Option<String>,
    /// 双链目标日记 id；非空时 [text] 是链接标签。
    #[serde(default)]
    pub diary_link_id: Option<String>,
}

#[derive(Deserialize)]
pub struct IrListItem {
    #[serde(default)]
    pub children: Vec<IrBlock>,
    /// 非空表示这是任务项。
    #[serde(default)]
    pub checked: Option<bool>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IrCell {
    #[serde(default)]
    pub children: Vec<IrBlock>,
    #[serde(default = "one")]
    pub colspan: usize,
    #[serde(default = "one")]
    pub rowspan: usize,
    #[serde(default)]
    pub align: Option<String>,
    #[serde(default)]
    pub header: bool,
}

fn one() -> usize {
    1
}

#[derive(Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum IrBlock {
    Paragraph {
        #[serde(default)]
        spans: Vec<IrSpan>,
    },
    Heading {
        level: usize,
        #[serde(default)]
        spans: Vec<IrSpan>,
    },
    List {
        #[serde(default)]
        ordered: bool,
        #[serde(default = "one")]
        start: usize,
        #[serde(default)]
        items: Vec<IrListItem>,
    },
    Quote {
        #[serde(default)]
        children: Vec<IrBlock>,
    },
    Code {
        #[serde(default)]
        language: Option<String>,
        #[serde(default)]
        text: String,
    },
    Divider,
    Image {
        path: String,
        #[serde(default)]
        alt: Option<String>,
        /// 正文列宽百分比上限（25/50/75/100）。
        #[serde(default)]
        width_percent: Option<u32>,
        /// 粘贴进来的外链图，导出时不下载、只当链接处理。
        #[serde(default)]
        external: bool,
    },
    Media {
        kind: String,
        filename: String,
        #[serde(default)]
        path: String,
        #[serde(default)]
        cover_path: Option<String>,
    },
    Table {
        #[serde(default)]
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
