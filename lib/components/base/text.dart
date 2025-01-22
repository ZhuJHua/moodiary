import 'package:flutter/material.dart';
import 'package:moodiary/components/base/marquee.dart';
import 'package:moodiary/presentation/pref.dart';

Widget buildAdaptiveText({
  required String text,
  TextStyle? textStyle,
  required BuildContext context,
  double? maxWidth,
  bool? isTileTitle,
  bool? isTileSubtitle,
  bool? isPrimaryTitle,
  bool? isTitle,
}) {
  late final colorScheme = Theme.of(context).colorScheme;
  late final textTheme = Theme.of(context).textTheme;
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
          textScaler:
              TextScaler.linear(PrefUtil.getValue<double>('fontScale')!))
        ..layout();
      return textPainter.width > (maxWidth ?? constraints.maxWidth)
          ? SizedBox(
              height: textPainter.height,
              width: maxWidth ?? constraints.maxWidth,
              child: Marquee(
                text: text,
                velocity: 20,
                blankSpace: 20,
                textScaleFactor: PrefUtil.getValue<double>('fontScale')!,
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
              overflow: TextOverflow.ellipsis,
            );
    },
  );
}

Widget getEllipsisText({
  required String text,
  required int maxLine,
  required TextStyle textStyle,
  required BuildContext context,
}) {
  return LayoutBuilder(builder: (context, constraints) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxAllowedWidth = constraints.maxWidth;
    final fullTextWidth = _calculateTextWidth(text, textStyle, maxLine);
    if (fullTextWidth <= maxAllowedWidth) {
      return Text(
        text,
        maxLines: maxLine,
        style: textStyle,
      );
    }
    final ellipsisWidth = _calculateTextWidth('...', textStyle, maxLine);
    int leftIndex = 0;
    int rightIndex = text.length;
    double leftWidth = 0;
    double rightWidth = 0;
    while (leftIndex < rightIndex) {
      final nextLeftWidth =
          _calculateTextWidth(text[leftIndex], textStyle, maxLine) + leftWidth;
      final nextRightWidth =
          _calculateTextWidth(text[rightIndex - 1], textStyle, maxLine) +
              rightWidth;
      if (nextLeftWidth + rightWidth + ellipsisWidth > maxAllowedWidth) {
        break;
      }
      if (leftWidth <= rightWidth) {
        leftWidth = nextLeftWidth;
        leftIndex++;
      } else {
        rightWidth = nextRightWidth;
        rightIndex--;
      }
    }
    final leftText = text.substring(0, leftIndex);
    final rightText = text.substring(rightIndex);
    final realText = '$leftText...$rightText';
    return Text(
      realText,
      maxLines: maxLine,
      style: textStyle,
    );
  });
}

double _calculateTextWidth(String text, TextStyle style, int maxLines) {
  final span = TextSpan(text: text, style: style);
  final tp = TextPainter(
    text: span,
    maxLines: maxLines,
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  return tp.width;
}
