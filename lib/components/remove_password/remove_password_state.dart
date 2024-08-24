import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

class RemovePasswordState {
  late RxString password;

  late RxString realPassword;

  RemovePasswordState() {
    password = ''.obs;
    realPassword = Utils().prefUtil.getValue<String>('password')!.obs;

    ///Initialize variables
  }
}
