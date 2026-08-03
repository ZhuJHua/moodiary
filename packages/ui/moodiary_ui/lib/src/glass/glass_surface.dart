import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'package:moodiary_ui/src/glass/glass_config.dart';

/// 毛玻璃面：一层背景模糊 + 一层半透明底色 + 描边 + 投影。全仓唯一画玻璃的地方。
class MoodiaryGlassSurface extends StatelessWidget {
  final Widget child;

  /// 同时用于裁剪、描边与投影，三者必须同一个形状，否则边缘会对不齐。
  final OutlinedBorder shape;

  /// 底色。默认深色取 surfaceContainerHigh、浅色取 surfaceContainer ——
  /// 深色下需要更实一点，否则内容浮不起来。
  final Color? tint;

  /// 描边颜色。宽度恒为**一个物理像素**（`1 / devicePixelRatio`），不随屏幕密度变粗。
  final Color? borderColor;

  final List<BoxShadow>? shadows;

  const MoodiaryGlassSurface({
    super.key,
    required this.child,
    this.shape = const RoundedRectangleBorder(
      borderRadius: AppBorderRadius.largeBorderRadius,
    ),
    this.tint,
    this.borderColor,
    this.shadows,
  });

  /// 默认投影。底栏那颗动作按钮不是玻璃却要跟胶囊同款，所以抽出来共用 ——
  /// 两边各写一份迟早会飘。
  static List<BoxShadow> defaultShadows(Brightness brightness) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.42 : 0.12,
      ),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final config = MoodiaryGlass.of(context);
    final scheme = context.colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    final base =
        tint ?? (dark ? scheme.surfaceContainerHigh : scheme.surfaceContainer);
    final fill = base.withValues(alpha: config.tintAlpha);
    final side = BorderSide(
      color:
          borderColor ??
          (dark ? Colors.white.withValues(alpha: 0.18) : scheme.outlineVariant),
      // 一个物理像素。写死 0.5 在 3x 屏上其实是 1.5 个物理像素，粗得能看出来。
      width: 1 / MediaQuery.devicePixelRatioOf(context),
    );

    return CustomPaint(
      // 投影不能用 ShapeDecoration 画。两个原因叠在一起会让玻璃变成一块黑板：
      //   1. 投影和下面的 ClipPath / BackdropFilter 在**同一个渲染 pass** 里，clip 不
      //      开新 pass，所以刚画上去的投影正好是 BackdropFilter 采样的背景；
      //   2. StadiumBorder.preferPaintInterior 为 true，ShapeDecoration 画投影走的是
      //      `paintInterior` —— 实心填充整个形状，不是一圈边。
      // 于是整条胶囊内部先被糊上一层约 30% 的黑，再透过 0.72 的底色显出来。
      // 这里改成自绘并把本体从投影里挖掉，投影只留在形状外面。
      painter: _GlassShadowPainter(
        shape: shape,
        textDirection: Directionality.maybeOf(context),
        shadows: shadows ?? defaultShadows(scheme.brightness),
      ),
      child: ClipPath(
        // 裁剪必须是 BackdropFilter 的**祖先**：反过来的话模糊会溢出圆角，
        // 在深色底上是一圈很明显的方角灰边。
        clipper: ShapeBorderClipper(shape: shape),
        child: BackdropFilter(
          filter: _backdropFilter(config),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: shape.copyWith(side: side),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 先模糊、再提饱和。少了提饱和这步，出来的是「半透明板子」而不是玻璃 ——
/// iOS 的材质模糊自带这一步。饱和度恰好为 1 时不套色彩滤镜，省一层。
ImageFilter _backdropFilter(MoodiaryGlassConfig config) {
  final blur = ImageFilter.blur(
    sigmaX: config.blurSigma,
    sigmaY: config.blurSigma,
  );
  if (config.saturation == 1) return blur;
  return ImageFilter.compose(outer: _saturate(config.saturation), inner: blur);
}

/// 饱和度矩阵。系数用 sRGB 亮度权重，[s] 为 1 时是单位阵。
ColorFilter _saturate(double s) {
  const lumR = 0.213, lumG = 0.715, lumB = 0.072;
  return ColorFilter.matrix(<double>[
    lumR + s * (1 - lumR), lumG * (1 - s), lumB * (1 - s), 0, 0, //
    lumR * (1 - s), lumG + s * (1 - lumG), lumB * (1 - s), 0, 0, //
    lumR * (1 - s), lumG * (1 - s), lumB + s * (1 - lumB), 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// 只画形状**外面**那圈投影，内部挖空。见 [MoodiaryGlassSurface.build] 的注释。
class _GlassShadowPainter extends CustomPainter {
  final OutlinedBorder shape;
  final List<BoxShadow> shadows;
  final TextDirection? textDirection;

  const _GlassShadowPainter({
    required this.shape,
    required this.shadows,
    this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Offset.zero & size;
    final body = shape.getOuterPath(rect, textDirection: textDirection);

    // 挖空用的外框要盖住投影**实际**能扩散到的范围。用 blurRadius 是不够的：
    // MaskFilter 的高斯尾巴按 sigma 算，而 blurSigma = blurRadius * 0.57735 + 0.5，
    // 取 3σ 才覆盖得住，否则投影会被这个框切出一条直边。
    var reach = 0.0;
    for (final shadow in shadows) {
      reach = math.max(
        reach,
        3 * shadow.blurSigma + shadow.spreadRadius + shadow.offset.distance,
      );
    }
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(reach + 1)),
        body,
      ),
    );
    for (final shadow in shadows) {
      // 位移与扩散的算法对齐 ShapeDecoration._paintShadows，换个画法不换观感。
      canvas.drawPath(
        shape.getOuterPath(
          rect.shift(shadow.offset).inflate(shadow.spreadRadius),
          textDirection: textDirection,
        ),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.textDirection != textDirection ||
      !listEquals(oldDelegate.shadows, shadows);
}
