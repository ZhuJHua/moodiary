import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:mui/mui.dart';

import '../gen/assets.gen.dart';

class MoodiaryLogo extends StatelessWidget {
  final double size;

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

  static final Map<String, ui.Image> _rasterCache = {};

  static Future<ui.Image?> rasterize({
    required Brightness brightness,
    required int pixels,
  }) async {
    final dark = brightness == Brightness.dark;
    final key = '${dark ? 'dark' : 'light'}@$pixels';
    final cached = _rasterCache[key];
    if (cached != null) return cached;
    try {
      // context 传 null：SvgAssetLoader 会回落到 rootBundle，离屏那侧拿不到 context
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
