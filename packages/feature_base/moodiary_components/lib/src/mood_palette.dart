import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

enum MoodPalette {
  classic(
    [0xFFB71C1C, 0xFFEE7F59, 0xFFD8D5CD, 0xFF79C26A, 0xFF1E7B45],
    [0xFFEF5A50, 0xFFF7B08F, 0xFF66645F, 0xFF8FD27F, 0xFF34A35B],
  ),
  blueOrange(
    [0xFF2C4A9C, 0xFF6E93D8, 0xFFD4D1C9, 0xFFF2A13E, 0xFFC24A16],
    [0xFF5F84DE, 0xFFA3BDEE, 0xFF6B6964, 0xFFF4B35E, 0xFFE06A2C],
  );

  const MoodPalette(this._light, this._dark);

  final List<int> _light;
  final List<int> _dark;

  static MoodPalette fromName(String? name) =>
      name == blueOrange.name ? blueOrange : classic;

  // Standalone component trees can use the default without app storage.
  static MoodPalette get current => getIt.isRegistered<IKVStorage>()
      ? fromName(MoodiaryKVs.moodPalette.get())
      : classic;

  static MoodPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoodPaletteScope>()?.palette ??
      current;

  Color color(DiaryMood mood, Brightness brightness) =>
      Color((brightness == .dark ? _dark : _light)[mood.index]);

  Color onColor(DiaryMood mood, Brightness brightness) {
    final luminance = color(mood, brightness).computeLuminance();
    const white = Color(0xFFFFFFFF);
    const ink = Color(0xFF161616);
    final whiteContrast = 1.05 / (luminance + 0.05);
    final inkContrast = (luminance + 0.05) / (ink.computeLuminance() + 0.05);
    return whiteContrast > inkContrast ? white : ink;
  }

  String label(BuildContext context) => switch (this) {
    classic => context.l10n.app.moodPaletteClassic,
    blueOrange => context.l10n.app.moodPaletteBlueOrange,
  };
}

/// Notifies mood consumers even when a palette change leaves ThemeData equal.
class MoodPaletteScope extends InheritedTheme {
  const MoodPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final MoodPalette palette;

  @override
  bool updateShouldNotify(MoodPaletteScope oldWidget) =>
      palette != oldWidget.palette;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      MoodPaletteScope(palette: palette, child: child);
}
