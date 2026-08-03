import 'package:flutter/widgets.dart';

/// 全仓玻璃效果的配置面，由 [MoodiaryGlass] 往下发。
@immutable
class MoodiaryGlassConfig {
  /// 高斯模糊标准差，同时喂给 sigmaX / sigmaY。
  ///
  /// **别往大了调**：引擎做高斯模糊时会先把背景降采样，降采样倍数随 σ 增大，
  /// σ 一大背景就会碎成肉眼可见的一格一格（σ=30 时很明显）。想要更「玻璃」
  /// 应该降 [tintAlpha]，不是加 σ。
  final double blurSigma;

  /// 底色的不透明度。这一项才是「玻璃明不明显」的主因：0.72 时只有 28% 的背景
  /// 透得过来，模糊再狠也看不见，加 σ 是白加。
  final double tintAlpha;

  /// 背景采样的饱和度提升。iOS 的材质模糊自带这一步，少了它就只是「半透明板子」
  /// 而不是玻璃。**恰好为 1 时整层色彩滤镜不建**，可以用来单独排查它带来的问题
  /// （它会把降采样的块状伪影一起放大）。
  final double saturation;

  const MoodiaryGlassConfig({
    this.blurSigma = 20,
    this.tintAlpha = 0.62,
    this.saturation = 1.2,
  });

  MoodiaryGlassConfig copyWith({
    double? blurSigma,
    double? tintAlpha,
    double? saturation,
  }) {
    return MoodiaryGlassConfig(
      blurSigma: blurSigma ?? this.blurSigma,
      tintAlpha: tintAlpha ?? this.tintAlpha,
      saturation: saturation ?? this.saturation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MoodiaryGlassConfig &&
      other.blurSigma == blurSigma &&
      other.tintAlpha == tintAlpha &&
      other.saturation == saturation;

  @override
  int get hashCode => Object.hash(blurSigma, tintAlpha, saturation);
}

/// 配置的注入点。没套 [MoodiaryGlass] 的子树拿到的是默认值，所以单测和预览页
/// 不用额外搭壳。
class MoodiaryGlass extends InheritedWidget {
  final MoodiaryGlassConfig config;

  const MoodiaryGlass({super.key, required this.config, required super.child});

  static MoodiaryGlassConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoodiaryGlass>()?.config ??
      const MoodiaryGlassConfig();

  @override
  bool updateShouldNotify(MoodiaryGlass oldWidget) =>
      config != oldWidget.config;
}
