part of '../editor.dart';

/// The host supplies syntax colors; typography comes from [TiptapEditorStyle.codeBlock].
/// Returned text must equal the source text.
typedef TiptapCodeHighlighter = TextSpan Function(
  String? language,
  String text,
);

/// Typography, layout policies and paint settings for an editor viewport.
class TiptapEditorStyle {
  /// Creates an editor style with defaults for text and block rendering.
  const TiptapEditorStyle({
    this.centerMedia = false,
    this.exactLineHeight = false,
    this.textRuns,
    this.taskMinHeight = 0,
    this.blockGap,
    this.cellBlockGap,
    this.ruleHeights,
    this.taskIndent,
    this.nestedTaskIndent = 0,
    this.codeBlockPadding = const EdgeInsets.fromLTRB(12, 28, 12, 12),
    this.tableCellPadding = const EdgeInsets.fromLTRB(10, 6, 10, 8),
    this.tableBlockGap = 4,
    this.tableFixedLayout = false,
    this.wrapCodeBlocks = false,
    this.tableMinRowHeight = 42,
    this.tableMinColumnWidth = 64,
    this.tableCodeMinWidth = 240,
    this.tableMediaMinWidth = 160,
    this.overflowFadeWidth = 18,
    this.overflowBackground = const Color(0xffffffff),
    this.overflowIndicatorColor = const Color(0x88687078),
    this.overflowIndicatorHeight = 2,
    this.overflowIndicatorHold = const Duration(milliseconds: 600),
    this.overflowIndicatorFade = const Duration(milliseconds: 300),
    this.firstLineIndent = 0,
    this.headingTopSpacing,
    this.headingBottomSpacing,
    this.paragraph = const TextStyle(
      fontSize: 17,
      height: 1.5,
      color: Color(0xff202124),
    ),
    this.headings = const [
      TextStyle(
        fontSize: 32,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xff202124),
      ),
      TextStyle(
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: Color(0xff202124),
      ),
      TextStyle(
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: Color(0xff202124),
      ),
      TextStyle(
        fontSize: 21,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: Color(0xff202124),
      ),
      TextStyle(
        fontSize: 19,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: Color(0xff202124),
      ),
      TextStyle(
        fontSize: 17,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: Color(0xff202124),
      ),
    ],
    this.marks = const {
      'bold': TextStyle(fontWeight: FontWeight.w700),
      'italic': TextStyle(fontStyle: FontStyle.italic),
      'underline': TextStyle(decoration: TextDecoration.underline),
      'strike': TextStyle(decoration: TextDecoration.lineThrough),
      'code': TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Color(0xffeef0f3),
      ),
      'highlight': TextStyle(backgroundColor: Color(0xffffe796)),
      'link': TextStyle(
        color: Color(0xff2463c5),
        decoration: TextDecoration.underline,
      ),
    },
    this.reference = const TextStyle(color: Color(0xff2463c5)),
    this.referenceBackground = const Color(0xffe8eefb),
    this.referencePadding = 6,
    this.referenceRadius = 4,
    this.inlineCodePadding = Offset.zero,
    this.inlineCodeRadius = 0,
    this.inlineCodeFontSizeFactor,
    this.highlightPadding = 0,
    this.highlightRadius = 0,
    this.highlightHeight,
    this.codeBlock = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 15,
      height: 1.6,
      color: Color(0xff202124),
    ),
    this.markerColor = const Color(0xff687078),
    this.quoteBorderColor = const Color(0xffc5c9d0),
    this.codeBackground = const Color(0xfff1f3f5),
    this.codeHeaderDivider,
    this.ruleColor = const Color(0xffc5c9d0),
    this.taskFillColor = const Color(0xff202124),
    this.taskCheckColor = const Color(0xffffffff),
    this.listIndent = 25.5,
    this.quoteIndent = 21.25,
    this.quoteBorderWidth = 4.25,
    this.bulletGlyphs = const ['•', '◦', '▪'],
    this.caretColor = const Color(0xff2463c5),
    this.selectionColor = const Color(0x553878dc),
    this.composingColor = const Color(0xff2463c5),
    this.handleColor = const Color(0xff2463c5),
    this.opaqueBackground = const Color(0xfff1f3f5),
    this.opaqueBorder = const Color(0xffc5c9d0),
    this.magnifierShadowColor = const Color(0x33000000),
    this.magnifierBorderColor = const Color(0x1f000000),
    this.placeholderStyle = const TextStyle(
      fontSize: 17,
      height: 1.5,
      color: Color(0xff858b95),
    ),
    this.blockSpacing = 12,
    this.padding = const EdgeInsets.all(16),
    this.caretWidth = 2,
    this.caretRadius = 2,
    this.caretHeightFactor = 1,
    this.animateCaretMovement = true,
    this.cacheExtent = 500,
    this.opaqueBlockHeight = 64,
    this.textDirection = TextDirection.ltr,
    this.textAlign = TextAlign.start,
    this.keyboardAppearance = Brightness.light,
  }) : assert(caretWidth > 0),
       assert(caretHeightFactor > 0),
       assert(caretRadius >= 0),
       assert(tableMinColumnWidth > 0),
       assert(tableCodeMinWidth > 0),
       assert(tableMediaMinWidth > 0),
       assert(overflowFadeWidth >= 0),
       assert(overflowIndicatorHeight >= 0),
       assert(blockSpacing >= 0),
       assert(cacheExtent >= 0);

  /// Minimum table column width and horizontal overflow feedback dimensions.
  final double tableMinColumnWidth, overflowFadeWidth, overflowIndicatorHeight;

  /// Minimum content widths for code and media inside table cells.
  final double tableCodeMinWidth, tableMediaMinWidth;

  /// Colors for horizontal overflow fades and scroll indicators.
  final Color overflowBackground, overflowIndicatorColor;

  /// How long overflow indicators stay visible and take to fade out.
  final Duration overflowIndicatorHold, overflowIndicatorFade;

  /// Animates short caret moves unless the platform requests reduced motion.
  final bool animateCaretMovement;

  /// Caret corner radius and height relative to its text line.
  final double caretRadius, caretHeightFactor;

  /// Controls media alignment, exact line metrics and fixed table columns.
  final bool centerMedia, exactLineHeight, tableFixedLayout;

  /// Wrap long code lines instead of scrolling the block sideways.
  final bool wrapCodeBlocks;

  /// Font-specific runs supplied by the host; their joined text must be unchanged.
  final Iterable<(String, TextStyle)> Function(String text, TextStyle style)?
  textRuns;

  /// Minimum height of a task row.
  final double taskMinHeight;

  /// Host-supplied collapsed margins, including the first/last block.
  final double Function(m.Node? previous, m.Node? next)? blockGap, cellBlockGap;

  /// Optional heights keyed by horizontal rule variant.
  final Map<String, double>? ruleHeights;

  /// Task list indentation; null uses the standard list indent.
  final double? taskIndent;

  /// Extra nested task indentation, table block spacing and minimum row height.
  final double nestedTaskIndent, tableBlockGap, tableMinRowHeight;

  /// Insets within code blocks and table cells.
  final EdgeInsets codeBlockPadding, tableCellPadding;

  /// Additional indentation for the first line of each paragraph.
  final double firstLineIndent;

  /// Optional top spacing for heading levels one through six.
  final List<double>? headingTopSpacing;

  /// Optional bottom spacing for headings.
  final double? headingBottomSpacing;

  /// Base text styles for paragraphs, code blocks and reference labels.
  final TextStyle paragraph, codeBlock, reference;

  /// Background of inline reference chips.
  final Color referenceBackground;

  /// Reference chip padding and radius, and inline code background radius.
  final double referencePadding, referenceRadius, inlineCodeRadius;

  /// Horizontal and vertical padding around inline code backgrounds.
  final Offset inlineCodePadding;

  /// Optional inline code font size multiplier relative to its block style.
  final double? inlineCodeFontSizeFactor;

  /// Absolute inline highlight padding/radius; zero preserves plain TextStyle paint.
  final double highlightPadding, highlightRadius;

  /// Optional font-box height policy for rounded highlights. The background is
  /// centred in each line box, independently of the glyph/caret baseline.
  final double Function(double ascent, double descent)? highlightHeight;

  /// Paint colors for list markers, quote borders, code, rules and task boxes.
  final Color markerColor,
      quoteBorderColor,
      codeBackground,
      ruleColor,
      taskFillColor,
      taskCheckColor;

  /// A hairline under the code block header, when a header builder is set.
  final Color? codeHeaderDivider;

  /// List and quote indentation, and quote border thickness.
  final double listIndent, quoteIndent, quoteBorderWidth;

  /// Bullet glyphs cycled by list nesting depth.
  final List<String> bulletGlyphs;

  /// Text styles for heading levels one through six.
  final List<TextStyle> headings;

  /// Inline text styles keyed by mark type.
  final Map<String, TextStyle> marks;

  /// Colors for caret, selection, composition, handles, opaque nodes and magnifier.
  final Color caretColor,
      selectionColor,
      composingColor,
      handleColor,
      opaqueBackground,
      opaqueBorder,
      magnifierShadowColor,
      magnifierBorderColor;

  /// Text style used for an empty document's placeholder.
  final TextStyle placeholderStyle;

  /// Default block gap, caret width, offscreen layout cache and opaque row height.
  final double blockSpacing, caretWidth, cacheExtent, opaqueBlockHeight;

  /// Insets around the document inside the viewport.
  final EdgeInsets padding;

  /// Base writing direction for paragraph layout.
  final TextDirection textDirection;

  /// Horizontal alignment for text blocks.
  final TextAlign textAlign;

  /// Brightness requested for the platform keyboard.
  final Brightness keyboardAppearance;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TiptapEditorStyle &&
          centerMedia == other.centerMedia &&
          exactLineHeight == other.exactLineHeight &&
          textRuns == other.textRuns &&
          taskMinHeight == other.taskMinHeight &&
          blockGap == other.blockGap &&
          cellBlockGap == other.cellBlockGap &&
          mapEquals(ruleHeights, other.ruleHeights) &&
          taskIndent == other.taskIndent &&
          nestedTaskIndent == other.nestedTaskIndent &&
          codeBlockPadding == other.codeBlockPadding &&
          tableCellPadding == other.tableCellPadding &&
          tableBlockGap == other.tableBlockGap &&
          tableFixedLayout == other.tableFixedLayout &&
          wrapCodeBlocks == other.wrapCodeBlocks &&
          tableMinRowHeight == other.tableMinRowHeight &&
          tableMinColumnWidth == other.tableMinColumnWidth &&
          tableCodeMinWidth == other.tableCodeMinWidth &&
          tableMediaMinWidth == other.tableMediaMinWidth &&
          overflowFadeWidth == other.overflowFadeWidth &&
          overflowBackground == other.overflowBackground &&
          overflowIndicatorColor == other.overflowIndicatorColor &&
          overflowIndicatorHeight == other.overflowIndicatorHeight &&
          overflowIndicatorHold == other.overflowIndicatorHold &&
          overflowIndicatorFade == other.overflowIndicatorFade &&
          firstLineIndent == other.firstLineIndent &&
          listEquals(headingTopSpacing, other.headingTopSpacing) &&
          headingBottomSpacing == other.headingBottomSpacing &&
          paragraph == other.paragraph &&
          reference == other.reference &&
          referenceBackground == other.referenceBackground &&
          referencePadding == other.referencePadding &&
          referenceRadius == other.referenceRadius &&
          inlineCodePadding == other.inlineCodePadding &&
          inlineCodeRadius == other.inlineCodeRadius &&
          inlineCodeFontSizeFactor == other.inlineCodeFontSizeFactor &&
          highlightPadding == other.highlightPadding &&
          highlightRadius == other.highlightRadius &&
          highlightHeight == other.highlightHeight &&
          codeBlock == other.codeBlock &&
          markerColor == other.markerColor &&
          quoteBorderColor == other.quoteBorderColor &&
          codeBackground == other.codeBackground &&
          codeHeaderDivider == other.codeHeaderDivider &&
          ruleColor == other.ruleColor &&
          taskFillColor == other.taskFillColor &&
          taskCheckColor == other.taskCheckColor &&
          listIndent == other.listIndent &&
          quoteIndent == other.quoteIndent &&
          quoteBorderWidth == other.quoteBorderWidth &&
          listEquals(bulletGlyphs, other.bulletGlyphs) &&
          listEquals(headings, other.headings) &&
          mapEquals(marks, other.marks) &&
          caretColor == other.caretColor &&
          selectionColor == other.selectionColor &&
          composingColor == other.composingColor &&
          handleColor == other.handleColor &&
          opaqueBackground == other.opaqueBackground &&
          opaqueBorder == other.opaqueBorder &&
          magnifierShadowColor == other.magnifierShadowColor &&
          magnifierBorderColor == other.magnifierBorderColor &&
          placeholderStyle == other.placeholderStyle &&
          blockSpacing == other.blockSpacing &&
          padding == other.padding &&
          caretWidth == other.caretWidth &&
          caretRadius == other.caretRadius &&
          caretHeightFactor == other.caretHeightFactor &&
          animateCaretMovement == other.animateCaretMovement &&
          cacheExtent == other.cacheExtent &&
          opaqueBlockHeight == other.opaqueBlockHeight &&
          textDirection == other.textDirection &&
          textAlign == other.textAlign &&
          keyboardAppearance == other.keyboardAppearance;
  @override
  int get hashCode => Object.hashAll([
    referencePadding,
    referenceRadius,
    inlineCodePadding,
    inlineCodeRadius,
    inlineCodeFontSizeFactor,
    highlightPadding,
    highlightRadius,
    highlightHeight,
    exactLineHeight,
    textRuns,
    taskMinHeight,
    blockGap,
    cellBlockGap,
    Object.hashAllUnordered(
      (ruleHeights ?? {}).entries.map((e) => Object.hash(e.key, e.value)),
    ),
    taskIndent,
    nestedTaskIndent,
    codeBlockPadding,
    tableCellPadding,
    tableBlockGap,
    tableFixedLayout,
    wrapCodeBlocks,
    tableMinRowHeight,
    tableMinColumnWidth,
    tableCodeMinWidth,
    tableMediaMinWidth,
    overflowFadeWidth,
    overflowBackground,
    overflowIndicatorColor,
    overflowIndicatorHeight,
    overflowIndicatorHold,
    overflowIndicatorFade,
    paragraph,
    codeBlock,
    markerColor,
    quoteBorderColor,
    codeBackground,
    codeHeaderDivider,
    ruleColor,
    taskFillColor,
    taskCheckColor,
    listIndent,
    quoteIndent,
    quoteBorderWidth,
    Object.hashAll(bulletGlyphs),
    Object.hashAll(headings),
    Object.hashAllUnordered(
      marks.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    caretColor,
    selectionColor,
    composingColor,
    handleColor,
    opaqueBackground,
    opaqueBorder,
    magnifierShadowColor,
    magnifierBorderColor,
    placeholderStyle,
    blockSpacing,
    padding,
    caretWidth,
    caretRadius,
    caretHeightFactor,
    animateCaretMovement,
    cacheExtent,
    opaqueBlockHeight,
    textDirection,
    textAlign,
    keyboardAppearance,
  ]);

  /// Resolves block typography with platform font fallbacks.
  TextStyle forBlock(m.Node node) {
    final base = node.type == 'heading'
        ? headings[((node.attrs['level'] as int? ?? 1) - 1).clamp(0, 5)]
        : node.type == 'codeBlock'
        ? codeBlock
        : paragraph;
    if (node.type == 'codeBlock' &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return base.copyWith(
        fontFamily: base.fontFamily == 'monospace' || base.fontFamily == null
            ? 'Menlo'
            : base.fontFamily,
        fontFamilyFallback: [
          'SF Mono',
          'monospace',
          ...?base.fontFamilyFallback,
          'Apple Color Emoji',
        ],
      );
    }
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return base;
    }
    return base.copyWith(
      fontFamily: base.fontFamily ?? '.AppleSystemUIFont',
      fontFamilyFallback: [
        ...?base.fontFamilyFallback,
        if (!(base.fontFamilyFallback?.contains('Apple Color Emoji') ?? false))
          'Apple Color Emoji',
      ],
    );
  }

  /// Applies inline mark styles to a block's base text style.
  TextStyle forInline(m.Node node, TextStyle base) {
    var result = base;
    final decorations = <TextDecoration>[
      if (base.decoration != null) base.decoration!,
    ];
    for (final mark in node.marks) {
      final override = marks[mark.type];
      if (override == null) continue;
      if (override.decoration != null) decorations.add(override.decoration!);
      result = result.merge(override);
      if (mark.type == 'code' && inlineCodeFontSizeFactor != null) {
        result = result.copyWith(
          fontSize: (base.fontSize ?? 17) * inlineCodeFontSizeFactor!,
        );
      }
      if (mark.type == 'highlight' && mark.attrs['color'] is String) {
        final hex = (mark.attrs['color']! as String).replaceFirst('#', '');
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          result = result.copyWith(
            backgroundColor: Color(
              hex.length <= 6 ? value | 0xff000000 : value,
            ),
          );
        }
      }
    }
    return decorations.isEmpty
        ? result
        : result.copyWith(decoration: TextDecoration.combine(decorations));
  }
}
