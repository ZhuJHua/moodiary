import 'package:get/get.dart';
import 'package:moodiary/persistence/pref.dart';

class LockState {
  late RxString password;

  late RxString realPassword;

  //锁定类型，是立即锁定导致，还是启动锁定导致
  late String? lockType;

  bool get supportBiometrics =>
      PrefUtil.getValue<bool>('supportBiometrics') ?? false;

  RxBool isCheck = false.obs;

  LockState() {
    password = ''.obs;
    realPassword = PrefUtil.getValue<String>('password')!.obs;
    lockType = Get.arguments;

    ///Initialize variables
  }
}
