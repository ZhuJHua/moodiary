import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/pages/login/login_logic.dart';
import 'package:moodiary/persistence/supabase.dart';
import 'package:moodiary/router/app_routes.dart';

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
