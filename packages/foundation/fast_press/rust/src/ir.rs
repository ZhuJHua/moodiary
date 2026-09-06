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
        width_percent: Option<u32>,
        is_external: bool,
    },
    Media {
        kind: String,
        filename: String,
        path: String,
        cover_path: Option<String>,
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
