import 'package:moodiary/persistence/pref.dart';

class ThemeModeDialogState {
  int themeMode = PrefUtil.getValue<int>('themeMode')!;

  ThemeModeDialogState();
}
