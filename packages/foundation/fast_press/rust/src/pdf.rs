use anyhow::{Context, Result, anyhow};
use std::collections::HashMap;
use std::fmt::Write as _;
use std::path::Path;
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime, Duration};
use typst::syntax::{FileId, Source};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World};

use crate::ir::{
    IrBlock, IrDividerVariant, IrDoc, IrListItem, IrRow, IrSpan, attachment_line, divider_label,
    media_width_percent,
};

pub struct PdfStyle {
    pub font_path: String,
    pub font_family: String,
    pub font_size_pt: f64,
    pub line_spacing_em: f64,
    pub first_line_indent: bool,
    pub page_width_mm: f64,
    pub page_height_mm: f64,
    pub page_margin_mm: f64,
    pub include_title: bool,
    pub include_meta: bool,
    pub video_label: String,
    pub audio_label: String,
    pub attachment_label: String,
}

const RULE: &str = "0.5pt + luma(180)";
const HIGHLIGHT_FILL: &str = "rgb(\"#fff0a0\")";
const WAVY: &str = "layout(size => curve(stroke: 0.6pt + luma(170), curve.move((0pt, 1.5pt)), \
    curve.quad((2pt, -3pt), (4pt, 0pt), relative: true), \
    ..range(calc.max(calc.floor(size.width / 4pt) - 1, 0))\
    .map(i => curve.quad(auto, (4pt, 0pt), relative: true))))";

pub fn write_pdf(
    docs: Vec<IrDoc>,
    style: &PdfStyle,
    out_path: String,
    cancelled: &dyn Fn() -> bool,
) -> Result<()> {
    let font_blob = std::fs::read(&style.font_path)
        .with_context(|| format!("读取字体失败：{}", style.font_path))?;

    let mut generator = Markup::new(style);
    generator.document(&docs, cancelled)?;
    if cancelled() {
        anyhow::bail!("cancelled");
    }
    let (source, images) = generator.finish();

    let world = MoodiaryWorld::new(source, font_blob, images)?;

    let compiled = typst::compile(&world);
    let document = compiled.output.map_err(|errors| {
        anyhow!(
            "排版失败：{}",
            errors
                .iter()
                .map(|e| e.message.to_string())
                .collect::<Vec<_>>()
                .join("；")
        )
    })?;

    let bytes = typst_pdf::pdf(&document, &typst_pdf::PdfOptions::default()).map_err(|errors| {
        anyhow!(
            "生成 PDF 失败：{}",
            errors
                .iter()
                .map(|e| e.message.to_string())
                .collect::<Vec<_>>()
                .join("；")
        )
    })?;

    std::fs::write(&out_path, bytes).with_context(|| format!("写入失败：{out_path}"))?;

    typst::comemo::evict(0);
    Ok(())
}

struct MoodiaryWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    source: Source,
    files: HashMap<String, Bytes>,
}

impl MoodiaryWorld {
    fn new(text: String, font_blob: Vec<u8>, images: Vec<(String, Vec<u8>)>) -> Result<Self> {
        let fonts: Vec<Font> = Font::iter(Bytes::new(font_blob)).collect();
        if fonts.is_empty() {
            return Err(anyhow!("字体文件里没有可用的字体"));
        }
        let book = FontBook::from_fonts(&fonts);
        Ok(Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(book),
            fonts,
            source: Source::detached(text),
            files: images
                .into_iter()
                .map(|(name, bytes)| (name, Bytes::new(bytes)))
                .collect(),
        })
    }
}

impl World for MoodiaryWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.source.id()
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.source.id() {
            Ok(self.source.clone())
        } else {
            Err(FileError::NotFound(id.vpath().get_without_slash().into()))
        }
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        let key = id.vpath().get_without_slash().to_string();
        self.files
            .get(&key)
            .cloned()
            .ok_or_else(|| FileError::NotFound(id.vpath().get_without_slash().into()))
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index).cloned()
    }

    fn today(&self, _offset: Option<Duration>) -> Option<Datetime> {
        None
    }
}

const PARAGRAPH_CHUNK: usize = 2000;

struct Markup<'a> {
    style: &'a PdfStyle,
    out: String,
    images: Vec<(String, Vec<u8>)>,
}

impl<'a> Markup<'a> {
    fn new(style: &'a PdfStyle) -> Self {
        Self {
            style,
            out: String::new(),
            images: Vec::new(),
        }
    }

    fn finish(self) -> (String, Vec<(String, Vec<u8>)>) {
        (self.out, self.images)
    }

    fn document(&mut self, docs: &[IrDoc], cancelled: &dyn Fn() -> bool) -> Result<()> {
        self.preamble();
        for (i, doc) in docs.iter().enumerate() {
            if cancelled() {
                anyhow::bail!("cancelled");
            }
            if i > 0 {
                self.out.push_str("#pagebreak()\n");
            }
            if self.style.include_title && !doc.title.is_empty() {
                let _ = writeln!(
                    self.out,
                    "#heading(level: 1, {})",
                    text_call(&doc.title, self.style)
                );
            }
            if self.style.include_meta {
                let meta = doc.meta_line();
                if !meta.is_empty() {
                    let _ = writeln!(
                        self.out,
                        "#text(size: {}pt, fill: luma(120), {})\n#v(0.6em)",
                        self.style.font_size_pt * 0.85,
                        string_literal(&meta)
                    );
                }
            }
            self.blocks(&doc.blocks);
        }
        Ok(())
    }

    fn preamble(&mut self) {
        let s = self.style;
        let _ = writeln!(
            self.out,
            "#set page(width: {}mm, height: {}mm, margin: {}mm, numbering: \"1 / 1\")",
            s.page_width_mm, s.page_height_mm, s.page_margin_mm
        );
        let family = if s.font_family.trim().is_empty() {
            String::new()
        } else {
            format!("font: {}, ", string_literal(&s.font_family))
        };
        let _ = writeln!(
            self.out,
            "#set text({family}size: {}pt, lang: \"zh\")",
            s.font_size_pt
        );
        let indent = if s.first_line_indent {
            ", first-line-indent: (amount: 2em, all: false)"
        } else {
            ""
        };
        let _ = writeln!(
            self.out,
            "#set par(leading: {}em, linebreaks: \"simple\"{indent})",
            s.line_spacing_em
        );
        self.out.push('\n');
    }

    fn blocks(&mut self, blocks: &[IrBlock]) {
        for block in blocks {
            self.block(block);
        }
    }

    fn block(&mut self, block: &IrBlock) {
        match block {
            IrBlock::Paragraph { spans } => {
                for chunk in chunk_spans(spans) {
                    let _ = writeln!(self.out, "#par({})", self.inline(&chunk));
                }
            }

            IrBlock::Heading { level, spans } => {
                let _ = writeln!(
                    self.out,
                    "#heading(level: {}, {})",
                    (*level).clamp(1, 6),
                    self.inline(spans)
                );
            }

            IrBlock::List {
                ordered,
                start,
                items,
            } => self.list(*ordered, *start as usize, items),

            IrBlock::Quote { children } => {
                self.out
                    .push_str("#quote(block: true)[\n#set par(first-line-indent: 0em);\n");
                self.blocks(children);
                self.out.push_str("]\n");
            }

            IrBlock::Code { language, text } => {
                let lang = language
                    .as_deref()
                    .filter(|l| !l.trim().is_empty())
                    .map(|l| format!("lang: {}, ", string_literal(l)))
                    .unwrap_or_default();
                let _ = writeln!(
                    self.out,
                    "#raw({}block: true, {})",
                    lang,
                    string_literal(text)
                );
            }

            IrBlock::Divider { variant, label } => self.divider(*variant, label.as_deref()),

            IrBlock::Image {
                path,
                alt,
                width_percent,
                is_external,
            } => self.image(path, alt.as_deref(), *width_percent, *is_external),

            IrBlock::Media {
                kind,
                name,
                filename,
                cover_path,
                width_percent,
                ..
            } => {
                if let Some(cover) = cover_path.as_deref() {
                    self.image(
                        cover,
                        name.as_deref(),
                        Some(width_percent.unwrap_or(60)),
                        false,
                    );
                }
                let label = if kind == "video" {
                    &self.style.video_label
                } else {
                    &self.style.audio_label
                };
                let _ = writeln!(
                    self.out,
                    "#text(size: {}pt, fill: luma(120), {})",
                    self.style.font_size_pt * 0.85,
                    string_literal(&format!(
                        "[{label}] {}",
                        name.as_deref().unwrap_or(filename)
                    ))
                );
            }

            IrBlock::Attachment { name, size, .. } => {
                let _ = writeln!(
                    self.out,
                    "#text(size: {}pt, fill: luma(120), {})",
                    self.style.font_size_pt * 0.85,
                    string_literal(&attachment_line(&self.style.attachment_label, name, *size))
                );
            }

            IrBlock::Table { rows } => self.table(rows),
        }
    }

    fn divider(&mut self, variant: IrDividerVariant, label: Option<&str>) {
        let line = |stroke: &str| format!("line(length: 100%, stroke: {stroke})");
        let body = match variant {
            IrDividerVariant::Solid => line(RULE),
            IrDividerVariant::Dashed => {
                line("(paint: luma(180), thickness: 0.6pt, dash: \"dashed\")")
            }
            IrDividerVariant::Dotted => {
                line("(paint: luma(160), thickness: 1pt, dash: \"dotted\")")
            }
            IrDividerVariant::Double => {
                format!("stack(spacing: 1.5pt, {}, {})", line(RULE), line(RULE))
            }
            IrDividerVariant::Wavy => WAVY.to_string(),
            IrDividerVariant::Text => match divider_label(variant, label) {
                Some(label) => format!(
                    "grid(columns: (1fr, auto, 1fr), column-gutter: 0.8em, align: horizon, {}, text(size: {}pt, fill: luma(120), {}), {})",
                    line(RULE),
                    self.style.font_size_pt * 0.85,
                    string_literal(label),
                    line(RULE)
                ),
                None => line(RULE),
            },
        };
        let _ = writeln!(self.out, "#v(0.4em)\n#{body}\n#v(0.4em)");
    }

    fn list(&mut self, ordered: bool, start: usize, items: &[IrListItem]) {
        let func = if ordered { "enum" } else { "list" };
        let head = if ordered {
            format!("#enum(start: {start}, tight: false")
        } else {
            format!("#{func}(tight: false")
        };
        self.out.push_str(&head);
        for item in items {
            self.out.push_str(",\n[#set par(first-line-indent: 0em);");
            if let Some(checked) = item.checked {
                let fill = if checked { "black" } else { "none" };
                let _ = write!(
                    self.out,
                    "#box(width: 0.7em, height: 0.7em, stroke: 0.6pt, fill: {fill}, baseline: 0.1em)#h(0.35em)"
                );
            }
            let mut rest = item.children.as_slice();
            if let Some(IrBlock::Paragraph { spans }) = rest.first() {
                let _ = write!(self.out, "#({})", self.inline(spans));
                rest = &rest[1..];
            }
            self.blocks(rest);
            self.out.push(']');
        }
        self.out.push_str(")\n");
    }

    fn table(&mut self, rows: &[IrRow]) {
        if rows.is_empty() {
            return;
        }
        let columns = rows
            .iter()
            .map(|r| r.cells.iter().map(|c| c.colspan as usize).sum::<usize>())
            .max()
            .unwrap_or(1)
            .max(1);
        let _ = write!(
            self.out,
            "#table(columns: ({}), stroke: 0.5pt + luma(180)",
            vec!["1fr"; columns].join(", ")
        );
        for row in rows {
            for cell in &row.cells {
                self.out.push_str(",\ntable.cell(");
                if cell.colspan > 1 {
                    let _ = write!(self.out, "colspan: {}, ", cell.colspan);
                }
                if cell.rowspan > 1 {
                    let _ = write!(self.out, "rowspan: {}, ", cell.rowspan);
                }
                if let Some(align) = cell.align.as_deref() {
                    let a = match align {
                        "center" => Some("center"),
                        "right" => Some("right"),
                        "justify" | "left" => Some("left"),
                        _ => None,
                    };
                    if let Some(a) = a {
                        let _ = write!(self.out, "align: {a}, ");
                    }
                }
                self.out.push_str("[#set par(first-line-indent: 0em);");
                if cell.header {
                    self.out.push_str("#strong[");
                }
                self.blocks(&cell.children);
                if cell.header {
                    self.out.push(']');
                }
                self.out.push_str("])");
            }
        }
        self.out.push_str("\n)\n");
    }

    fn image(
        &mut self,
        path: &str,
        alt: Option<&str>,
        width_percent: Option<u32>,
        is_external: bool,
    ) {
        if is_external {
            let _ = writeln!(
                self.out,
                "#link({}, {})",
                string_literal(path),
                text_call(path, self.style)
            );
            return;
        }
        let Ok(bytes) = std::fs::read(path) else {
            return;
        };
        let extension = Path::new(path)
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("jpg");
        let name = format!("img/{}.{extension}", self.images.len());
        self.images.push((name.clone(), bytes));

        let width = media_width_percent(width_percent);
        let alt_arg = alt
            .filter(|a| !a.trim().is_empty())
            .map(|a| format!(", alt: {}", string_literal(a)))
            .unwrap_or_default();
        let _ = writeln!(
            self.out,
            "#image({}, width: {width}%{alt_arg})",
            string_literal(&format!("/{name}"))
        );
    }

    fn inline(&self, spans: &[IrSpan]) -> String {
        let merged = merge_whitespace_spans(spans);
        if merged.is_empty() {
            return "[]".to_string();
        }
        let parts: Vec<String> = merged
            .iter()
            .map(|piece| match piece {
                InlinePiece::Span(s) => self.span(s),
                InlinePiece::Spacer => "box(width: 0.25em)".to_string(),
            })
            .collect();
        parts.join(" + ")
    }

    fn span(&self, span: &IrSpan) -> String {
        let pieces: Vec<String> = span
            .text
            .split('\n')
            .map(|line| self.styled(span, line))
            .collect();
        let mut body = pieces.join(" + linebreak() + ");

        if let Some(target) = span.diary_link_id.as_deref() {
            let _ = target;
            body = format!("text(fill: rgb(\"#2b5cb8\"), {body})");
        } else if let Some(href) = span.href.as_deref() {
            body = format!("link({}, {body})", string_literal(href));
        }
        body
    }

    fn styled(&self, span: &IrSpan, line: &str) -> String {
        let body = if span.code {
            format!("raw({})", string_literal(line))
        } else {
            self.decorated(span, line)
        };
        if span.highlight {
            format!("highlight(fill: {HIGHLIGHT_FILL}, {body})")
        } else {
            body
        }
    }

    fn decorated(&self, span: &IrSpan, line: &str) -> String {
        let mut body = text_call(line, self.style);
        if span.bold {
            body = format!("strong({body})");
        }
        if span.italic {
            body = format!("emph({body})");
        }
        if span.strike {
            body = format!("strike({body})");
        }
        if span.underline {
            body = format!("underline({body})");
        }
        body
    }
}

enum InlinePiece {
    Span(IrSpan),
    Spacer,
}

fn merge_whitespace_spans(spans: &[IrSpan]) -> Vec<InlinePiece> {
    fn marks_whitespace(span: &IrSpan) -> bool {
        span.strike || span.underline || span.code || span.highlight
    }
    fn blank(text: &str) -> bool {
        !text.is_empty() && text.chars().all(|c| c == ' ' || c == '\t')
    }

    let kept: Vec<&IrSpan> = spans.iter().filter(|s| !s.text.is_empty()).collect();
    let mut out: Vec<InlinePiece> = Vec::with_capacity(kept.len());
    let mut pending = String::new();

    for (i, span) in kept.iter().enumerate() {
        if !blank(&span.text) {
            let mut owned = (*span).clone();
            if !pending.is_empty() {
                owned.text.insert_str(0, &pending);
                pending.clear();
            }
            out.push(InlinePiece::Span(owned));
            continue;
        }

        if out.is_empty() {
            continue;
        }
        if let Some(InlinePiece::Span(last)) = out.last_mut()
            && !marks_whitespace(last)
        {
            last.text.push_str(&span.text);
            continue;
        }
        match kept.get(i + 1) {
            Some(next) if !marks_whitespace(next) => pending.push_str(&span.text),
            Some(_) => out.push(InlinePiece::Spacer),
            None => {}
        }
    }

    out
}

fn text_call(value: &str, _style: &PdfStyle) -> String {
    format!("text({})", string_literal(value))
}

fn string_literal(value: &str) -> typst::ecow::EcoString {
    use typst::foundations::Repr;
    value.repr()
}

fn chunk_spans(spans: &[IrSpan]) -> Vec<Vec<IrSpan>> {
    let total: usize = spans.iter().map(|s| s.text.chars().count()).sum();
    if total <= PARAGRAPH_CHUNK {
        return vec![spans.to_vec()];
    }

    let mut chunks: Vec<Vec<IrSpan>> = Vec::new();
    let mut current: Vec<IrSpan> = Vec::new();
    let mut used = 0usize;

    for span in spans {
        let mut rest: Vec<char> = span.text.chars().collect();
        while !rest.is_empty() {
            let room = PARAGRAPH_CHUNK.saturating_sub(used).max(1);
            if rest.len() <= room {
                let mut piece = span.clone();
                piece.text = rest.iter().collect();
                used += rest.len();
                current.push(piece);
                break;
            }
            let cut = break_point(&rest, room);
            let mut piece = span.clone();
            piece.text = rest[..cut].iter().collect();
            current.push(piece);
            chunks.push(std::mem::take(&mut current));
            used = 0;
            rest.drain(..cut);
        }
        if used >= PARAGRAPH_CHUNK {
            chunks.push(std::mem::take(&mut current));
            used = 0;
        }
    }
    if !current.is_empty() {
        chunks.push(current);
    }
    chunks
}

fn break_point(chars: &[char], limit: usize) -> usize {
    const PUNCT: &[char] = &[
        '。', '！', '？', '；', '，', '、', '：', '.', '!', '?', ';', ',', ' ',
    ];
    let lower = limit.saturating_sub(limit / 4).max(1);
    for i in (lower..limit).rev() {
        if PUNCT.contains(&chars[i - 1]) {
            return i;
        }
    }
    limit
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fixture;
    use crate::ir::IrCell;
    use std::io::Read;

    pub(super) fn font_path() -> String {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        dir.join("../../mui/assets/fonts/Dosis.ttf")
            .canonicalize()
            .expect("测试字体不见了")
            .to_string_lossy()
            .into_owned()
    }

    pub(super) fn style() -> PdfStyle {
        PdfStyle {
            font_path: font_path(),
            font_family: String::new(),
            font_size_pt: 11.0,
            line_spacing_em: 0.8,
            first_line_indent: true,
            page_width_mm: 210.0,
            page_height_mm: 297.0,
            page_margin_mm: 20.0,
            include_title: true,
            include_meta: true,
            video_label: "Video".into(),
            audio_label: "Audio".into(),
            attachment_label: "File".into(),
        }
    }

    fn temp(name: &str) -> String {
        let dir =
            std::env::temp_dir().join(format!("moodiary-typst-{}-{name}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir.join(format!("{name}.pdf"))
            .to_string_lossy()
            .into_owned()
    }

    fn read_head(path: &str, n: usize) -> Vec<u8> {
        let mut f = std::fs::File::open(path).expect("产物不存在");
        let mut buf = vec![0u8; n];
        let read = f.read(&mut buf).unwrap();
        buf.truncate(read);
        buf
    }

    #[test]
    fn writes_valid_pdf() {
        let out = temp("basic");
        let styled = |text: &str, f: fn(&mut IrSpan)| {
            let mut s = fixture::sp(text);
            f(&mut s);
            s
        };
        let docs = vec![IrDoc {
            id: "a".into(),
            title: "Title".into(),
            time: "2026-08-04 09:30".into(),
            weather: vec!["Cloudy".into()],
            position: vec!["Hangzhou".into()],
            tags: vec![],
            category_name: Some("Daily".into()),
            blocks: vec![
                IrBlock::Heading {
                    level: 2,
                    spans: vec![fixture::sp("Morning")],
                },
                fixture::para(vec![
                    fixture::sp("plain "),
                    styled("bold", |s| s.bold = true),
                    fixture::sp(" "),
                    styled("italic", |s| s.italic = true),
                    fixture::sp(" "),
                    styled("struck", |s| s.strike = true),
                    fixture::sp(" "),
                    IrSpan {
                        text: "link".into(),
                        href: Some("https://example.com".into()),
                        ..Default::default()
                    },
                ]),
                IrBlock::Divider {
                    variant: IrDividerVariant::Solid,
                    label: None,
                },
                IrBlock::Quote {
                    children: vec![fixture::text_para("quoted")],
                },
                IrBlock::Code {
                    language: Some("dart".into()),
                    text: "print(\"hi\");".into(),
                },
                IrBlock::List {
                    ordered: false,
                    start: 1,
                    items: vec![
                        fixture::item(vec![fixture::text_para("done")], Some(true)),
                        fixture::item(vec![fixture::text_para("todo")], Some(false)),
                    ],
                },
                IrBlock::Table {
                    rows: vec![
                        IrRow {
                            cells: vec![IrCell {
                                header: true,
                                colspan: 2,
                                ..fixture::cell(vec![fixture::text_para("merged head")])
                            }],
                        },
                        IrRow {
                            cells: vec![
                                fixture::cell(vec![fixture::text_para("a")]),
                                fixture::cell(vec![fixture::text_para("b")]),
                            ],
                        },
                    ],
                },
            ],
        }];

        write_pdf(docs, &style(), out.clone(), &|| false).expect("导出应当成功");
        assert_eq!(&read_head(&out, 5), b"%PDF-");
        assert!(std::fs::metadata(&out).unwrap().len() > 1000);
    }

    #[test]
    fn user_text_cannot_inject_typst_code() {
        let out = temp("inject");
        let payloads = [
            r#"#import "@preview/x": *"#,
            r#"") ; #import "evil" ; text(""#,
            r#"#let x = 1; #x"#,
            r#"\\\\"#,
            r#"$sum_(i=1)^n i$"#,
            "a@b.com 与 @张三",
            "a<b>c 和 5 * 3 和 _下划线_",
            "C:\\Users\\x // 注释?",
        ];
        for (i, payload) in payloads.iter().enumerate() {
            let docs = vec![IrDoc {
                id: format!("p{i}"),
                title: "inject".into(),
                ..fixture::doc(vec![fixture::text_para(payload)])
            }];
            write_pdf(docs, &style(), out.clone(), &|| false)
                .unwrap_or_else(|e| panic!("payload {i} 让导出失败了：{e}"));
            assert_eq!(&read_head(&out, 5), b"%PDF-", "payload {i}");
        }
    }

    #[test]
    fn escapes_only_backslash_and_quote() {
        assert_eq!(string_literal(r#"a"b"#), r#""a\"b""#);
        assert_eq!(string_literal(r"a\b"), r#""a\\b""#);
        assert_eq!(string_literal("#$@<>_*`[]"), "\"#$@<>_*`[]\"");
        assert_eq!(string_literal("行一\n行二"), "\"行一\\n行二\"");
    }

    #[test]
    fn huge_paragraph_completes() {
        let out = temp("huge");
        let unit = "这是一段用于测试的中文正文内容";
        let mut text = String::with_capacity(325253 * 3);
        while text.chars().count() < 325253 {
            text.push_str(unit);
        }
        let docs = vec![IrDoc {
            id: "huge".into(),
            title: "长文本测试".into(),
            ..fixture::doc(vec![fixture::text_para(&text)])
        }];

        let started = std::time::Instant::now();
        write_pdf(docs, &style(), out.clone(), &|| false).expect("32 万字应当能导出");
        let elapsed = started.elapsed();

        assert_eq!(&read_head(&out, 5), b"%PDF-");
        assert!(elapsed.as_secs() < 120, "耗时 {elapsed:?}，超出预期");
    }

    #[test]
    fn chunking_splits_at_punctuation() {
        let text: String = "句子内容。".repeat(1000);
        let spans = vec![IrSpan {
            text: text.clone(),
            ..Default::default()
        }];
        let chunks = chunk_spans(&spans);
        assert!(chunks.len() > 1, "超长段落应当被切开");
        for chunk in &chunks {
            let n: usize = chunk.iter().map(|s| s.text.chars().count()).sum();
            assert!(n <= PARAGRAPH_CHUNK, "每块不应超过阈值，实际 {n}");
        }
        let joined: String = chunks
            .iter()
            .flat_map(|c| c.iter().map(|s| s.text.clone()))
            .collect();
        assert_eq!(joined, text);
    }

    #[test]
    fn missing_font_fails_loudly() {
        let out = temp("nofont");
        let mut bad = style();
        bad.font_path = "/nowhere/none.ttf".into();
        let docs = vec![fixture::doc(vec![])];
        let err = write_pdf(docs, &bad, out.clone(), &|| false).unwrap_err();
        assert!(err.to_string().contains("读取字体失败"));
        assert!(!std::path::Path::new(&out).exists(), "失败时不应留下文件");
    }

    pub(super) fn rendered(blocks: Vec<IrBlock>) -> (String, Vec<typst::visualize::Shape>) {
        fn walk(
            frame: &typst::layout::Frame,
            text: &mut String,
            shapes: &mut Vec<typst::visualize::Shape>,
        ) {
            for (_pos, item) in frame.items() {
                match item {
                    typst::layout::FrameItem::Text(t) => text.push_str(&t.text),
                    typst::layout::FrameItem::Shape(sh, _) => shapes.push(sh.clone()),
                    typst::layout::FrameItem::Group(g) => walk(&g.frame, text, shapes),
                    _ => {}
                }
            }
        }

        let font_blob = std::fs::read(font_path()).unwrap();
        let st = style();
        let mut g = Markup::new(&st);
        g.document(&[fixture::doc(blocks)], &|| false).unwrap();
        let (source, images) = g.finish();
        let world = MoodiaryWorld::new(source, font_blob, images).unwrap();
        let doc = typst::compile(&world)
            .output
            .unwrap_or_else(|e| panic!("排版失败：{e:?}"));
        let _ = typst_pdf::pdf(&doc, &typst_pdf::PdfOptions::default()).unwrap();
        let (mut text, mut shapes) = (String::new(), Vec::new());
        for page in doc.pages() {
            walk(&page.frame, &mut text, &mut shapes);
        }
        (text, shapes)
    }

    fn divider(variant: IrDividerVariant, label: Option<&str>) -> IrBlock {
        IrBlock::Divider {
            variant,
            label: label.map(Into::into),
        }
    }

    fn line_count(shapes: &[typst::visualize::Shape]) -> usize {
        shapes
            .iter()
            .filter(|s| matches!(s.geometry, typst::visualize::Geometry::Line(_)))
            .count()
    }

    #[test]
    fn divider_variants_draw_their_shape() {
        let (_, solid) = rendered(vec![divider(IrDividerVariant::Solid, None)]);
        assert_eq!(line_count(&solid), 1, "实线应当画一条");

        let (_, double) = rendered(vec![divider(IrDividerVariant::Double, None)]);
        assert_eq!(line_count(&double), 2, "双线应当画两条");

        for variant in [IrDividerVariant::Dashed, IrDividerVariant::Dotted] {
            let (_, shapes) = rendered(vec![divider(variant, None)]);
            assert!(
                shapes
                    .iter()
                    .any(|s| s.stroke.as_ref().is_some_and(|k| k.dash.is_some())),
                "{variant:?} 应当带 dash"
            );
        }

        let (_, wavy) = rendered(vec![divider(IrDividerVariant::Wavy, None)]);
        assert!(
            wavy.iter()
                .any(|s| matches!(s.geometry, typst::visualize::Geometry::Curve(_))),
            "波浪线应当是一条曲线"
        );

        let (text, labelled) = rendered(vec![divider(IrDividerVariant::Text, Some("Day two"))]);
        assert!(
            text.contains("Day two"),
            "文字分隔线应当画出标签，实际：{text:?}"
        );
        assert_eq!(line_count(&labelled), 2, "标签两侧各一条线");

        let (_, blank) = rendered(vec![divider(IrDividerVariant::Text, Some("  "))]);
        assert_eq!(line_count(&blank), 1, "空标签退化成实线");
    }

    #[test]
    fn attachment_renders_name_and_size() {
        let (text, _) = rendered(vec![
            IrBlock::Attachment {
                name: "report.pdf".into(),
                filename: "file-0190aa11.pdf".into(),
                path: "/nowhere/file-0190aa11.pdf".into(),
                mime: Some("application/pdf".into()),
                size: Some(2048),
            },
            IrBlock::Attachment {
                name: "notes.txt".into(),
                filename: "file-0190aa12.txt".into(),
                path: "/nowhere/file-0190aa12.txt".into(),
                mime: None,
                size: None,
            },
        ]);
        assert!(
            text.contains("[File] report.pdf · 2.0 KB"),
            "实际：{text:?}"
        );
        assert!(text.contains("[File] notes.txt"), "实际：{text:?}");
    }

    #[test]
    fn media_label_prefers_name() {
        let media = |kind: &str, name: Option<&str>, filename: &str| IrBlock::Media {
            kind: kind.into(),
            name: name.map(Into::into),
            filename: filename.into(),
            path: format!("/nowhere/{filename}"),
            cover_path: None,
            width_percent: None,
        };
        let (text, _) = rendered(vec![
            media("audio", Some("Morning walk"), "audio-0190aa11.m4a"),
            media("video", None, "video-0190aa12.mp4"),
        ]);
        assert!(text.contains("[Audio] Morning walk"), "实际：{text:?}");
        assert!(!text.contains("audio-0190aa11"), "有名字时不露文件名");
        assert!(
            text.contains("[Video] video-0190aa12.mp4"),
            "实际：{text:?}"
        );
    }

    #[test]
    fn missing_image_is_skipped() {
        let out = temp("missingimg");
        let docs = vec![fixture::doc(vec![
            fixture::image("/nowhere/gone.jpg"),
            fixture::text_para("after"),
        ])];
        write_pdf(docs, &style(), out.clone(), &|| false).expect("缺图不应让导出失败");
        assert_eq!(&read_head(&out, 5), b"%PDF-");
    }
}

#[cfg(test)]
mod whitespace_between_marks {
    use super::*;
    use crate::fixture;

    fn render(spans: Vec<IrSpan>) -> (String, Vec<f64>) {
        let docs = vec![fixture::doc(vec![fixture::para(spans)])];
        let font_blob = std::fs::read(super::tests::font_path()).unwrap();
        let st = super::tests::style();
        let mut g = Markup::new(&st);
        g.document(&docs, &|| false).unwrap();
        let (source, images) = g.finish();
        let world = MoodiaryWorld::new(source, font_blob, images).unwrap();
        let compiled = typst::compile(&world);
        let doc = compiled.output.unwrap();
        let _ = typst_pdf::pdf(&doc, &typst_pdf::PdfOptions::default()).unwrap();
        let mut text = String::new();
        let mut lines = Vec::new();
        for page in doc.pages() {
            walk(&page.frame, &mut text, &mut lines);
        }
        (text, lines)
    }

    fn walk(frame: &typst::layout::Frame, text: &mut String, lines: &mut Vec<f64>) {
        for (_pos, item) in frame.items() {
            match item {
                typst::layout::FrameItem::Text(t) => text.push_str(&t.text),
                typst::layout::FrameItem::Shape(sh, _) => {
                    if let typst::visualize::Geometry::Line(to) = sh.geometry {
                        lines.push(to.x.to_pt());
                    }
                }
                typst::layout::FrameItem::Group(g) => walk(&g.frame, text, lines),
                _ => {}
            }
        }
    }

    fn word_width(word: &str) -> f64 {
        let docs = vec![fixture::doc(vec![fixture::para(vec![IrSpan {
            text: word.into(),
            underline: true,
            ..Default::default()
        }])])];
        let font_blob = std::fs::read(super::tests::font_path()).unwrap();
        let st = super::tests::style();
        let mut g = Markup::new(&st);
        g.document(&docs, &|| false).unwrap();
        let (source, images) = g.finish();
        let world = MoodiaryWorld::new(source, font_blob, images).unwrap();
        let compiled = typst::compile(&world);
        let doc = compiled.output.unwrap();
        let _ = typst_pdf::pdf(&doc, &typst_pdf::PdfOptions::default()).unwrap();
        let (mut t, mut l) = (String::new(), Vec::new());
        for page in doc.pages() {
            walk(&page.frame, &mut t, &mut l);
        }
        l[0]
    }

    #[test]
    fn code_block_is_syntax_highlighted() {
        let docs = vec![fixture::doc(vec![IrBlock::Code {
            language: Some("dart".into()),
            text: "// 注释\nvoid main() { print(\"x\"); }".into(),
        }])];
        let font_blob = std::fs::read(super::tests::font_path()).unwrap();
        let st = super::tests::style();
        let mut g = Markup::new(&st);
        g.document(&docs, &|| false).unwrap();
        let (source, images) = g.finish();
        let world = MoodiaryWorld::new(source, font_blob, images).unwrap();
        let compiled = typst::compile(&world);
        let doc = compiled.output.unwrap();
        let _ = typst_pdf::pdf(&doc, &typst_pdf::PdfOptions::default()).unwrap();

        let mut hexes = std::collections::BTreeSet::new();
        fn scan(f: &typst::layout::Frame, out: &mut std::collections::BTreeSet<String>) {
            for (_pos, item) in f.items() {
                match item {
                    typst::layout::FrameItem::Text(t) => {
                        if let typst::visualize::Paint::Solid(c) = &t.fill {
                            let rgb = c.to_rgb();
                            let q = |v: f32| (v * 255.0).round() as u8;
                            out.insert(format!(
                                "{:02X}{:02X}{:02X}",
                                q(rgb.red),
                                q(rgb.green),
                                q(rgb.blue)
                            ));
                        }
                    }
                    typst::layout::FrameItem::Group(g) => scan(&g.frame, out),
                    _ => {}
                }
            }
        }
        for page in doc.pages() {
            scan(&page.frame, &mut hexes);
        }

        for (scope, hex) in [
            ("关键字", "D73948"),
            ("注释", "74747C"),
            ("字符串", "198810"),
        ] {
            assert!(
                hexes.contains(hex),
                "{scope}应当染成 #{hex}，实际出现的颜色：{hexes:?}"
            );
        }
    }

    #[test]
    fn strike_does_not_bleed_into_following_link() {
        let (text, lines) = render(vec![
            IrSpan {
                text: "AAA".into(),
                strike: true,
                ..Default::default()
            },
            fixture::sp(" "),
            IrSpan {
                text: "BBB".into(),
                href: Some("https://example.com".into()),
                ..Default::default()
            },
        ]);

        assert!(text.contains("AAA BBB"), "空格必须保留，实际渲染：{text:?}");
        assert_eq!(lines.len(), 1, "只该有删除线一条线");
        let expected = word_width("AAA");
        assert!(
            (lines[0] - expected).abs() < 0.01,
            "删除线长 {:.2}pt，应当等于 \"AAA\" 的 {:.2}pt（渗出去了）",
            lines[0],
            expected
        );
    }

    #[test]
    fn highlight_paints_only_its_word() {
        let (text, shapes) = super::tests::rendered(vec![fixture::para(vec![
            IrSpan {
                text: "AAA".into(),
                highlight: true,
                ..Default::default()
            },
            fixture::sp(" "),
            fixture::sp("BBB"),
        ])]);
        assert!(text.contains("AAA"));
        let rects: Vec<_> = shapes
            .iter()
            .filter_map(|s| match s.geometry {
                typst::visualize::Geometry::Rect(size) => Some((size, &s.fill)),
                _ => None,
            })
            .collect();
        assert_eq!(rects.len(), 1);
        let (size, fill) = rects[0];
        assert!(
            matches!(fill, Some(typst::visualize::Paint::Solid(c)) if {
                let rgb = c.to_rgb();
                (rgb.red - 1.0).abs() < 0.01 && (rgb.blue - 160.0 / 255.0).abs() < 0.01
            }),
            "高亮应当铺一块底色"
        );
        let expected = word_width("AAA");
        assert!(
            (size.x.to_pt() - expected).abs() < 0.01,
            "高亮宽 {:.2}pt，应当等于 \"AAA\" 的 {:.2}pt",
            size.x.to_pt(),
            expected
        );
    }

    #[test]
    fn both_sides_marked_falls_back_to_spacer() {
        let (_text, lines) = render(vec![
            IrSpan {
                text: "AAA".into(),
                strike: true,
                ..Default::default()
            },
            fixture::sp(" "),
            IrSpan {
                text: "BBB".into(),
                underline: true,
                ..Default::default()
            },
        ]);

        assert_eq!(lines.len(), 2);
        let expected = word_width("AAA");
        for (i, len) in lines.iter().enumerate() {
            assert!(
                (len - expected).abs() < 0.01,
                "第 {i} 条线长 {len:.2}pt，应当等于单词宽 {expected:.2}pt"
            );
        }
    }

    #[test]
    fn plain_neighbours_keep_the_space() {
        let (text, lines) = render(vec![
            IrSpan {
                text: "AAA".into(),
                bold: true,
                ..Default::default()
            },
            fixture::sp(" "),
            IrSpan {
                text: "BBB".into(),
                italic: true,
                ..Default::default()
            },
        ]);
        assert!(text.contains("AAA BBB"), "实际渲染：{text:?}");
        assert!(lines.is_empty(), "加粗斜体不该画线");
    }
}
