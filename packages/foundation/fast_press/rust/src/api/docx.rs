use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::api::cancel::CancelToken;
use crate::api::ir::IrDoc;

pub use crate::docx::DocxStyle;

#[frb(mirror(DocxStyle))]
pub struct _DocxStyle {
    pub east_asia_font: String,
    pub ascii_font: String,
    pub font_size_pt: f64,
    pub line_spacing: f64,
    pub first_line_indent: bool,
    pub page_width: u32,
    pub page_height: u32,
    pub page_margin: u32,
    pub include_title: bool,
    pub include_meta: bool,
    pub page_break_between: bool,
    pub video_label: String,
    pub audio_label: String,
}

pub fn write_docx(
    docs: Vec<IrDoc>,
    style: DocxStyle,
    out_path: String,
    cancel: &CancelToken,
) -> Result<()> {
    crate::docx::write_docx(docs, &style, out_path, &cancel.checker())
}

#[frb(opaque)]
pub struct DocxBuilder {
    docs: Vec<IrDoc>,
    style: DocxStyle,
}

impl DocxBuilder {
    pub fn new(style: DocxStyle) -> DocxBuilder {
        DocxBuilder {
            docs: Vec::new(),
            style,
        }
    }

    pub fn add(&mut self, doc: IrDoc) {
        self.docs.push(doc);
    }

    pub fn finish(&mut self, out_path: String, cancel: &CancelToken) -> Result<()> {
        crate::docx::write_docx(
            std::mem::take(&mut self.docs),
            &self.style,
            out_path,
            &cancel.checker(),
        )
    }
}
