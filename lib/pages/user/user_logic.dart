import 'package:mood_diary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/supabase.dart';
import 'user_state.dart';

class UserLogic extends GetxController {
  final UserState state = UserState();

  Future<void> signOut() async {
    await SupabaseUtil().signOut();
    Get.offAndToNamed(AppRoutes.loginPage);
  }
}
