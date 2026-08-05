use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::api::export_ir::IrDoc;

pub use moodiary_export::pdf::PdfStyle;

#[frb(mirror(PdfStyle))]
pub struct _PdfStyle {
    pub font_path: String,
    /// 留空则用字体文件自报的家族名。
    pub font_family: String,
    pub font_size_pt: f64,
    pub line_spacing_em: f64,
    pub first_line_indent: bool,
    pub page_width_mm: f64,
    pub page_height_mm: f64,
    pub page_margin_mm: f64,
    pub include_title: bool,
    pub include_meta: bool,
    /// 音视频占位行的类型词，已本地化（这一侧没有 l10n）。
    pub video_label: String,
    pub audio_label: String,
}

pub fn write_pdf(docs: Vec<IrDoc>, style: PdfStyle, out_path: String) -> Result<()> {
    moodiary_export::pdf::write_pdf(docs, style, out_path)
}
