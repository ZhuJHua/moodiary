import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 文件类型图标：lucide 的文件轮廓 + 写在纸面里的扩展名。
///
/// lucide 没有 md / docx / pdf 这类具体格式的图标，与其为每种格式凑一套风格不一的
/// 第三方图标，不如复用同一个文件轮廓——新增格式只是多传一个字符串。
///
/// 文字用 Dosis（圆角西文可变字体，随本包打包）：纸面里能放字的宽度只有图标尺寸的
/// 一半左右，这个字号下需要字形方正、字重可调，系统西文字体容易糊成一团。
class FileTypeIcon extends StatelessWidget {
  /// 扩展名，显示为大写。空串则只画文件轮廓。
  final String extension;

  final double size;

  /// 轮廓与文字的颜色，默认跟随 IconTheme。
  final Color? color;

  const FileTypeIcon(this.extension, {super.key, this.size = 24, this.color});

  /// 纸面去掉描边后能放字的宽度占比。lucide file 的纸面在 24 viewBox 里是
  /// x∈[4,20]，去掉 2 的描边还剩 14/24 ≈ 0.58；这里取 0.52 让最长的 DOCX 两侧
  /// 也留得住白，不至于贴上描边。
  static const _innerWidthRatio = 0.52;

  /// 字距（相对字号）。收紧字距让 DOCX 在更小的总宽里保持字号——省出来的正是左右留白。
  /// 测量与渲染必须用同一个比例，否则反推出的字号是错的。
  static const _trackingRatio = -0.045;

  /// 字号上限（相对图标尺寸）。MD / PDF 用得上这个尺寸，DOCX 会被压到放得下为止——
  /// 固定字号的话三个格式都得迁就最长的那个。
  static const _maxFontRatio = 0.26;

  /// Dosis 700 在 100px（含 [_trackingRatio] 字距）下每个字符串的实测宽度，
  /// 用来反推「放得下」的字号。
  ///
  /// **不能用 [FittedBox]**：它做的是变换缩放，把已经光栅化的字形拉伸，字号越小越糊。
  /// 这里先量宽度再定字号，文字始终在最终尺寸上排版与光栅化，边缘是清的。
  static final _widthAt100 = <String, double>{};

  static double _fitFontSize(String label, double maxFont, double maxWidth) {
    final unit = _widthAt100[label] ??= _measure(label);
    // 宽度随字号近似线性，按比例反推即可。
    return math.min(maxFont, maxWidth / unit * 100);
  }

  static double _measure(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: 'Dosis',
          package: 'moodiary_ui',
          fontSize: 100,
          height: 1,
          letterSpacing: _trackingRatio * 100,
          fontVariations: [FontVariation('wght', 700)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
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
        alignment: Alignment.center,
        children: [
          icon,
          // 纸面重心比图标中心略低——右上角被折角占掉一块。
          Padding(
            padding: EdgeInsets.only(top: size * 0.02),
            child: Text(
              label,
              maxLines: 1,
              // 不跟随正文字号缩放，否则大字号下会撑破轮廓。
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: 'Dosis',
                package: 'moodiary_ui',
                fontSize: fontSize,
                height: 1,
                color: tint,
                letterSpacing: _trackingRatio * fontSize,
                // Dosis 默认字重 200，这个字号下几乎看不清。
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
