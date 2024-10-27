import 'package:get/get.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'user_state.dart';

class UserLogic extends GetxController {
  final UserState state = UserState();

  Future<void> signOut() async {
    await Utils().supabaseUtil.signOut();
    Get.offAndToNamed(AppRoutes.loginPage);
  }
}
