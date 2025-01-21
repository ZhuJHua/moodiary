import 'package:moodiary/utils/data/pref.dart';
import 'package:refreshed/refreshed.dart';

class FontState {
  RxDouble fontScale = PrefUtil.getValue<double>('fontScale')!.obs;
  RxDouble bottomSheetHeight = 300.0.obs;
  double minHeight = 200.0; // 最小高度
  double maxHeight = 400.0; // 最大高度

  // 当前的自定义字体的路径
  RxString currentFontPath = PrefUtil.getValue<String>('customFont')!.obs;

  // 字体路径,名称map
  RxMap<String, String> fontMap = <String, String>{}.obs;

  RxBool isFetching = true.obs;

  FontState();
}
