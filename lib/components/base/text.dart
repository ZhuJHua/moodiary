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
  required TextScaler textScaler,
}) {
  return LayoutBuilder(builder: (context, constraints) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAllowedWidth = constraints.maxWidth;
    const ellipsis = '...';

    // Helper function to calculate text width
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

    // Helper function to create a TextPainter
    TextPainter createTextPainter(String displayText) {
      return TextPainter(
        text: TextSpan(text: displayText.fixAutoLines(), style: textStyle),
        maxLines: maxLine,
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(maxWidth: maxAllowedWidth);
    }

    // Step 1: Check if the full text fits
    final fullTextPainter = createTextPainter(text);
    if (!fullTextPainter.didExceedMaxLines) {
      return Text(
        text.fixAutoLines(),
        maxLines: maxLine,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
        textScaler: textScaler,
      );
    }

    // Step 2: Binary search for truncating text
    int leftIndex = 0;
    int rightIndex = text.length;
    String truncatedText = text;

    while (leftIndex < rightIndex) {
      // Calculate widths for left and right segments
      final leftText = text.substring(0, leftIndex);
      final rightText = text.substring(rightIndex);
      final testText = '$leftText$ellipsis$rightText';

      final totalWidth = calculateTextWidth(leftText) +
          calculateTextWidth(rightText) +
          calculateTextWidth(ellipsis);

      if (totalWidth > maxAllowedWidth) {
        // Adjust longer side (prefer balanced width)
        if (calculateTextWidth(leftText) <= calculateTextWidth(rightText)) {
          rightIndex--;
        } else {
          leftIndex++;
        }
      } else {
        truncatedText = testText;
        leftIndex++;
      }
    }

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
