import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/webdav_util.dart';

import '../../common/values/webdav.dart';
import '../../utils/utils.dart';
import 'web_dav_state.dart';

class WebDavLogic extends GetxController {
  final WebDavState state = WebDavState();

  WebDavUtil get webDav => Utils().webDavUtil;

  late TextEditingController webDavUrlController =
      TextEditingController(text: state.hasOption.value ? state.currentOptions[0] : null);
  late FocusNode webDavUrlFocusNode = FocusNode();
  late TextEditingController usernameController =
      TextEditingController(text: state.hasOption.value ? state.currentOptions[1] : null);
  late FocusNode usernameFocusNode = FocusNode();
  late TextEditingController passwordController =
      TextEditingController(text: state.hasOption.value ? state.currentOptions[2] : null);
  late FocusNode passwordFocusNode = FocusNode();

  @override
  void onReady() async {
    if (state.hasOption.value) {
      await checkConnectivity();
    }
    super.onReady();
  }

  @override
  void onClose() {
    webDavUrlFocusNode.dispose();
    usernameFocusNode.dispose();
    passwordFocusNode.dispose();
    webDavUrlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> checkConnectivity() async {
    state.connectivityStatus.value = WebDavConnectivityStatus.connecting;
    var res = await webDav.checkConnectivity();
    state.connectivityStatus.value = res ? WebDavConnectivityStatus.connected : WebDavConnectivityStatus.unconnected;
  }

  void unFocus() {
    if (webDavUrlFocusNode.hasFocus) webDavUrlFocusNode.unfocus();
    if (usernameFocusNode.hasFocus) usernameFocusNode.unfocus();
    if (passwordFocusNode.hasFocus) passwordFocusNode.unfocus();
  }

  void submitForm() async {
    if (state.formKey.currentState?.validate() ?? false) {
      unFocus();
      state.formKey.currentState?.save();

      await webDav.updateWebDav(
          baseUrl: webDavUrlController.text, username: usernameController.text, password: passwordController.text);
      state.hasOption.value = true;
      await checkConnectivity();
      await webDav.initDir();
      Utils().noticeUtil.showToast('保存成功');
    }
  }

  DateTime? _firstClickTime; // 用于记录第一次点击时间

  void removeWebDavOption() {
    final currentTime = DateTime.now();

    if (_firstClickTime == null) {
      _firstClickTime = currentTime;
      Utils().noticeUtil.showToast('请再次点击确认删除');
      return;
    }
    if (currentTime.difference(_firstClickTime!).inSeconds <= 2) {
      _firstClickTime = null; // 重置点击时间
      webDavUrlController.text = '';
      usernameController.text = '';
      passwordController.text = '';
      state.hasOption.value = false;
      webDav.removeWebDavOption();
      Utils().noticeUtil.showToast('删除成功');
    } else {
      // 超过3秒，重置点击时间并提示
      _firstClickTime = currentTime;
      Utils().noticeUtil.showToast('请再次点击确认删除');
    }
  }

  void setAutoSync(bool value) async {
    await Utils().prefUtil.setValue<bool>('autoSync', value);
    state.autoSync.value = value;
  }
}
