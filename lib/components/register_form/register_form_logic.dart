import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/pages/login/login_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'register_form_state.dart';

class RegisterFormLogic extends GetxController {
  final RegisterFormState state = RegisterFormState();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode rePasswordFocusNode = FocusNode();
  late final loginLogic = Bind.find<LoginLogic>();

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
    rePasswordFocusNode.dispose();

    super.onClose();
  }

  void unFocus() {
    emailFocusNode.unfocus();
    passwordFocusNode.unfocus();
    rePasswordFocusNode.unfocus();
  }

  Future<void> submit() async {
    unFocus();
    if (state.formKey.currentState!.validate()) {
      state.formKey.currentState!.save();
      await Utils().supabaseUtil.signUp(state.email, state.password).then((value) {}, onError: (_) {
        Utils().noticeUtil.showToast('该账号已经注册');
      });
    }
  }
}
