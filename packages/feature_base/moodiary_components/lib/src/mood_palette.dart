import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

enum MoodPalette {
  classic(
    [0xFFD4382F, 0xFFF0936B, 0xFFD8D5CD, 0xFF79C26A, 0xFF2A9356],
    [0xFFEF5A50, 0xFFF7B08F, 0xFF66645F, 0xFF8FD27F, 0xFF34A35B],
  ),
  blueOrange(
    [0xFF4467C4, 0xFF89A8E2, 0xFFD4D1C9, 0xFFF2A13E, 0xFFD45A1E],
    [0xFF5F84DE, 0xFFA3BDEE, 0xFF6B6964, 0xFFF4B35E, 0xFFE06A2C],
  );

  const MoodPalette(this._light, this._dark);

  final List<int> _light;
  final List<int> _dark;

  static MoodPalette fromName(String? name) =>
      name == blueOrange.name ? blueOrange : classic;

  // Standalone component trees can use the default without app storage.
  static MoodPalette get _current => getIt.isRegistered<IKVStorage>()
      ? fromName(MoodiaryKVs.moodPalette.get())
      : classic;

  static MoodPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoodPaletteScope>()?.palette ??
      _current;

  Color color(DiaryMood mood, ColorScheme colorScheme) => colorScheme.harmonize(
    Color((colorScheme.brightness == .dark ? _dark : _light)[mood.index]),
  );

  Color onColor(DiaryMood mood, ColorScheme colorScheme) =>
      Color.lerp(color(mood, colorScheme), const Color(0xFF000000), 0.75)!;

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
