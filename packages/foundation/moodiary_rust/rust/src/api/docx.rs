use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::api::cancel::CancelToken;
use crate::api::export_ir::IrDoc;

pub use moodiary_export::docx::DocxStyle;

#[frb(mirror(DocxStyle))]
pub struct _DocxStyle {
    /// 写进 `w:rFonts` 的 `eastAsia`。
    pub east_asia_font: String,
    /// 写进 `ascii` / `hAnsi`。
    pub ascii_font: String,
    pub font_size_pt: f64,
    /// 行距倍数（1.0 = 单倍）。
    pub line_spacing: f64,
    pub first_line_indent: bool,
    /// 单位 twip（1/1440 英寸）。A4 = 11906 × 16838。
    pub page_width: u32,
    pub page_height: u32,
    pub page_margin: u32,
    pub include_title: bool,
    pub include_meta: bool,
    pub page_break_between: bool,
    /// 音视频占位行的类型词，已本地化（这一侧没有 l10n）。
    pub video_label: String,
    pub audio_label: String,
}

pub fn write_docx(
    docs: Vec<IrDoc>,
    style: DocxStyle,
    out_path: String,
    cancel: &CancelToken,
) -> Result<()> {
    moodiary_export::docx::write_docx(docs, &style, out_path, &cancel.checker())
}

/// 合并导出用的累加器，理由同 [PdfBuilder](crate::api::pdf::PdfBuilder)。
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
        moodiary_export::docx::write_docx(
            std::mem::take(&mut self.docs),
            &self.style,
            out_path,
            &cancel.checker(),
        )
    }
}
