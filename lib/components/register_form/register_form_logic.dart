import 'package:flutter/material.dart';
import 'package:moodiary/pages/login/login_logic.dart';
import 'package:moodiary/utils/data/supabase.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:refreshed/refreshed.dart';

import 'register_form_state.dart';

class RegisterFormLogic extends GetxController {
  final RegisterFormState state = RegisterFormState();

  final FocusNode emailFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode rePasswordFocusNode = FocusNode();
  late final loginLogic = Bind.find<LoginLogic>();

  @override
  void onClose() {
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
      await SupabaseUtil().signUp(state.email, state.password).then((value) {},
          onError: (_) {
        NoticeUtil.showToast('该账号已经注册');
      });
    }
  }
}
