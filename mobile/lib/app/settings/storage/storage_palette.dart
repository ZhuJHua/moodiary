import 'package:mui/mui.dart';

/// Stable category identities from the approved storage design, in display order.
abstract final class StoragePalette {
  static const _light = [
    Color(0xffc27428),
    Color(0xff4c78a8),
    Color(0xff5e9442),
    Color(0xff5b6372),
    Color(0xff9c9784),
    Color(0xffb65a75),
    Color(0xff3e9488),
  ];
  static const _dark = [
    Color(0xffe9a15c),
    Color(0xff7fa7d6),
    Color(0xff93c774),
    Color(0xff8d96a8),
    Color(0xffc2bda8),
    Color(0xffe08ca5),
    Color(0xff6fc2b5),
  ];
  static List<Color> of(BuildContext context) =>
      context.theme.colors.brightness == .dark ? _dark : _light;
}
