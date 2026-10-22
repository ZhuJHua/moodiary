use flutter_rust_bridge::frb;

pub use crate::ir::{IrBlock, IrCell, IrDividerVariant, IrDoc, IrListItem, IrRow, IrSpan};

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
    pub highlight: bool,
    pub href: Option<String>,
    pub diary_link_id: Option<String>,
}

#[frb(mirror(IrListItem))]
pub struct _IrListItem {
    pub children: Vec<IrBlock>,
    pub checked: Option<bool>,
}

#[frb(mirror(IrRow))]
pub struct _IrRow {
    pub cells: Vec<IrCell>,
}

#[frb(mirror(IrCell))]
pub struct _IrCell {
    pub children: Vec<IrBlock>,
    pub colspan: u32,
    pub rowspan: u32,
    pub align: Option<String>,
    pub header: bool,
}

#[frb(mirror(IrDividerVariant))]
pub enum _IrDividerVariant {
    Solid,
    Dashed,
    Dotted,
    Double,
    Wavy,
    Text,
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
