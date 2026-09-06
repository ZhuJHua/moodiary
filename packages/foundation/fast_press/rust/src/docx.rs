use anyhow::{Context, Result};
use docx_rs::*;
use std::collections::HashSet;
use std::fs::File;
use std::path::Path;

use crate::ir::{IrBlock, IrDoc, IrListItem, IrRow, IrSpan};

pub struct DocxStyle {
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

const NUM_BULLET: usize = 1;
const NUM_ORDERED: usize = 2;
const INDENT_STEP: i32 = 420;
const MAX_LEVEL: usize = 5;
const EMU_PER_TWIP: u32 = 635;

const CODE_BG: &str = "F2F3F5";

struct CodePiece {
    text: String,
    color: String,
    bold: bool,
    italic: bool,
}

fn highlight(language: Option<&str>, text: &str) -> Vec<Vec<CodePiece>> {
    let syntax = language
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .and_then(|l| typst::text::RAW_SYNTAXES.find_syntax_by_token(l))
        .unwrap_or_else(|| typst::text::RAW_SYNTAXES.find_syntax_plain_text());

    let mut highlighter = syntect::easy::HighlightLines::new(syntax, &typst::text::RAW_THEME);
    text.split('\n')
        .map(
            |line| match highlighter.highlight_line(line, &typst::text::RAW_SYNTAXES) {
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
                Err(_) => vec![CodePiece {
                    text: line.to_string(),
                    color: "000000".to_string(),
                    bold: false,
                    italic: false,
                }],
            },
        )
        .collect()
}
const QUOTE_COLOR: &str = "6B7686";
const LINK_COLOR: &str = "2B5CB8";
const META_COLOR: &str = "8A93A0";

pub fn write_docx(
    docs: Vec<IrDoc>,
    style: &DocxStyle,
    out_path: String,
    cancelled: &dyn Fn() -> bool,
) -> Result<()> {
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
                .line((style.line_spacing * 240.0).round() as i32),
        );

    for level in 1..=6usize {
        let scale = [1.8_f64, 1.5, 1.3, 1.15, 1.05, 1.0][level - 1];
        docx = docx.add_style(
            Style::new(format!("Heading{level}"), StyleType::Paragraph)
                .name(format!("heading {level}"))
                .bold()
                .size(half_pt(style.font_size_pt * scale))
                .fonts(run_fonts(style))
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

fn half_pt(pt: f64) -> usize {
    (pt * 2.0).round().max(2.0) as usize
}

fn content_width_emu(style: &DocxStyle) -> u32 {
    style
        .page_width
        .saturating_sub(style.page_margin.saturating_mul(2))
        .saturating_mul(EMU_PER_TWIP)
}

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
            let mut docx = docx;
            for child in children {
                docx = quoted(docx, child, ctx, depth + 1);
            }
            docx
        }

        IrBlock::List { ordered, items, .. } => list(docx, *ordered, items, ctx, depth),

        IrBlock::Code { language, text } => {
            let mut docx = docx;
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
                return docx.add_paragraph(link_paragraph(path, path, ctx));
            }
            match image_run(path, *width_percent, ctx) {
                Some(run) => docx.add_paragraph(Paragraph::new().add_run(run)),
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
                    if let Some(checked) = item.checked {
                        let mark = if checked { "☑ " } else { "☐ " };
                        para = para.add_run(fonts(Run::new(), ctx.style).add_text(mark));
                    }
                    docx = docx.add_paragraph(inline(para, spans, ctx));
                }
                other => docx = block(docx, other, ctx, depth + 1),
            }
        }
        if first {
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

fn image_run(path: &str, width_percent: Option<u32>, ctx: &Ctx) -> Option<Run> {
    let path = Path::new(path);
    if !path.is_file() {
        return None;
    }
    let bytes = std::fs::read(path).ok()?;

    let (px_w, px_h) = image::ImageReader::new(std::io::Cursor::new(&bytes))
        .with_guessed_format()
        .ok()?
        .into_dimensions()
        .ok()?;
    if px_w == 0 || px_h == 0 {
        return None;
    }

    let percent = width_percent.unwrap_or(100).clamp(1, 100);
    let target_w = ctx.content_width_emu / 100 * percent;
    let natural_w = px_w * EMU_PER_TWIP * 15;
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
    use crate::fixture;
    use crate::ir::IrCell;
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
        let media: Vec<&String> = parts
            .keys()
            .filter(|k| k.starts_with("word/media/") && !k.ends_with('/'))
            .collect();
        assert_eq!(media.len(), 1, "只有存在的那张图应当落成 media 部件");

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
