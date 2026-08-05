//! 导出 IR 的跨桥声明。类型本体在 [`moodiary_doc`]，这里只让 FRB 生成 Dart 侧的对应类。

use flutter_rust_bridge::frb;

pub use moodiary_doc::{IrBlock, IrCell, IrDoc, IrListItem, IrSpan};

#[frb(mirror(IrDoc))]
pub struct _IrDoc {
    pub id: String,
    pub title: String,
    pub time: String,
    pub weather: Vec<String>,
    pub position: Vec<String>,
    pub tags: Vec<String>,
    pub category_name: Option<String>,
    pub blocks: Vec<IrBlock>,
}

#[frb(mirror(IrSpan))]
pub struct _IrSpan {
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

#[frb(mirror(IrListItem))]
pub struct _IrListItem {
    pub children: Vec<IrBlock>,
    /// 非空表示这是任务项。
    pub checked: Option<bool>,
}

#[frb(mirror(IrCell))]
pub struct _IrCell {
    pub children: Vec<IrBlock>,
    pub colspan: u32,
    pub rowspan: u32,
    pub align: Option<String>,
    pub header: bool,
}

#[frb(mirror(IrBlock))]
pub enum _IrBlock {
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
