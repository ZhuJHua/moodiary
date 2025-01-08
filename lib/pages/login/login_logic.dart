import 'package:refreshed/refreshed.dart';

import 'login_state.dart';

class LoginLogic extends GetxController {
  final LoginState state = LoginState();

  //切换登录注册
  void changeForm() {
    state.isLogin = !state.isLogin;
    update();
  }
}
