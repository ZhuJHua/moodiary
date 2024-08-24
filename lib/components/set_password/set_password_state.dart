import 'package:get/get.dart';

class SetPasswordState {
  late RxString password;

  late RxString checkPassword;

  SetPasswordState() {
    password = ''.obs;
    checkPassword = ''.obs;

    ///Initialize variables
  }
}
