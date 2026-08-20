use anyhow::Result;
use flutter_rust_bridge::frb;

use crate::api::cancel::CancelToken;
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

pub fn write_pdf(
    docs: Vec<IrDoc>,
    style: PdfStyle,
    out_path: String,
    cancel: &CancelToken,
) -> Result<()> {
    moodiary_export::pdf::write_pdf(docs, &style, out_path, &cancel.checker())
}

/// 合并导出用的累加器。直接把整库交给 [write_pdf] 结果一样，但那样整个语料会同时以
/// 三份存在（Dart 对象、过桥缓冲、Rust 的 Vec）；逐篇推则缓冲里只有一篇。
#[frb(opaque)]
pub struct PdfBuilder {
    docs: Vec<IrDoc>,
    style: PdfStyle,
}

impl PdfBuilder {
    pub fn new(style: PdfStyle) -> PdfBuilder {
        PdfBuilder {
            docs: Vec::new(),
            style,
        }
    }

    pub fn add(&mut self, doc: IrDoc) {
        self.docs.push(doc);
    }

    pub fn finish(&mut self, out_path: String, cancel: &CancelToken) -> Result<()> {
        moodiary_export::pdf::write_pdf(
            std::mem::take(&mut self.docs),
            &self.style,
            out_path,
            &cancel.checker(),
        )
    }
}
