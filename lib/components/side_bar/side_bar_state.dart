import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';

class SideBarState {
  var packageInfo = Rx<PackageInfo?>(null);

  late RxString hitokoto;

  late Diary diary;
  late DateTime nowTime;
  late RxString imageUrl;

  //天气
  late RxList<String> weatherResponse;

  late bool getWeather;

  SideBarState() {
    //获取信息
    hitokoto = ''.obs;
    nowTime = DateTime.now();
    imageUrl = ''.obs;
    weatherResponse = <String>[].obs;
    getWeather = PrefUtil.getValue<bool>('getWeather')!;

    ///Initialize variables
  }
}
