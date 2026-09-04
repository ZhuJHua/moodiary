import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:mui/mui.dart';

import '../gen/assets.gen.dart';

/// Moodiary 的应用标识。明暗两份 SVG（`assets/brand/logo_{light,dark}.svg`），
/// 资产索引由 flutter_gen 生成，**本包是它的 owner** —— 关于页、分享图页脚都从这里取，
/// 不再各自复制一份文件。
///
/// 两种取法：
///   * [MoodiaryLogo] widget —— 正常 UI 用，跟随主题明暗；
///   * [MoodiaryLogo.rasterize] —— 离屏渲染用，先把矢量图转成 [ui.Image]。
class MoodiaryLogo extends StatelessWidget {
  /// 边长（dp）。图标是正方形的（viewBox 48×48）。
  final double size;

  /// 强制明暗。null = 跟随当前主题。
  final Brightness? brightness;

  const MoodiaryLogo({super.key, this.size = 48, this.brightness});

  @override
  Widget build(BuildContext context) {
    final dark =
        (brightness ?? Theme.of(context).brightness) == Brightness.dark;
    return _asset(dark).svg(width: size, height: size);
  }

  static SvgGenImage _asset(bool dark) =>
      dark ? Assets.brand.logoDark : Assets.brand.logoLight;

  /// 键是「明暗 + 像素边长」。同一尺寸一个进程内只解一次 —— 批量导出 300 篇日记
  /// 不该解 300 次。
  static final Map<String, ui.Image> _rasterCache = {};

  /// 预光栅化成 [ui.Image]，给拿不到第二帧的地方用。
  ///
  /// **离屏渲染树不会跑第二帧**（见 `ImageComposer`），`SvgPicture` 那条异步加载链在那里
  /// 没有机会完成，所以必须先解成位图再进树。解不出来返回 null —— 少一枚标识好过整件事失败。
  static Future<ui.Image?> rasterize({
    required Brightness brightness,
    required int pixels,
  }) async {
    final dark = brightness == Brightness.dark;
    final key = '${dark ? 'dark' : 'light'}@$pixels';
    final cached = _rasterCache[key];
    if (cached != null) return cached;
    try {
      // context 传 null：SvgAssetLoader 会回落到 rootBundle，离屏那侧拿不到 context。
      final info = await vg.loadPicture(
        SvgAssetLoader(_asset(dark).path, packageName: SvgGenImage.package),
        null,
      );
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..scale(pixels / info.size.width, pixels / info.size.height)
        ..drawPicture(info.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(pixels, pixels);
      picture.dispose();
      info.picture.dispose();
      return _rasterCache[key] = image;
    } catch (_) {
      return null;
    }
  }
}
