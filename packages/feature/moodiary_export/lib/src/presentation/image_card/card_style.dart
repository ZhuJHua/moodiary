import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

/// 图片卡片的样式快照 —— **纯数据，不含 BuildContext**。
///
/// 离屏渲染树里没有祖先 `Theme`（见 [ImageComposer]），所以配色与排版必须在进树之前
/// 就解析好一份传进去。真源仍是 `ThemeData`：明暗两套主题都由 [ThemeManager] 现成给出，
/// 这里只挑一套、按编辑器的排版比例派生出正文/标题/代码那几档。
///
/// 排版刻意**不用 M3 的 15 级**，而是照抄编辑器 `moodiary-editor.css`：正文 16/1.7、
/// 标题 22/700、h1 1.7em、h2 1.45em、h3 1.25em。图片要像"日记本身"，不像一个 App 页面。
class ImageCardStyle {
  final Brightness brightness;

  /// 卡片逻辑宽度（dp）。
  final double widthDp;

  /// 底部品牌条。
  final bool watermark;

  final Color background;
  final Color text;
  final Color muted;
  final Color outline;
  final Color hairline;
  final Color accent;

  /// 代码块 / 行内代码的底色。
  final Color codeSurface;

  /// 图片、视频封面缺失时的占位底色。
  final Color placeholder;

  /// 叠在画面上的前景（视频播放角标）。M3 没有这个角色，来自 MuiTokens。
  final Color onMedia;

  /// 叠在画面上的遮罩底。
  final Color mediaScrim;

  /// 正文（16 / 1.7）。其余档位都从它或它的强调档派生。
  final TextStyle body;

  /// 与 [body] 同尺寸的强调档（可变字体的 wght 轴已经设好）。
  final TextStyle bodyStrong;

  /// 日记标题（22 / 1.4 / Bold）。
  final TextStyle title;

  /// 日期大字（20 / 1.3 / Bold）。
  final TextStyle dateAnchor;

  /// 元信息小字（12 / 1.4）。
  final TextStyle meta;

  /// 与 [meta] 同尺寸的强调档（心情胶囊用）。
  final TextStyle metaStrong;

  /// 等宽（代码块与行内代码）。
  final TextStyle mono;

  /// 语法高亮色表（github / github-dark，与助手同一张）。
  final Map<String, TextStyle> codeTheme;

  const ImageCardStyle({
    required this.brightness,
    required this.widthDp,
    required this.watermark,
    required this.background,
    required this.text,
    required this.muted,
    required this.outline,
    required this.hairline,
    required this.accent,
    required this.codeSurface,
    required this.placeholder,
    required this.onMedia,
    required this.mediaScrim,
    required this.body,
    required this.bodyStrong,
    required this.title,
    required this.dateAnchor,
    required this.meta,
    required this.metaStrong,
    required this.mono,
    required this.codeTheme,
  });

  /// 从一份 `ThemeData` 派生。[brightness] 决定取明还是暗那一套。
  factory ImageCardStyle.of(
    ThemeData raw, {
    required double widthDp,
    required bool watermark,
  }) {
    final theme = MuiTheme.viewOf(raw);
    final scheme = theme.colors;
    final typography = theme.typography;

    // 三个基准：常规 16、强调 16（SemiBold）、Bold 22。字重只能从排版级取 ——
    // 裸 copyWith(fontWeight:) 会被可变字体的 fontVariations 吃掉。
    final body = typography.bodyLarge.onSurface.copyWith(
      fontSize: 16,
      height: 1.7,
      letterSpacing: 0,
      color: scheme.onSurface,
    );
    final bodyStrong = typography.bodyLarge.emphasized.onSurface.copyWith(
      fontSize: 16,
      height: 1.7,
      letterSpacing: 0,
      color: scheme.onSurface,
    );
    final bold = typography.titleLarge.emphasized.onSurface;

    return ImageCardStyle(
      brightness: raw.brightness,
      widthDp: widthDp,
      watermark: watermark,
      // 卡片是"纸"，取容器阶梯最外一档：浅色纯白、深色近黑。
      background: scheme.surfaceContainerLowest,
      text: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      outline: scheme.outline,
      hairline: scheme.outlineVariant,
      accent: scheme.primary,
      codeSurface: scheme.surfaceContainer,
      placeholder: scheme.surfaceContainerHigh,
      onMedia: theme.onMedia,
      mediaScrim: scheme.scrim.withValues(alpha: 0.45),
      body: body,
      bodyStrong: bodyStrong,
      title: bold.copyWith(fontSize: 22, height: 1.4, color: scheme.onSurface),
      dateAnchor: bold.copyWith(
        fontSize: 20,
        height: 1.3,
        color: scheme.onSurface,
      ),
      meta: typography.bodySmall.onSurfaceVariant.copyWith(
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      metaStrong: typography.bodySmall.emphasized.onSurfaceVariant.copyWith(
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      mono: body.copyWith(
        fontSize: 14.08, // 0.88em，与编辑器一致
        height: 1.6,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
      ),
      codeTheme: raw.brightness == Brightness.dark
          ? darkCodeTheme
          : lightCodeTheme,
    );
  }

  /// 按当前应用主题与用户选择的明暗档解析。[fallback] 是「跟随应用」时的取值。
  factory ImageCardStyle.resolve({
    Brightness? brightness,
    required Brightness fallback,
    required double widthDp,
    required bool watermark,
  }) {
    final target = brightness ?? fallback;
    final manager = ThemeManager.instance;
    return ImageCardStyle.of(
      target == Brightness.dark ? manager.darkTheme : manager.lightTheme,
      widthDp: widthDp,
      watermark: watermark,
    );
  }

  /// 正文列宽（去掉左右内边距）。图片按百分比排版要用它。
  double get contentWidth => widthDp - horizontalPadding * 2;

  static const double horizontalPadding = 24;
  static const double topPadding = 28;
  static const double bottomPadding = 20;
}
