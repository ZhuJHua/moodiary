import 'package:get/get.dart';

import 'login_state.dart';

class LoginLogic extends GetxController {
  final LoginState state = LoginState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  //切换登录注册
  void changeForm() {
    state.isLogin = !state.isLogin;
    update();
  }
}
