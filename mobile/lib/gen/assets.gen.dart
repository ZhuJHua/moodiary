// dart format width=80

/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: deprecated_member_use,directives_ordering,implicit_dynamic_list_literal,unnecessary_import

import 'package:flutter/widgets.dart';

class $ResGen {
  const $ResGen();

  /// Directory path: res/sponsor
  $ResSponsorGen get sponsor => const $ResSponsorGen();
}

class $AssetsIconGen {
  const $AssetsIconGen();

  /// Directory path: assets/icon/dark
  $AssetsIconDarkGen get dark => const $AssetsIconDarkGen();

  /// Directory path: assets/icon/light
  $AssetsIconLightGen get light => const $AssetsIconLightGen();
}

class $AssetsLottieGen {
  const $AssetsLottieGen();

  /// File path: assets/lottie/file_ok.json
  String get fileOk => 'assets/lottie/file_ok.json';

  /// File path: assets/lottie/file_process.json
  String get fileProcess => 'assets/lottie/file_process.json';

  /// File path: assets/lottie/loading_cat.json
  String get loadingCat => 'assets/lottie/loading_cat.json';

  /// File path: assets/lottie/loading_material.json
  String get loadingMaterial => 'assets/lottie/loading_material.json';

  /// File path: assets/lottie/ok.json
  String get ok => 'assets/lottie/ok.json';

  /// List of all assets
  List<String> get values => [
    fileOk,
    fileProcess,
    loadingCat,
    loadingMaterial,
    ok,
  ];
}

class $ResSponsorGen {
  const $ResSponsorGen();

  /// File path: res/sponsor/wechat.jpg
  AssetGenImage get wechat => const AssetGenImage('res/sponsor/wechat.jpg');

  /// List of all assets
  List<AssetGenImage> get values => [wechat];
}

class $AssetsIconDarkGen {
  const $AssetsIconDarkGen();

  /// File path: assets/icon/dark/dark_foreground.png
  AssetGenImage get darkForeground =>
      const AssetGenImage('assets/icon/dark/dark_foreground.png');

  /// File path: assets/icon/dark/dark_icon.png
  AssetGenImage get darkIcon =>
      const AssetGenImage('assets/icon/dark/dark_icon.png');

  /// File path: assets/icon/dark/dark_icon_desktop.png
  AssetGenImage get darkIconDesktop =>
      const AssetGenImage('assets/icon/dark/dark_icon_desktop.png');

  /// File path: assets/icon/dark/dark_splash_icon.png
  AssetGenImage get darkSplashIcon =>
      const AssetGenImage('assets/icon/dark/dark_splash_icon.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    darkForeground,
    darkIcon,
    darkIconDesktop,
    darkSplashIcon,
  ];
}

class $AssetsIconLightGen {
  const $AssetsIconLightGen();

  /// File path: assets/icon/light/light_foreground.png
  AssetGenImage get lightForeground =>
      const AssetGenImage('assets/icon/light/light_foreground.png');

  /// File path: assets/icon/light/light_icon.png
  AssetGenImage get lightIcon =>
      const AssetGenImage('assets/icon/light/light_icon.png');

  /// File path: assets/icon/light/light_icon_desktop.png
  AssetGenImage get lightIconDesktop =>
      const AssetGenImage('assets/icon/light/light_icon_desktop.png');

  /// File path: assets/icon/light/light_splash_icon.png
  AssetGenImage get lightSplashIcon =>
      const AssetGenImage('assets/icon/light/light_splash_icon.png');

  /// List of all assets
  List<AssetGenImage> get values => [
    lightForeground,
    lightIcon,
    lightIconDesktop,
    lightSplashIcon,
  ];
}

abstract final class Assets {
  static const $AssetsIconGen icon = $AssetsIconGen();
  static const $AssetsLottieGen lottie = $AssetsLottieGen();
  static const $ResGen res = $ResGen();
}

class AssetGenImage {
  const AssetGenImage(
    this._assetName, {
    this.size,
    this.flavors = const {},
    this.animation,
  });

  final String _assetName;

  final Size? size;
  final Set<String> flavors;
  final AssetGenImageAnimation? animation;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = true,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.medium,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({AssetBundle? bundle, String? package}) {
    return AssetImage(_assetName, bundle: bundle, package: package);
  }

  String get path => _assetName;

  String get keyName => _assetName;
}

class AssetGenImageAnimation {
  const AssetGenImageAnimation({
    required this.isAnimation,
    required this.duration,
    required this.frames,
  });

  final bool isAnimation;
  final Duration duration;
  final int frames;
}
