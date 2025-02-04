import 'package:flutter/material.dart';
import 'package:moodiary/components/base/marquee.dart';
import 'package:moodiary/utils/lru.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    var textStyle = style;
    if (isTileTitle == true) {
      textStyle = textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface);
    }
    if (isTileSubtitle == true) {
      textStyle =
          textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    }
    if (isTitle == true) {
      textStyle = textTheme.titleLarge;
    }
    if (isPrimaryTitle == true) {
      textStyle = textTheme.titleLarge?.copyWith(
        color: colorScheme.primary,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
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
            : Text(
                text,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
      },
    );
  }
}

class EllipsisText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String ellipsis;
  final int? maxLines;

  static final _cache = LRUCache<String, String>(maxSize: 1000);

  const EllipsisText(
    this.text, {
    super.key,
    this.style,
    this.ellipsis = '...',
    this.maxLines,
  });

  double _calculateTextWidth(String text, TextScaler textScaler) {
    final span = TextSpan(text: text.fixAutoLines(), style: style);
    final tp = TextPainter(
      text: span,
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return tp.width;
  }

  TextPainter _createTextPainter(
    String displayText,
    double maxWidth,
    TextScaler textScaler,
  ) {
    return TextPainter(
      text: TextSpan(text: displayText.fixAutoLines(), style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(builder: (context, constraints) {
      if (text.isEmpty) {
        return const SizedBox.shrink();
      }
      final cacheKey =
          '${text.hashCode}_${ellipsis}_${constraints.maxWidth}_$maxLines';
      final cachedResult = _cache.get(cacheKey);
      if (cachedResult != null) {
        return Text(
          cachedResult,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
          textScaler: textScaler,
        );
      }

      if (!_createTextPainter(
        text,
        constraints.maxWidth,
        textScaler,
      ).didExceedMaxLines) {
        _cache.put(cacheKey, text.fixAutoLines());
        return Text(
          text.fixAutoLines(),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
          textScaler: textScaler,
        );
      }

      int leftIndex = 0;
      int rightIndex = text.characters.length;
      double leftWidth = 0;
      double rightWidth = 0;

      int lastValidLeftIndex = 0;
      int lastValidRightIndex = text.characters.length;

      while (leftIndex < rightIndex) {
        final nextLeftWidth = _calculateTextWidth(
                text.characters.elementAt(leftIndex), textScaler) +
            leftWidth;
        final nextRightWidth = _calculateTextWidth(
                text.characters.elementAt(rightIndex - 1), textScaler) +
            rightWidth;
        final currentText =
            '${text.runeSubstring(0, leftIndex)}$ellipsis${text.runeSubstring(rightIndex)}';

        if (_createTextPainter(
          currentText,
          constraints.maxWidth,
          textScaler,
        ).didExceedMaxLines) {
          break;
        } else {
          lastValidLeftIndex = leftIndex;
          lastValidRightIndex = rightIndex;
          if (leftWidth <= rightWidth) {
            leftWidth = nextLeftWidth;
            leftIndex++;
          } else {
            rightWidth = nextRightWidth;
            rightIndex--;
          }
        }
      }

      final truncatedText =
          '${text.runeSubstring(0, lastValidLeftIndex)}$ellipsis${text.runeSubstring(lastValidRightIndex)}';

      _cache.put(cacheKey, truncatedText.fixAutoLines());

      return Text(
        truncatedText.fixAutoLines(),
        maxLines: maxLines,
        style: style,
        textScaler: textScaler,
      );
    });
  }
}

extension StringExt on String {
  String fixAutoLines() => characters.join('\u{200B}');

  String runeSubstring(int start, [int? end]) {
    return String.fromCharCodes(runes.toList().sublist(start, end));
  }

  String removeLineBreaks() => replaceAll(RegExp(r'[\r\n]+'), '');
}

class AnimatedText extends StatelessWidget {
  const AnimatedText(
    this.text, {
    super.key,
    required this.style,
    required this.isFetching,
    this.placeholder = '...',
  });

  final String placeholder;
  final String text;
  final TextStyle? style;
  final bool isFetching;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isFetching
          ? Text(
              placeholder,
              key: const ValueKey('empty'),
              style: style,
            )
          : Text(
              text,
              key: const ValueKey('text'),
              style: style,
            ),
    );
  }
}
