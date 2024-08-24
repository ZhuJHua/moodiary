import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/login/login_logic.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';

import 'login_form_state.dart';

class LoginFormLogic extends GetxController {
  final LoginFormState state = LoginFormState();

  late final loginLogic = Bind.find<LoginLogic>();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    emailFocusNode.dispose();
    passwordFocusNode.dispose();

    super.onClose();
  }

  Future<void> submit() async {
    if (state.formKey.currentState!.validate()) {
      state.formKey.currentState!.save();
      await Utils().supabaseUtil.signIn(state.email, state.password);
      Get.offAndToNamed(AppRoutes.userPage);
    }
  }
}
