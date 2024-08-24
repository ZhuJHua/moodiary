import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class LockState {
  late RxString password;

  late RxString realPassword;

  //锁定类型，是立即锁定导致，还是启动锁定导致
  late String? lockType;

  LockState() {
    password = ''.obs;
    realPassword = Utils().prefUtil.getValue<String>('password')!.obs;
    lockType = Get.arguments;

    ///Initialize variables
  }
}
