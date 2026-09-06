import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

class ImageCardStyle {
  final Brightness brightness;

  final double widthDp;

  final bool watermark;

  final Color background;
  final Color text;
  final Color muted;
  final Color outline;
  final Color hairline;
  final Color accent;

  final Color codeSurface;

  final Color placeholder;

  final Color onMedia;

  final Color mediaScrim;

  final TextStyle body;

  final TextStyle bodyStrong;

  final TextStyle title;

  final TextStyle dateAnchor;

  final TextStyle meta;

  final TextStyle metaStrong;

  final TextStyle mono;

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

  factory ImageCardStyle.of(
    ThemeData raw, {
    required double widthDp,
    required bool watermark,
  }) {
    final theme = MuiTheme.viewOf(raw);
    final scheme = theme.colors;
    final typography = theme.typography;

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
        fontSize: 14.08,
        height: 1.6,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Courier New', 'monospace'],
      ),
      codeTheme: raw.brightness == Brightness.dark
          ? darkCodeTheme
          : lightCodeTheme,
    );
  }

  factory ImageCardStyle.resolve({
    Brightness? brightness,
    required Brightness fallback,
    required double widthDp,
    required bool watermark,
  }) {
    final target = brightness ?? fallback;
    final manager = getIt<ThemeManager>();
    return ImageCardStyle.of(
      target == Brightness.dark ? manager.darkTheme : manager.lightTheme,
      widthDp: widthDp,
      watermark: watermark,
    );
  }

  double get contentWidth => widthDp - horizontalPadding * 2;

  static const double horizontalPadding = 24;
  static const double topPadding = 28;
  static const double bottomPadding = 20;
}
