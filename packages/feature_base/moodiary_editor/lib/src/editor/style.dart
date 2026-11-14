part of '../moodiary_editor.dart';

Color _parseColor(String? value, Color fallback) {
  final hex = value?.replaceFirst('#', '');
  final number = hex == null ? null : int.tryParse(hex, radix: 16);
  return number == null ? fallback : Color(0xff000000 | number);
}

TextStyle _textStyle({
  required Color color,
  required double size,
  double height = 1.43,
  FontWeight weight = FontWeight.w400,
  String? family,
}) {
  final apple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  final system = apple
      ? '.AppleSystemUIFont'
      : defaultTargetPlatform == TargetPlatform.windows
      ? 'Segoe UI'
      : 'sans-serif';
  return TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: family ?? system,
    fontFamilyFallback: [
      if (family != null) system,
      if (apple)
        'Apple Color Emoji'
      else if (defaultTargetPlatform == TargetPlatform.windows)
        'Segoe UI Emoji'
      else
        'Noto Color Emoji',
    ],
    fontSize: size,
    fontVariations: _appleOpticalSize(size, family),
    fontWeight: weight,
    height: height,
    letterSpacing: _appleSystemTracking(size, family),
    wordSpacing: 0,
    color: color,
  );
}

/// Document typography and colours supplied by the host.
ft.TiptapEditorStyle buildEditorStyle({
  ColorScheme? colors,
  required Brightness brightness,
  String? fontFamily,
  double fontScale = 1,
  bool firstLineIndent = false,
}) {
  final dark = brightness == Brightness.dark, body = 17 * fontScale;
  // UIKit's public system-font alias resolves in Flutter; the hidden .SF UI
  // Mono name falls back to a proportional font.
  final mono =
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS
      ? '.AppleSystemUIFontMonospaced'
      : 'monospace';
  final onSurface =
          colors?.onSurface ??
          (dark ? const Color(0xffeeeeee) : const Color(0xff1b1b1b)),
      variant = colors?.onSurfaceVariant ?? const Color(0xff777777),
      primary = colors?.primary ?? onSurface,
      outline = colors?.outlineVariant ?? const Color(0xffc6c6c6),
      container = colors?.surfaceContainer ?? const Color(0xfff0f0f0),
      surface = colors?.surface ?? const Color(0xffffffff),
      raised = colors?.surfaceContainerHigh ?? container;
  final base = _textStyle(
    family: fontFamily,
    size: body,
    height: 1.65,
    color: onSurface,
  ).copyWith(leadingDistribution: TextLeadingDistribution.even);
  return ft.TiptapEditorStyle(
    centerMedia: true,
    exactLineHeight: true,
    textRuns: _textRuns,
    taskMinHeight: body * (1.2 + .275),
    blockGap: (previous, next) => _blockGap(previous, next, body, fontScale),
    cellBlockGap: (previous, next) =>
        _blockGap(previous, next, body, fontScale, cell: true),
    codeBlockPadding: const EdgeInsets.fromLTRB(12, 38, 12, 12),
    tableCellPadding: const EdgeInsets.fromLTRB(10, 6 + 1 / 3, 10, 6 + 1 / 3),
    tableMinRowHeight: 0,
    tableMinColumnWidth: 100 * fontScale,
    overflowBackground: surface,
    overflowIndicatorColor: variant.withValues(alpha: .55),
    taskIndent: body * 1.2 + 10,
    nestedTaskIndent: body * .2,
    ruleHeights: {
      'solid': body + 1,
      'dashed': body + 1,
      'dotted': body + 4,
      'double': body + 4,
      'wavy': body + 6,
      'text': 13 * fontScale * 2.4,
    },
    paragraph: base,
    headings: [
      for (final (i, size) in [1.5, 1.25, 1.125, 1.0, 1.0, 1.0].indexed)
        base.copyWith(
          fontSize: body * size,
          letterSpacing: _appleSystemTracking(body * size, fontFamily),
          fontVariations: _appleOpticalSize(body * size, fontFamily),
          height: 1.4,
          fontWeight: i < 2 ? FontWeight.w700 : FontWeight.w600,
        ),
    ],
    headingTopSpacing: [
      for (final (i, size) in [1.5, 1.25, 1.125, 1.0, 1.0, 1.0].indexed)
        body * size * [1.5, 1.4, 1.3, 1.2, 1.2, 1.2][i],
    ],
    headingBottomSpacing: body * .4,
    blockSpacing: body * .75,
    firstLineIndent: firstLineIndent ? body * 2 : 0,
    listIndent: body * 1.5,
    quoteIndent: body * 1.25,
    quoteBorderWidth: body * .25,
    markerColor: variant,
    quoteBorderColor: outline,
    ruleColor: outline,
    caretColor: primary,
    selectionColor: primary.withValues(alpha: .28),
    handleColor: primary,
    magnifierBorderColor: colors?.surfaceBright ?? surface,
    magnifierShadowColor: (colors?.shadow ?? const Color(0xff000000))
        .withValues(alpha: dark ? .42 : .12),
    composingColor: primary,
    codeBackground: container,
    codeHeaderDivider: outline,
    opaqueBackground: container,
    opaqueBorder: outline,
    taskFillColor: onSurface,
    taskCheckColor: surface,
    reference: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
    referenceBackground: raised,
    referencePadding: 4,
    referenceRadius: 6,
    inlineCodePadding: const Offset(.35, .1),
    inlineCodeRadius: 4,
    inlineCodeFontSizeFactor: .875,
    highlightPadding: 1,
    highlightRadius: 3,
    highlightHeight:
        defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? _roundedFontBoxHeight
        : null,
    codeBlock: TextStyle(
      inherit: false,
      letterSpacing: 0,
      wordSpacing: 0,
      fontWeight: FontWeight.w400,
      fontFamily: mono,
      fontSize: 14 * fontScale,
      height: 1.6,
      color: onSurface,
    ),
    marks: {
      'bold': const TextStyle(fontWeight: FontWeight.w700),
      'italic': const TextStyle(fontStyle: FontStyle.italic),
      'underline': const TextStyle(decoration: TextDecoration.underline),
      'strike': const TextStyle(decoration: TextDecoration.lineThrough),
      'code': TextStyle(
        fontVariations: const [],
        letterSpacing: 0,
        wordSpacing: 0,
        fontFamily: mono,
        backgroundColor: raised,
      ),
      'highlight': TextStyle(
        backgroundColor: dark
            ? const Color(0xff5c4b14)
            : const Color(0xfffbe7a1),
        color: dark ? const Color(0xfff6ebc8) : onSurface,
      ),
      'link': TextStyle(color: primary, decoration: TextDecoration.underline),
    },
    placeholderStyle: base.copyWith(color: variant.withValues(alpha: .55)),
    keyboardAppearance: brightness,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  );
}

// Rounds ascent and descent up independently; mark backgrounds exclude
// line-height leading.
double _roundedFontBoxHeight(double ascent, double descent) =>
    ascent.ceilToDouble() + descent.ceilToDouble();

// Adjacent block margins collapse; media retains its space at document edges.
double _blockGap(
  ft.Node? previous,
  ft.Node? next,
  double body,
  double scale, {
  bool cell = false,
}) {
  bool media(ft.Node n) => const {
    'image',
    'video',
    'audio',
    'attachment',
    'codeBlock',
    'table',
  }.contains(n.type);
  double em(ft.Node n) =>
      n.type == 'horizontalRule' && n.attrs['variant'] == 'text'
      ? 13 * scale
      : n.type == 'heading'
      ? body *
            [
              1.5,
              1.25,
              1.125,
              1.0,
              1.0,
              1.0,
            ][((n.attrs['level'] as num? ?? 1).toInt() - 1).clamp(0, 5)]
      : body;
  double bottom(ft.Node? n) => n == null
      ? 0
      : n.type == 'horizontalRule'
      ? em(n)
      : media(n)
      ? body * .75
      : 0;
  double top = 0;
  if (next != null) {
    if (next.type == 'horizontalRule') {
      top = em(next);
    } else if (next.type == 'table' ||
        media(next) && (cell || previous == null)) {
      top = body * .75;
    } else if (!cell && previous != null) {
      top = previous.type == 'heading'
          ? em(next) * .4
          : next.type == 'heading'
          ? em(next) *
                [
                  1.5,
                  1.4,
                  1.3,
                  1.2,
                  1.2,
                  1.2,
                ][((next.attrs['level'] as num? ?? 1).toInt() - 1).clamp(0, 5)]
          : body * .75;
    }
  }
  if (next != null && media(next)) top = math.max(top, body * .75);
  return math.max(top, bottom(previous));
}

// SF tracking belongs to Latin SF glyphs. CoreText leaves fallback CJK glyphs
// untracked; applying SF's negative spacing to them changes wrapped line counts.
final _cjkRun = RegExp(
  r'[\u2e80-\u9fff\uac00-\ud7af\uf900-\ufaff\uff00-\uffef\u{20000}-\u{323af}]+',
  unicode: true,
);
Iterable<(String, TextStyle)> _textRuns(String text, TextStyle style) sync* {
  if (!_usesAppleSystemFont(style.fontFamily) || style.letterSpacing == 0) {
    yield (text, style);
    return;
  }
  var start = 0;
  for (final match in _cjkRun.allMatches(text)) {
    if (start < match.start) yield (text.substring(start, match.start), style);
    yield (match.group(0)!, style.copyWith(letterSpacing: 0));
    start = match.end;
  }
  if (start < text.length) yield (text.substring(start), style);
}

// Unknown labels use the common grammars with automatic language detection.
final _codeHighlightCache = LRUCache<(String?, String, Brightness), TextSpan>(
  maxSize: 32,
);

@visibleForTesting
TextSpan buildCodeHighlight(
  String? language,
  String text,
  Brightness brightness,
) {
  final resolved = components.resolveCodeLanguage(language);
  final key = (resolved, text, brightness),
      cached = _codeHighlightCache.get(key);
  if (cached != null) return cached;
  final renderer = components.TextSpanRenderer(
    null,
    brightness == Brightness.dark
        ? components.darkCodeTheme
        : components.lightCodeTheme,
  );
  var result = resolved == null
      ? components.codeHighlighter.justTextHighlightResult(text)
      : components.codeHighlighter.highlight(code: text, language: resolved);
  if (resolved == null) {
    // Auto-detect tolerates illegal tokens per language, unlike re_highlight's
    // highlightAuto, and keeps the first relevance tie.
    for (final name in components.codeHighlighter.listLanguages()) {
      final candidate = components.codeHighlighter.highlight(
        code: text,
        language: name,
      );
      if (candidate.relevance > result.relevance) result = candidate;
    }
  }
  result.render(renderer);
  final span = renderer.span ?? TextSpan(text: text);
  _codeHighlightCache.put(key, span);
  return span;
}
