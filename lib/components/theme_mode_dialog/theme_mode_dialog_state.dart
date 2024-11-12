import 'package:mood_diary/utils/utils.dart';

class ThemeModeDialogState {
  int themeMode = Utils().prefUtil.getValue<int>('themeMode')!;

  ThemeModeDialogState();
}
