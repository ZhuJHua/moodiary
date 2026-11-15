import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_layout.dart';
import 'package:moodiary_diary/src/presentation/wordcloud/word_cloud_timeline.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

export 'word_cloud_timeline.dart' show WordCloudPlayMode;

/// 词云画布：负责按段摆放、文字缓存、逐帧绘制与点词命中测试。
///
/// 播放位置由外部的 [progress]（0..1）驱动，本组件不持有时钟 —— 页面用
/// 一个 AnimationController 驱动它，拖动进度条时直接写值即可。
///
/// 布局是**按段**的（见 [WordCloudTimeline]）：每段一副摆放，播放时在相邻
/// 两段之间插值位置与字号。文字只在基准字号下 layout 一次并缓存，绘制时用
/// `canvas.scale` 缩放，所以每帧没有文字 layout，也没有重新摆放。
class WordCloudCanvas extends StatefulWidget {
  final WordCloudData data;

  /// 0..1，播放进度（映射到播放窗口里的浮点段号）。
  final ValueListenable<double> progress;

  final WordCloudPlayMode mode;

  final ValueChanged<PlacedWord>? onWordTap;

  final double minFontSize;
  final double maxFontSize;

  const WordCloudCanvas({
    super.key,
    required this.data,
    required this.progress,
    this.mode = .perBucket,
    this.onWordTap,
    this.minFontSize = 12,
    this.maxFontSize = 44,
  });

  @override
  State<WordCloudCanvas> createState() => _WordCloudCanvasState();
}

class _WordCloudCanvasState extends State<WordCloudCanvas> {
  /// 度量文字用的基准字号：每个词只在这个字号下 layout 一次，
  /// 绘制时用 canvas.scale 缩放（每帧零 layout）。
  static const double _baseFontSize = 64;

  final _repaint = ValueNotifier<int>(0);
  final _labels = <String, TextPainter>{};
  Map<String, WordCloudTerm> _terms = const {};

  WordCloudTimeline? _timeline;
  Object? _timelineSource;
  Size _timelineSize = Size.zero;
  WordCloudPlayMode? _timelineMode;
  int _timelineStyle = -1;
  int _prebuiltStep = -1;

  MuiThemeData? _theme;
  TextScaler _scaler = TextScaler.noScaling;
  TextStyle? _template;
  late Color _colorFrom;
  late Color _colorTo;
  int _style = 0;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_bump);
  }

  @override
  void didUpdateWidget(covariant WordCloudCanvas old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      old.progress.removeListener(_bump);
      widget.progress.addListener(_bump);
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_bump);
    _clearLabels();
    _repaint.dispose();
    super.dispose();
  }

  void _bump() {
    _repaint.value++;
    // 走进新的一段时，先把下一段的摆放算好，段边界上就不现算。
    final timeline = _timeline;
    if (timeline == null) return;
    final step = _positionOf(timeline).floor();
    if (step == _prebuiltStep) return;
    _prebuiltStep = step;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) timeline.prebuild(step + 1);
    });
  }

  /// 摆放/主题变了必须补一次重绘：`shouldRepaint` 恒为 false，帧完全靠这个
  /// notifier 驱动（与 graph_canvas 同一套）。放在帧后，避免在 build 里标脏。
  void _bumpAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bump();
    });
  }

  void _clearLabels() {
    for (final painter in _labels.values) {
      painter.dispose();
    }
    _labels.clear();
  }

  /// 主题或文字缩放变了就要重新量字、重排。
  void _ensureStyle(BuildContext context) {
    final theme = context.theme;
    final scaler = MediaQuery.textScalerOf(context);
    if (identical(_theme, theme) && _scaler == scaler && _template != null) {
      return;
    }
    _theme = theme;
    _scaler = scaler;
    _template = theme.typography.titleLarge.emphasized.onSurface;
    _colorFrom = theme.colors.primary;
    _colorTo = theme.colors.tertiary;
    _style++;
    _clearLabels();
  }

  TextPainter _labelPainter(String word) => _labels.putIfAbsent(word, () {
    final term = _terms[word];
    return TextPainter(
      text: TextSpan(
        text: word,
        style: _template!.copyWith(
          fontSize: _baseFontSize,
          color: _colorOf(term),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: _scaler,
      maxLines: 1,
    )..layout();
  });

  /// 颜色编码的是"这个词最活跃在哪一段"（时间轴），与播放位置无关，
  /// 所以每个词的 TextPainter 只需要一份缓存。
  Color _colorOf(WordCloudTerm? term) {
    if (term == null || term.counts.length <= 1) {
      return Color.lerp(_colorFrom, _colorTo, 0.5)!;
    }
    var peak = 0;
    for (var i = 1; i < term.counts.length; i++) {
      if (term.counts[i] > term.counts[peak]) peak = i;
    }
    return Color.lerp(_colorFrom, _colorTo, peak / (term.counts.length - 1))!;
  }

  void _ensureTimeline(Size size) {
    if (size.isEmpty || widget.data.terms.isEmpty) {
      if (_timeline != null) {
        _timeline = null;
        _bumpAfterFrame();
      }
      return;
    }
    if (_timelineSource == widget.data &&
        _timelineSize == size &&
        _timelineMode == widget.mode &&
        _timelineStyle == _style) {
      return;
    }
    _timelineSource = widget.data;
    _timelineSize = size;
    _timelineMode = widget.mode;
    _timelineStyle = _style;
    _terms = {for (final term in widget.data.terms) term.word: term};
    _timeline = WordCloudTimeline(
      terms: widget.data.terms,
      activeFirst: widget.data.activeFirst,
      activeLast: widget.data.activeLast,
      mode: widget.mode,
      size: size,
      measure: (word) {
        final painter = _labelPainter(word);
        return Size(painter.width, painter.height);
      },
      baseFontSize: _baseFontSize,
      minFontSize: widget.minFontSize,
      maxFontSize: widget.maxFontSize,
    );
    _bumpAfterFrame();
  }

  double _positionOf(WordCloudTimeline timeline) =>
      widget.progress.value.clamp(0.0, 1.0) * timeline.segments;

  PlacedWord? _hitTest(Offset local) {
    final timeline = _timeline;
    if (timeline == null) return null;
    final position = _positionOf(timeline);
    PlacedWord? best;
    var bestFont = 0.0;
    for (var i = 0; i < widget.data.terms.length; i++) {
      final at = timeline.at(i, position);
      if (at == null) continue;
      final rect = Rect.fromCenter(
        center: at.center,
        width: at.size.width,
        height: at.size.height,
      );
      if (rect.contains(local) && at.fontSize > bestFont) {
        best = at;
        bestFont = at.fontSize;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _ensureStyle(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureTimeline(Size(constraints.maxWidth, constraints.maxHeight));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final hit = _hitTest(details.localPosition);
            if (hit != null) widget.onWordTap?.call(hit);
          },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _WordCloudPainter(this),
            ),
          ),
        );
      },
    );
  }
}

class _WordCloudPainter extends CustomPainter {
  final _WordCloudCanvasState s;

  _WordCloudPainter(this.s) : super(repaint: s._repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final timeline = s._timeline;
    if (timeline == null) return;
    final position = s._positionOf(timeline);
    final terms = s.widget.data.terms;

    for (var i = 0; i < terms.length; i++) {
      final at = timeline.at(i, position);
      if (at == null || at.fontSize < 0.5) continue;
      final painter = s._labelPainter(terms[i].word);
      final scale = at.fontSize / _WordCloudCanvasState._baseFontSize;
      canvas.save();
      canvas.translate(at.center.dx, at.center.dy);
      canvas.scale(scale);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  // 帧由 repaint 的 ValueNotifier 驱动（与 graph_canvas 一致）。
  @override
  bool shouldRepaint(covariant _WordCloudPainter old) => false;
}
