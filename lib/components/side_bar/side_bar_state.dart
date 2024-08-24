import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    getWeather = Utils().prefUtil.getValue<bool>('getWeather')!;

    ///Initialize variables
  }
}
