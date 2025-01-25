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
  TextStyle? textStyle,
  required TextScaler textScaler,
  String ellipsis = '...',
}) {
  return LayoutBuilder(builder: (context, constraints) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    double calculateTextWidth(String text) {
      final span = TextSpan(text: text.fixAutoLines(), style: textStyle);
      final tp = TextPainter(
        text: span,
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      return tp.width;
    }

    TextPainter createTextPainter(String displayText) {
      return TextPainter(
        text: TextSpan(text: displayText.fixAutoLines(), style: textStyle),
        maxLines: maxLine,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: constraints.maxWidth);
    }

    if (!createTextPainter(text).didExceedMaxLines) {
      return Text(
        text.fixAutoLines(),
        maxLines: maxLine,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
        textScaler: textScaler,
      );
    }

    int leftIndex = 0;
    int rightIndex = text.length;
    double leftWidth = 0;
    double rightWidth = 0;

    String truncatedText = text;

    int lastValidLeftIndex = 0;
    int lastValidRightIndex = text.length;

    while (leftIndex < rightIndex) {
      final nextLeftWidth = calculateTextWidth(text[leftIndex]) + leftWidth;
      final nextRightWidth =
          calculateTextWidth(text[rightIndex - 1]) + rightWidth;
      final currentText =
          '${text.substring(0, leftIndex)}$ellipsis${text.substring(rightIndex)}';
      if (createTextPainter(currentText).didExceedMaxLines) {
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

    final leftText = text.substring(0, lastValidLeftIndex);
    final rightText = text.substring(lastValidRightIndex);

    truncatedText = '$leftText$ellipsis$rightText';

    return Text(
      truncatedText.fixAutoLines(),
      maxLines: maxLine,
      style: textStyle,
      textScaler: textScaler,
    );
  });
}

extension FixAutoLines on String {
  String fixAutoLines() {
    return Characters(this).join('\u{200B}');
  }
}
