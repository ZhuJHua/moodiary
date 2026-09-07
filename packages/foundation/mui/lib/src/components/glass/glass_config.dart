import 'package:flutter/widgets.dart';

@immutable
class MGlassConfig {
  final double blurSigma;

  final double tintAlpha;

  final double saturation;

  const MGlassConfig({
    this.blurSigma = 20,
    this.tintAlpha = 0.62,
    this.saturation = 1.2,
  });

  MGlassConfig copyWith({
    double? blurSigma,
    double? tintAlpha,
    double? saturation,
  }) {
    return MGlassConfig(
      blurSigma: blurSigma ?? this.blurSigma,
      tintAlpha: tintAlpha ?? this.tintAlpha,
      saturation: saturation ?? this.saturation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MGlassConfig &&
      other.blurSigma == blurSigma &&
      other.tintAlpha == tintAlpha &&
      other.saturation == saturation;

  @override
  int get hashCode => Object.hash(blurSigma, tintAlpha, saturation);
}

class MGlass extends InheritedWidget {
  final MGlassConfig config;

  const MGlass({super.key, required this.config, required super.child});

  static MGlassConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MGlass>()?.config ??
      const MGlassConfig();

  @override
  bool updateShouldNotify(MGlass oldWidget) => config != oldWidget.config;
}
