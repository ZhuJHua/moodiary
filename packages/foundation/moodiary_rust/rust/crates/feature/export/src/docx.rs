//! 日记导出 DOCX。
//!
//! 输入是 Dart 侧 `ExportDoc` 的 JSON（见 moodiary_utils 的 export_doc.dart）——不是 tiptap
//! 文档。IR 的 Rust 镜像在 [`moodiary_doc`]，与 PDF 那条链共用一份定义。
//!
//! DOCX 对中文是白送的：OOXML 只写字体名不嵌字体，正文由 Word / WPS 用本机字体渲染。
//! 这也是它相对 PDF 的关键优势 —— 导出侧一个字节的字体都不用管。
//!
//! 两个 docx-rs 的坑，改这个文件时别踩回去：
//! 1. [`Pic::new`] 内部连着四个 `expect()` —— 一张坏图就让整次导出以 panic 收场
//!    （FRB 会兜成 Dart 异常，但这一趟导出的成果全没了）。**只用
//!    [`Pic::new_with_dimensions`]**，尺寸自己用 image crate 读，每张图失败就跳过。
//! 2. zipper 把媒体一律写成 `word/media/{id}.png`（`src/zipper/mod.rs:111`，上游 main 至今
//!    未改）。我们喂的是 JPEG 字节，故部件名与实际格式不符。`[Content_Types].xml` 里 png 与
//!    jpeg 都声明了 Default，Word / WPS 按内容嗅探能正常渲染，但这不是合规写法；若哪天遇到
//!    某个阅读器不认，解法是 fork 那一行按字节嗅探决定扩展名。

use anyhow::{Context, Result};
use docx_rs::*;
use std::collections::HashSet;
use std::fs::File;
use std::path::Path;

use moodiary_doc::{IrBlock, IrDoc, IrListItem, IrRow, IrSpan};

pub struct DocxStyle {
    /// 中文字体名（写进 `w:rFonts` 的 `eastAsia`）。
    pub east_asia_font: String,
    /// 西文字体名（`ascii` / `hAnsi`）。
    pub ascii_font: String,
    pub font_size_pt: f64,
    /// 行距倍数（1.0 = 单倍）。
    pub line_spacing: f64,
    pub first_line_indent: bool,
    /// 页面宽高（twip，1/1440 英寸）。A4 = 11906 × 16838。
    pub page_width: u32,
    pub page_height: u32,
    pub page_margin: u32,
    pub include_title: bool,
    /// 标题下写一行「日期 · 天气 · 位置 · 分类」摘要。
    pub include_meta: bool,
    pub page_break_between: bool,
    /// 音视频占位行的类型词（已本地化，由 Dart 传入 —— 这一侧没有 l10n）。
    pub video_label: String,
    pub audio_label: String,
}

const NUM_BULLET: usize = 1;
const NUM_ORDERED: usize = 2;
/// 每级缩进（twip）。420 ≈ 两个中文字符宽。
const INDENT_STEP: i32 = 420;
const MAX_LEVEL: usize = 5;
/// 正文可用宽度 = 页宽 - 两侧边距，换算成 EMU（1 twip = 635 EMU）。
const EMU_PER_TWIP: u32 = 635;

const CODE_BG: &str = "F2F3F5";

/// 代码块里的一段同色文字。
struct CodePiece {
    text: String,
    /// RRGGBB，docx 的 `w:color` 不带 #。
    color: String,
    bold: bool,
    italic: bool,
}

/// 语法集取 typst 用的同一套（two-face），主题也取 typst 的 `RAW_THEME`——
/// 这样同一篇日记导成 DOCX 和 PDF，代码块配色逐字节一致。
static SYNTAXES: std::sync::LazyLock<syntect::parsing::SyntaxSet> =
    std::sync::LazyLock::new(two_face::syntax::extra_no_newlines);

/// 把代码按行、按 token 切开并染色。语言为空或不认识时退回纯文本（仍然是黑字等宽）。
fn highlight(language: Option<&str>, text: &str) -> Vec<Vec<CodePiece>> {
    let syntax = language
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .and_then(|l| SYNTAXES.find_syntax_by_token(&l.to_ascii_lowercase()))
        .unwrap_or_else(|| SYNTAXES.find_syntax_plain_text());

    let mut highlighter = syntect::easy::HighlightLines::new(syntax, &typst::text::RAW_THEME);
    text.split('\n')
        .map(|line| match highlighter.highlight_line(line, &SYNTAXES) {
            Ok(ranges) => ranges
                .into_iter()
                .map(|(style, piece)| {
                    let fg = style.foreground;
                    let weight = style.font_style;
                    CodePiece {
                        text: piece.to_string(),
                        color: format!("{:02X}{:02X}{:02X}", fg.r, fg.g, fg.b),
                        bold: weight.contains(syntect::highlighting::FontStyle::BOLD),
                        italic: weight.contains(syntect::highlighting::FontStyle::ITALIC),
                    }
                })
                .collect(),
            // 高亮失败不该让整篇导出失败，退回无色一行。
            Err(_) => vec![CodePiece {
                text: line.to_string(),
                color: "000000".to_string(),
                bold: false,
                italic: false,
            }],
        })
        .collect()
}
const QUOTE_COLOR: &str = "6B7686";
const LINK_COLOR: &str = "2B5CB8";
const META_COLOR: &str = "8A93A0";

/// 把一批日记写成一个 .docx 文件。
///
/// [docs_json] 是 `ExportDoc.toJson()` 的**数组**。每篇一文件的场景由 Dart 侧循环调用、
/// 每次传单元素数组实现 —— 合并与拆分共用同一条码路。
///
/// 直接落盘而不回传字节：与 `Zip::new(file_path)`、`ImageCompressor::optimize_to_file`
/// 的既有约定一致，且带图日记几十 MB 时不必在内存里整份成型。
pub fn write_docx(
    docs: Vec<IrDoc>,
    style: &DocxStyle,
    out_path: String,
    cancelled: &dyn Fn() -> bool,
) -> Result<()> {
    // 同一批里的双链改成文档内跳转；不在这批里的目标只能降级成普通文字。
    let ids: HashSet<&str> = docs.iter().map(|d| d.id.as_str()).collect();

    let mut docx = base_docx(style);
    let content_width_emu = content_width_emu(style);
    let mut bookmark_id = 0usize;

    for (i, doc) in docs.iter().enumerate() {
        if cancelled() {
            anyhow::bail!("cancelled");
        }
        if i > 0 && style.page_break_between {
            docx =
                docx.add_paragraph(Paragraph::new().add_run(Run::new().add_break(BreakType::Page)));
        }

        if style.include_title && !doc.title.is_empty() {
            let anchor = anchor_of(&doc.id);
            docx = docx
                .add_bookmark_start(bookmark_id, anchor)
                .add_paragraph(
                    Paragraph::new()
                        .style("Heading1")
                        .add_run(fonts(Run::new(), style).bold().add_text(&doc.title)),
                )
                .add_bookmark_end(bookmark_id);
            bookmark_id += 1;
        }

        if style.include_meta {
            let meta = doc.meta_line();
            if !meta.is_empty() {
                docx = docx.add_paragraph(
                    Paragraph::new().add_run(
                        fonts(Run::new(), style)
                            .size(half_pt(style.font_size_pt * 0.85))
                            .color(META_COLOR)
                            .add_text(meta),
                    ),
                );
            }
        }

        let ctx = Ctx {
            style,
            ids: &ids,
            content_width_emu,
        };
        docx = blocks(docx, &doc.blocks, &ctx, 0);
    }

    let file =
        File::create(&out_path).with_context(|| format!("创建 docx 文件失败：{out_path}"))?;
    docx.build().pack(file).context("写入 docx 失败")?;
    Ok(())
}

struct Ctx<'a> {
    style: &'a DocxStyle,
    ids: &'a HashSet<&'a str>,
    content_width_emu: u32,
}

fn base_docx(style: &DocxStyle) -> Docx {
    let body = half_pt(style.font_size_pt);

    let mut docx = Docx::new()
        .page_size(style.page_width, style.page_height)
        .page_margin(PageMargin {
            top: style.page_margin as i32,
            left: style.page_margin as i32,
            bottom: style.page_margin as i32,
            right: style.page_margin as i32,
            header: 720,
            footer: 720,
            gutter: 0,
        })
        .default_size(body)
        .default_fonts(run_fonts(style))
        .default_line_spacing(
            LineSpacing::new()
                .line_rule(LineSpacingType::Auto)
                // w:line 单位是 1/240 行。
                .line((style.line_spacing * 240.0).round() as i32),
        );

    // 自己定义标题样式：docx-rs 的空文档不带 Heading1..6，不定义的话 Word 的导航窗格与
    // 目录域都认不出标题。
    for level in 1..=6usize {
        let scale = [1.8_f64, 1.5, 1.3, 1.15, 1.05, 1.0][level - 1];
        docx = docx.add_style(
            Style::new(format!("Heading{level}"), StyleType::Paragraph)
                .name(format!("heading {level}"))
                .bold()
                .size(half_pt(style.font_size_pt * scale))
                .fonts(run_fonts(style))
                // outline_lvl 才是 Word 导航窗格与目录域识别标题的依据，光有样式名不够。
                .outline_lvl(level - 1)
                .q_format(true)
                .line_spacing(LineSpacing::new().before(240).after(120)),
        );
    }

    docx.add_abstract_numbering(numbering_def(NUM_BULLET, false))
        .add_numbering(Numbering::new(NUM_BULLET, NUM_BULLET))
        .add_abstract_numbering(numbering_def(NUM_ORDERED, true))
        .add_numbering(Numbering::new(NUM_ORDERED, NUM_ORDERED))
}

fn numbering_def(id: usize, ordered: bool) -> AbstractNumbering {
    let mut def = AbstractNumbering::new(id);
    for level in 0..=MAX_LEVEL {
        let (format, text) = if ordered {
            (
                NumberFormat::new("decimal"),
                LevelText::new(format!("%{}.", level + 1)),
            )
        } else {
            // 三种符号轮换，嵌套层级一眼可辨。
            let bullet = ["•", "◦", "▪"][level % 3];
            (NumberFormat::new("bullet"), LevelText::new(bullet))
        };
        let left = INDENT_STEP * (level as i32 + 1);
        def = def.add_level(
            Level::new(level, Start::new(1), format, text, LevelJc::new("left")).indent(
                Some(left),
                Some(SpecialIndentType::Hanging(INDENT_STEP)),
                None,
                None,
            ),
        );
    }
    def
}

fn run_fonts(style: &DocxStyle) -> RunFonts {
    RunFonts::new()
        .ascii(&style.ascii_font)
        .hi_ansi(&style.ascii_font)
        .east_asia(&style.east_asia_font)
        .cs(&style.ascii_font)
}

fn fonts(run: Run, style: &DocxStyle) -> Run {
    run.fonts(run_fonts(style))
}

/// 磅 → 半磅（OOXML 的字号单位）。
fn half_pt(pt: f64) -> usize {
    (pt * 2.0).round().max(2.0) as usize
}

fn content_width_emu(style: &DocxStyle) -> u32 {
    style
        .page_width
        .saturating_sub(style.page_margin.saturating_mul(2))
        .saturating_mul(EMU_PER_TWIP)
}

/// 书签名不能有连字符、不能以数字开头，长度也有限制。
fn anchor_of(id: &str) -> String {
    format!("d_{}", id.replace('-', ""))
}

fn blocks(mut docx: Docx, blocks: &[IrBlock], ctx: &Ctx, depth: usize) -> Docx {
    for block in blocks {
        docx = self::block(docx, block, ctx, depth);
    }
    docx
}

fn block(docx: Docx, block: &IrBlock, ctx: &Ctx, depth: usize) -> Docx {
    match block {
        IrBlock::Paragraph { spans } => {
            let mut para = indented(Paragraph::new(), depth);
            if ctx.style.first_line_indent && depth == 0 {
                para = para.indent(
                    None,
                    Some(SpecialIndentType::FirstLine(INDENT_STEP)),
                    None,
                    None,
                );
            }
            docx.add_paragraph(inline(para, spans, ctx))
        }

        IrBlock::Heading { level, spans } => {
            let level = (*level).clamp(1, 6);
            let para = indented(Paragraph::new(), depth).style(&format!("Heading{level}"));
            docx.add_paragraph(inline(para, spans, ctx))
        }

        IrBlock::Quote { children } => {
            // docx-rs 的 Paragraph 没有直出的底纹 / 边框构造器，引用块用「缩进 + 灰字」表达，
            // 视觉上够用且不必去改 pub 字段。
            let mut docx = docx;
            for child in children {
                docx = quoted(docx, child, ctx, depth + 1);
            }
            docx
        }

        // docx 的 numbering 是文档级定义，起始序号要为每个列表单独建一份，
        // 暂不支持 IR 里的 start（与接 IR 之前的行为一致）。
        IrBlock::List { ordered, items, .. } => list(docx, *ordered, items, ctx, depth),

        IrBlock::Code { language, text } => {
            let mut docx = docx;
            // 代码块逐行成段：整块塞一个 run 里 Word 不会按换行断行。
            // 一行内再按高亮切成多个 run，每个 run 自带颜色。
            for line in highlight(language.as_deref(), text) {
                let mut para = indented(Paragraph::new(), depth + 1);
                for piece in line {
                    let mut run = Run::new()
                        .fonts(RunFonts::new().ascii("Consolas").east_asia("Consolas"))
                        .size(half_pt(ctx.style.font_size_pt * 0.9))
                        .highlight(CODE_BG)
                        .add_text(piece.text);
                    run = run.color(piece.color);
                    if piece.bold {
                        run = run.bold();
                    }
                    if piece.italic {
                        run = run.italic();
                    }
                    para = para.add_run(run);
                }
                docx = docx.add_paragraph(para);
            }
            docx
        }

        IrBlock::Divider => docx.add_paragraph(
            Paragraph::new().add_run(Run::new().add_text("―".repeat(30)).color(META_COLOR)),
        ),

        IrBlock::Image {
            path,
            width_percent,
            is_external,
            ..
        } => {
            if *is_external {
                // 外链图不下载（导出必须离线可用），退化成链接文字。
                return docx.add_paragraph(link_paragraph(path, path, ctx));
            }
            match image_run(path, *width_percent, ctx) {
                Some(run) => docx.add_paragraph(Paragraph::new().add_run(run)),
                // 文件缺失 / 解码失败：跳过这一张，不让整次导出失败。
                None => docx,
            }
        }

        IrBlock::Media {
            kind,
            filename,
            cover_path,
            ..
        } => {
            let mut docx = docx;
            if let Some(cover) = cover_path.as_deref()
                && let Some(run) = image_run(cover, Some(60), ctx)
            {
                docx = docx.add_paragraph(Paragraph::new().add_run(run));
            }
            let label = if kind == "video" {
                &ctx.style.video_label
            } else {
                &ctx.style.audio_label
            };
            docx.add_paragraph(
                Paragraph::new().add_run(
                    fonts(Run::new(), ctx.style)
                        .size(half_pt(ctx.style.font_size_pt * 0.85))
                        .color(META_COLOR)
                        .add_text(format!("[{label}] {filename}")),
                ),
            )
        }

        IrBlock::Table { rows } => table(docx, rows, ctx),
    }
}

/// 引用块的子块：整体再缩进一级并染灰。
fn quoted(docx: Docx, child: &IrBlock, ctx: &Ctx, depth: usize) -> Docx {
    match child {
        IrBlock::Paragraph { spans } => {
            let para = indented(Paragraph::new(), depth);
            docx.add_paragraph(inline_colored(para, spans, ctx, Some(QUOTE_COLOR)))
        }
        other => block(docx, other, ctx, depth),
    }
}

fn indented(para: Paragraph, depth: usize) -> Paragraph {
    if depth == 0 {
        return para;
    }
    para.indent(Some(INDENT_STEP * depth as i32), None, None, None)
}

fn list(mut docx: Docx, ordered: bool, items: &[IrListItem], ctx: &Ctx, depth: usize) -> Docx {
    let num_id = if ordered { NUM_ORDERED } else { NUM_BULLET };
    let level = depth.min(MAX_LEVEL);

    for item in items {
        let mut first = true;
        for child in &item.children {
            match child {
                IrBlock::Paragraph { spans } if first => {
                    first = false;
                    let mut para = Paragraph::new()
                        .numbering(NumberingId::new(num_id), IndentLevel::new(level));
                    // docx 没有原生复选框，勾选状态用符号表达。
                    if let Some(checked) = item.checked {
                        let mark = if checked { "☑ " } else { "☐ " };
                        para = para.add_run(fonts(Run::new(), ctx.style).add_text(mark));
                    }
                    docx = docx.add_paragraph(inline(para, spans, ctx));
                }
                // 列表项里的后续块（嵌套列表 / 第二段 / 图片）按下一级缩进。
                other => docx = block(docx, other, ctx, depth + 1),
            }
        }
        if first {
            // 空列表项也要占一行，否则编号会错位。
            docx = docx.add_paragraph(
                Paragraph::new().numbering(NumberingId::new(num_id), IndentLevel::new(level)),
            );
        }
    }
    docx
}

fn table(docx: Docx, rows: &[IrRow], ctx: &Ctx) -> Docx {
    if rows.is_empty() {
        return docx;
    }
    let columns = rows.iter().map(|r| r.cells.len()).max().unwrap_or(1).max(1);
    // 表格铺满正文宽度、列宽均分。光给 set_grid 不够 —— 不显式设 width + Fixed 布局，
    // Word 会按内容自动收窄，两列中文表会挤成窄条。
    let total = (ctx.content_width_emu / EMU_PER_TWIP) as usize;
    let column_width = total / columns;
    let grid = vec![column_width; columns];

    let table_rows: Vec<TableRow> = rows
        .iter()
        .map(|row| {
            let cells: Vec<TableCell> = row
                .cells
                .iter()
                .map(|cell| {
                    let mut tc = TableCell::new()
                        .width(column_width * cell.colspan.max(1) as usize, WidthType::Dxa);
                    if cell.colspan > 1 {
                        tc = tc.grid_span(cell.colspan as usize);
                    }
                    if cell.rowspan > 1 {
                        tc = tc.vertical_merge(VMergeType::Restart);
                    }
                    let mut wrote = false;
                    for child in &cell.children {
                        if let IrBlock::Paragraph { spans } = child {
                            wrote = true;
                            // 表头整格加粗：run 建好后改不了，故在 span 层面先强制。
                            let spans: Vec<IrSpan> = if cell.header {
                                spans
                                    .iter()
                                    .map(|s| IrSpan {
                                        bold: true,
                                        ..s.clone()
                                    })
                                    .collect()
                            } else {
                                spans.clone()
                            };
                            tc = tc.add_paragraph(inline(Paragraph::new(), &spans, ctx));
                        }
                    }
                    if !wrote {
                        tc = tc.add_paragraph(Paragraph::new());
                    }
                    tc
                })
                .collect();
            TableRow::new(cells)
        })
        .collect();

    docx.add_table(
        Table::new(table_rows)
            .set_grid(grid)
            .width(total, WidthType::Dxa)
            .layout(TableLayoutType::Fixed)
            .style("TableGrid"),
    )
}

fn inline(para: Paragraph, spans: &[IrSpan], ctx: &Ctx) -> Paragraph {
    inline_colored(para, spans, ctx, None)
}

fn inline_colored(
    mut para: Paragraph,
    spans: &[IrSpan],
    ctx: &Ctx,
    force_color: Option<&str>,
) -> Paragraph {
    for span in spans {
        // 双链：目标在同一批导出里就做文档内跳转，否则只留文字。
        if let Some(target) = span.diary_link_id.as_deref() {
            let run = styled_run(span, ctx, Some(LINK_COLOR));
            if ctx.ids.contains(target) {
                para = para.add_hyperlink(
                    Hyperlink::new(anchor_of(target), HyperlinkType::Anchor).add_run(run),
                );
            } else {
                para = para.add_run(run);
            }
            continue;
        }

        if let Some(href) = span.href.as_deref() {
            para = para.add_hyperlink(
                Hyperlink::new(href, HyperlinkType::External).add_run(styled_run(
                    span,
                    ctx,
                    Some(LINK_COLOR),
                )),
            );
            continue;
        }

        // 段内换行（hardBreak）在 IR 里是 span 文本中的 \n，docx 要显式 break。
        if span.text.contains('\n') {
            let mut lines = span.text.split('\n').peekable();
            while let Some(line) = lines.next() {
                let mut piece = span.clone();
                piece.text = line.to_string();
                let mut run = styled_run(&piece, ctx, force_color);
                if lines.peek().is_some() {
                    run = run.add_break(BreakType::TextWrapping);
                }
                para = para.add_run(run);
            }
            continue;
        }

        para = para.add_run(styled_run(span, ctx, force_color));
    }
    para
}

fn styled_run(span: &IrSpan, ctx: &Ctx, color: Option<&str>) -> Run {
    let mut run = if span.code {
        Run::new()
            .fonts(RunFonts::new().ascii("Consolas").east_asia("Consolas"))
            .highlight(CODE_BG)
    } else {
        fonts(Run::new(), ctx.style)
    };

    run = run
        .size(half_pt(ctx.style.font_size_pt))
        .add_text(&span.text);

    if span.bold {
        run = run.bold();
    }
    if span.italic {
        run = run.italic();
    }
    if span.strike {
        run = run.strike();
    }
    if span.underline || span.href.is_some() || span.diary_link_id.is_some() {
        run = run.underline("single");
    }
    if let Some(c) = color {
        run = run.color(c);
    }
    run
}

fn link_paragraph(text: &str, href: &str, ctx: &Ctx) -> Paragraph {
    Paragraph::new().add_hyperlink(
        Hyperlink::new(href, HyperlinkType::External).add_run(
            fonts(Run::new(), ctx.style)
                .color(LINK_COLOR)
                .underline("single")
                .add_text(text),
        ),
    )
}

/// 读图并按正文宽度换算显示尺寸。任何一步失败都返回 None（跳过这张），
/// 绝不 panic —— 一次 panic 会废掉整次导出。
fn image_run(path: &str, width_percent: Option<u32>, ctx: &Ctx) -> Option<Run> {
    let path = Path::new(path);
    if !path.is_file() {
        return None;
    }
    let bytes = std::fs::read(path).ok()?;

    // 只读文件头拿尺寸，不解码整张图。
    let (px_w, px_h) = image::ImageReader::open(path)
        .ok()?
        .with_guessed_format()
        .ok()?
        .into_dimensions()
        .ok()?;
    if px_w == 0 || px_h == 0 {
        return None;
    }

    // 按正文宽度等比缩放；widthPercent 是编辑器里的列宽上限，没有就按 100% 但不放大。
    let percent = width_percent.unwrap_or(100).clamp(1, 100);
    let target_w = ctx.content_width_emu / 100 * percent;
    let natural_w = px_w * EMU_PER_TWIP * 15; // px → EMU（96 DPI: 1px = 9525 EMU ≈ 635×15）
    let final_w = target_w.min(natural_w).max(1);
    let final_h = ((final_w as u64 * px_h as u64) / px_w as u64) as u32;

    Some(
        Run::new()
            .add_image(Pic::new_with_dimensions(bytes, px_w, px_h).size(final_w, final_h.max(1))),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use moodiary_doc::IrCell;
    use crate::fixture;
    use std::collections::HashMap;
    use std::io::Read;

    fn test_style() -> DocxStyle {
        DocxStyle {
            east_asia_font: "宋体".into(),
            ascii_font: "Georgia".into(),
            font_size_pt: 11.0,
            line_spacing: 1.5,
            first_line_indent: true,
            page_width: 11906,
            page_height: 16838,
            page_margin: 1440,
            include_title: true,
            include_meta: true,
            page_break_between: true,
            video_label: "视频".into(),
            audio_label: "音频".into(),
        }
    }

    /// 每个用例一个独立目录，避免并行跑时互相踩。
    fn tempdir() -> std::path::PathBuf {
        static COUNTER: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
        let n = COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let dir =
            std::env::temp_dir().join(format!("moodiary-docx-test-{}-{n}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write_jpeg(dir: &std::path::Path, name: &str) -> String {
        let img = image::RgbImage::from_fn(160, 120, |x, y| {
            image::Rgb([(x * 255 / 160) as u8, (y * 255 / 120) as u8, 128])
        });
        let path = dir.join(name);
        img.save_with_format(&path, image::ImageFormat::Jpeg)
            .unwrap();
        path.to_string_lossy().into_owned()
    }

    fn unzip(path: &str) -> HashMap<String, Vec<u8>> {
        let file = std::fs::File::open(path).expect("打开 docx");
        let mut zip = zip::ZipArchive::new(file).expect("docx 不是合法 zip");
        let mut out = HashMap::new();
        for i in 0..zip.len() {
            let mut entry = zip.by_index(i).unwrap();
            let name = entry.name().to_string();
            let mut buf = Vec::new();
            entry.read_to_end(&mut buf).unwrap();
            out.insert(name, buf);
        }
        out
    }

    fn doc_xml(parts: &HashMap<String, Vec<u8>>) -> String {
        String::from_utf8(parts["word/document.xml"].clone()).expect("document.xml 必须是 UTF-8")
    }

    /// 代码块要有语法高亮，且配色必须和 PDF 一致 —— 两边都用 typst 的 RAW_THEME。
    /// 这几个色值直接抄自 typst-library 的主题定义，PDF 侧实测渲染出的也是它们。
    #[test]
    fn code_block_is_syntax_highlighted() {
        let dir = tempdir();
        let out = dir.join("code.docx").to_string_lossy().into_owned();
        let docs = vec![fixture::doc(vec![IrBlock::Code {
            language: Some("dart".into()),
            text: "// 注释\nvoid main() { print(\"x\"); }".into(),
        }])];
        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let xml = doc_xml(&unzip(&out));
        for (scope, hex) in [
            ("关键字", "D73948"),
            ("注释", "74747C"),
            ("字符串", "198810"),
        ] {
            assert!(
                xml.contains(&format!("w:val=\"{hex}\"")),
                "{scope}应当染成 #{hex}，实际 document.xml 里没有"
            );
        }
    }

    /// 语言未知时不该炸，退回纯文本。
    #[test]
    fn unknown_language_falls_back_to_plain() {
        let dir = tempdir();
        let out = dir.join("unknown.docx").to_string_lossy().into_owned();
        let docs = vec![fixture::doc(vec![IrBlock::Code {
            language: Some("没有这种语言".into()),
            text: "hello".into(),
        }])];
        write_docx(docs, &test_style(), out.clone(), &|| false).expect("未知语言也要能导出");
        assert!(doc_xml(&unzip(&out)).contains("hello"));
    }

    #[test]
    fn writes_chinese_content_without_mojibake() {
        let dir = tempdir();
        let out = dir.join("basic.docx").to_string_lossy().into_owned();

        let bold = IrSpan {
            text: "加粗".into(),
            bold: true,
            ..Default::default()
        };
        let italic = IrSpan {
            text: "斜体".into(),
            italic: true,
            ..Default::default()
        };
        let strike = IrSpan {
            text: "删除线".into(),
            strike: true,
            ..Default::default()
        };
        let docs = vec![IrDoc {
            id: "0190aa11-2222-3333-4444-555566667777".into(),
            title: "立秋那天的雨".into(),
            time: "2026-08-04 09:30".into(),
            weather: vec!["多云转雨".into()],
            position: vec!["浙江省".into(), "杭州市".into()],
            tags: vec![],
            category_name: Some("日常".into()),
            blocks: vec![
                IrBlock::Heading {
                    level: 2,
                    spans: vec![fixture::sp("早上")],
                },
                fixture::para(vec![
                    fixture::sp("普通文字，"),
                    bold,
                    fixture::sp("，"),
                    italic,
                    fixture::sp("，"),
                    strike,
                ]),
                IrBlock::Divider,
                IrBlock::Quote {
                    children: vec![fixture::text_para("引用一段话")],
                },
                IrBlock::Code {
                    language: None,
                    text: "fn main() {\n    println!(\"你好\");\n}".into(),
                },
            ],
        }];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let parts = unzip(&out);
        let xml = doc_xml(&parts);

        assert!(
            xml.contains("立秋那天的雨"),
            "标题应当原样落进 document.xml"
        );
        assert!(xml.contains("多云转雨"), "meta 行应当含天气");
        assert!(xml.contains("杭州市"), "meta 行取位置的最后一段");
        assert!(xml.contains("加粗"));
        assert!(xml.contains("引用一段话"));
        assert!(xml.contains("println!"), "代码块正文应当保留");
        assert!(
            String::from_utf8_lossy(&parts["word/styles.xml"]).contains("Heading2"),
            "Heading2 样式必须存在，否则 Word 导航窗格认不出标题"
        );
    }

    #[test]
    fn embeds_image_as_media_part() {
        let dir = tempdir();
        let jpeg = write_jpeg(&dir, "photo.jpg");
        let out = dir.join("image.docx").to_string_lossy().into_owned();

        let docs = vec![fixture::doc(vec![
            IrBlock::Image {
                path: jpeg,
                alt: None,
                width_percent: Some(50),
                is_external: false,
            },
            fixture::image("/nowhere/missing.jpg"),
            IrBlock::Image {
                path: "https://example.com/a.png".into(),
                alt: None,
                width_percent: None,
                is_external: true,
            },
        ])];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let parts = unzip(&out);
        // zipper 会单独写一个 `word/media/` 目录条目，过滤时要排掉它。
        let media: Vec<&String> = parts
            .keys()
            .filter(|k| k.starts_with("word/media/") && !k.ends_with('/'))
            .collect();
        assert_eq!(media.len(), 1, "只有存在的那张图应当落成 media 部件");

        // docx-rs 的 zipper 硬编码 .png 扩展名，但我们喂的是 JPEG 字节 —— 部件名与内容不符。
        // Word / WPS 按内容嗅探能渲染；哪天遇到不认的阅读器，解法是 fork 那一行按魔数定扩展名。
        let bytes = &parts[media[0]];
        assert_eq!(
            &bytes[..2],
            &[0xFF, 0xD8],
            "媒体内容应当是 JPEG（SOI 魔数）"
        );
        assert!(
            media[0].ends_with(".png"),
            "上游硬编码 .png；此断言变红说明上游改了行为，可以去掉转码假设"
        );

        let xml = doc_xml(&parts);
        assert!(xml.contains("<w:drawing>"), "图片应当以 drawing 形式插入");
        assert!(
            xml.contains("https://example.com/a.png"),
            "外链图降级成链接文字，不下载"
        );
    }

    #[test]
    fn diary_links_anchor_only_within_the_batch() {
        let dir = tempdir();
        let out = dir.join("links.docx").to_string_lossy().into_owned();

        let link = |text: &str, id: &str| IrSpan {
            text: text.into(),
            diary_link_id: Some(id.into()),
            ..Default::default()
        };
        let docs = vec![
            IrDoc {
                id: "aaa-bbb".into(),
                title: "第一篇".into(),
                blocks: vec![fixture::para(vec![
                    link("去看", "ccc-ddd"),
                    link("外部目标", "not-in-batch"),
                ])],
                ..fixture::doc(vec![])
            },
            IrDoc {
                id: "ccc-ddd".into(),
                title: "第二篇".into(),
                ..fixture::doc(vec![])
            },
        ];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let xml = doc_xml(&unzip(&out));
        assert!(
            xml.contains("d_cccddd"),
            "同批内的双链应当锚到目标日记的书签"
        );
        assert!(
            !xml.contains("d_notinbatch"),
            "不在这批里的双链只能降级成文字，不能产出悬空锚点"
        );
        assert!(xml.contains("外部目标"), "降级后文字仍要保留");
    }

    #[test]
    fn nested_lists_and_tasks_use_numbering() {
        let dir = tempdir();
        let out = dir.join("list.docx").to_string_lossy().into_owned();

        let docs = vec![fixture::doc(vec![
            IrBlock::List {
                ordered: false,
                start: 1,
                items: vec![fixture::item(
                    vec![
                        fixture::text_para("外层"),
                        IrBlock::List {
                            ordered: true,
                            start: 1,
                            items: vec![fixture::item(vec![fixture::text_para("内层")], None)],
                        },
                    ],
                    None,
                )],
            },
            IrBlock::List {
                ordered: false,
                start: 1,
                items: vec![
                    fixture::item(vec![fixture::text_para("买菜")], Some(true)),
                    fixture::item(vec![fixture::text_para("做饭")], Some(false)),
                ],
            },
        ])];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let parts = unzip(&out);
        let xml = doc_xml(&parts);
        assert!(xml.contains("外层") && xml.contains("内层"));
        assert!(xml.contains("<w:numPr>"), "列表项应当挂 numbering");
        assert!(
            xml.contains("☑") && xml.contains("☐"),
            "任务项用符号表达勾选"
        );
        assert!(
            parts.contains_key("word/numbering.xml"),
            "numbering 定义必须落盘，否则 Word 不显示项目符号"
        );
    }

    #[test]
    fn table_survives_merges_and_headers() {
        let dir = tempdir();
        let out = dir.join("table.docx").to_string_lossy().into_owned();

        let docs = vec![fixture::doc(vec![IrBlock::Table {
            rows: vec![
                IrRow {
                    cells: vec![IrCell {
                        header: true,
                        colspan: 2,
                        ..fixture::cell(vec![fixture::text_para("合并表头")])
                    }],
                },
                IrRow {
                    cells: vec![
                        fixture::cell(vec![fixture::text_para("甲")]),
                        fixture::cell(vec![fixture::text_para("乙")]),
                    ],
                },
            ],
        }])];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let xml = doc_xml(&unzip(&out));
        assert!(xml.contains("<w:tbl>"), "应当产出真表格而不是纯文本");
        assert!(xml.contains("gridSpan"), "colspan 应当写成 gridSpan");
        assert!(xml.contains("合并表头") && xml.contains("甲") && xml.contains("乙"));

        // 表宽必须显式写死并配 fixed 布局，否则 Word 按内容自动收窄，中文表会挤成窄条。
        // A4（11906）减两侧 1440 页边距 = 9026 twip，两列各 4513。
        assert!(
            xml.contains(r#"<w:tblW w:w="9026" w:type="dxa" />"#),
            "表格应当铺满正文宽度"
        );
        assert!(
            xml.contains(r#"<w:gridCol w:w="4513" w:type="dxa" />"#),
            "列宽应当均分正文宽度"
        );
        assert!(
            xml.contains(r#"<w:tblLayout w:type="fixed" />"#),
            "固定布局才让上面两项生效"
        );
    }

    #[test]
    fn multiple_docs_are_separated_by_page_breaks() {
        let dir = tempdir();
        let out = dir.join("multi.docx").to_string_lossy().into_owned();

        let docs = vec![
            IrDoc {
                id: "a".into(),
                title: "第一篇".into(),
                ..fixture::doc(vec![])
            },
            IrDoc {
                id: "b".into(),
                title: "第二篇".into(),
                ..fixture::doc(vec![])
            },
            IrDoc {
                id: "c".into(),
                title: "第三篇".into(),
                ..fixture::doc(vec![])
            },
        ];

        write_docx(docs, &test_style(), out.clone(), &|| false).expect("导出应当成功");

        let xml = doc_xml(&unzip(&out));
        assert_eq!(
            xml.matches("w:type=\"page\"").count(),
            2,
            "三篇之间插两个分页符，首篇之前不插"
        );
    }
}
