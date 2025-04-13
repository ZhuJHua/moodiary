import 'package:get/get.dart';
import 'package:moodiary/common/models/isar/font.dart';
import 'package:moodiary/persistence/pref.dart';

class FontState {
  RxDouble fontScale = PrefUtil.getValue<double>('fontScale')!.obs;
  RxDouble bottomSheetHeight = 300.0.obs;
  double minHeight = 200.0; // 最小高度
  double maxHeight = 400.0; // 最大高度

  RxString currentFontFamily = PrefUtil.getValue<String>('customFont')!.obs;

  RxList<Font> fontList = <Font>[].obs;

  RxBool isFetching = true.obs;

  FontState();
}
