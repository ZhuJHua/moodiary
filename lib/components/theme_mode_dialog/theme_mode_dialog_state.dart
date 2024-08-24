import 'package:mood_diary/utils/utils.dart';

class ThemeModeDialogState {
  late int themeMode;

  ThemeModeDialogState() {
    themeMode = (Utils().prefUtil.getValue<int>('themeMode'))!;

    ///Initialize variables
  }
}
