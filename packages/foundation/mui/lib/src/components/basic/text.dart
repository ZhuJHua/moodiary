import 'package:mui/mui.dart';

class AdaptiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double? maxWidth;
  final bool? isTileTitle;
  final bool? isTileSubtitle;
  final bool? isPrimaryTitle;
  final bool? isTitle;

  const AdaptiveText(
    this.text, {
    super.key,
    this.style,
    this.maxWidth,
    this.isTileTitle,
    this.isTileSubtitle,
    this.isPrimaryTitle,
    this.isTitle,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final textScaler = MediaQuery.textScalerOf(context);
    var textStyle = style;
    if (isTileTitle == true) {
      textStyle = typography.bodyLarge.onSurface;
    }
    if (isTileSubtitle == true) {
      textStyle = typography.bodyMedium.onSurfaceVariant;
    }
    if (isTitle == true) {
      textStyle = typography.titleLarge.onSurface;
    }
    if (isPrimaryTitle == true) {
      textStyle = typography.titleLarge.primary;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: .ltr,
          maxLines: 1,
          textScaler: textScaler,
        )..layout(maxWidth: maxWidth ?? constraints.maxWidth);
        return textPainter.didExceedMaxLines
            ? SizedBox(
                height: textPainter.height,
                width: maxWidth ?? constraints.maxWidth,
                child: Marquee(
                  text: text,
                  velocity: 20,
                  blankSpace: 20,
                  textScaler: textScaler,
                  pauseAfterRound: const Duration(seconds: 1),
                  accelerationDuration: const Duration(seconds: 1),
                  accelerationCurve: Curves.linear,
                  decelerationDuration: const Duration(milliseconds: 300),
                  decelerationCurve: Curves.easeOut,
                  style: textStyle,
                ),
              )
            : Text(text, style: textStyle, maxLines: 1, overflow: .ellipsis);
      },
    );
  }
}

extension StringExt on String {
  String removeLineBreaks() => replaceAll(RegExp(r'[\r\n]+'), '');

  String preview({int maxRunes = 500}) {
    final truncated = length <= maxRunes
        ? this
        : String.fromCharCodes(runes.take(maxRunes));
    return truncated.trim().removeLineBreaks();
  }
}

class AnimatedText extends StatelessWidget {
  const AnimatedText(
    this.text, {
    super.key,
    required this.style,
    this.placeholder = '...',
  });

  final String placeholder;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: text.trim().isEmpty
          ? Text(placeholder, key: const ValueKey('empty'), style: style)
          : Text(text, key: const ValueKey('text'), style: style),
    );
  }
}
