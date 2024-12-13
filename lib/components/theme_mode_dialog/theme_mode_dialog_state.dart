import '../../utils/data/pref.dart';

class ThemeModeDialogState {
  int themeMode = PrefUtil.getValue<int>('themeMode')!;

  ThemeModeDialogState();
}
