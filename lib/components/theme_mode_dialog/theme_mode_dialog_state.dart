import 'package:moodiary/presentation/pref.dart';

class ThemeModeDialogState {
  int themeMode = PrefUtil.getValue<int>('themeMode')!;

  ThemeModeDialogState();
}
