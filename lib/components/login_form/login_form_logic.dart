import 'package:flutter/material.dart';
import 'package:mood_diary/pages/login/login_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/supabase.dart';
import 'login_form_state.dart';

class LoginFormLogic extends GetxController {
  final LoginFormState state = LoginFormState();

  late final loginLogic = Bind.find<LoginLogic>();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  @override
  void onClose() {
    emailFocusNode.dispose();
    passwordFocusNode.dispose();

    super.onClose();
  }

  Future<void> submit() async {
    if (state.formKey.currentState!.validate()) {
      state.formKey.currentState!.save();
      await SupabaseUtil().signIn(state.email, state.password);
      Get.offAndToNamed(AppRoutes.userPage);
    }
  }
}
