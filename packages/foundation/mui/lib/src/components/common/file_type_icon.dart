import 'dart:math' as math;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

class FileTypeIcon extends StatelessWidget {
  final String extension;

  final double size;

  final Color? color;

  const FileTypeIcon(this.extension, {super.key, this.size = 24, this.color});

  static const _innerWidthRatio = 0.52;

  static const _trackingRatio = -0.045;

  static const _maxFontRatio = 0.26;

  static final _widthAt100 = <String, double>{};

  static double _fitFontSize(String label, double maxFont, double maxWidth) {
    final unit = _widthAt100[label] ??= _measure(label);
    return math.min(maxFont, maxWidth / unit * 100);
  }

  static double _measure(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Dosis',
          package: 'mui',
          fontSize: 100,
          height: 1,
          letterSpacing: _trackingRatio * 100,
          fontVariations: [FontVariation('wght', 700)],
        ),
      ),
      textDirection: .ltr,
      textScaler: .noScaling,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final label = extension.toUpperCase();
    final tint = color ?? IconTheme.of(context).color;
    final icon = Icon(LucideIcons.file, size: size, color: tint);
    if (label.isEmpty) return icon;

    final fontSize = _fitFontSize(
      label,
      size * _maxFontRatio,
      size * _innerWidthRatio,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: .center,
        children: [
          icon,
          Padding(
            padding: .only(top: size * 0.02),
            child: Text(
              label,
              maxLines: 1,
              textScaler: .noScaling,
              style: TextStyle(
                fontFamily: 'Dosis',
                package: 'mui',
                fontSize: fontSize,
                height: 1,
                color: tint,
                letterSpacing: _trackingRatio * fontSize,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
