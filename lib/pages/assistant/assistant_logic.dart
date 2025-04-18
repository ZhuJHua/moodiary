import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:moodiary/api/api.dart';
import 'package:moodiary/common/models/hunyuan.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/utils/notice_util.dart';
import 'package:moodiary/utils/signature_util.dart';

import 'assistant_state.dart';

class AssistantLogic extends GetxController {
  final AssistantState state = AssistantState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  //控制器
  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();
  late final KeyboardObserver keyboardObserver;

  List<double> heightList = [];

  @override
  void onInit() {
    keyboardObserver = KeyboardObserver(
      onStateChanged: (state) {
        switch (state) {
          case KeyboardState.opening:
            break;
          case KeyboardState.closing:
            unFocus();
            break;
          case KeyboardState.closed:
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    keyboardObserver.start();
    super.onInit();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void handleBack() {
    if (focusNode.hasFocus) {
      unFocus();
      Future.delayed(const Duration(seconds: 1), () {
        Get.back();
      });
    } else {
      Get.back();
    }
  }

  void unFocus() {
    focusNode.unfocus();
  }

  void newChat() {
    state.messages = {};
    update();
  }

  void clearText() {
    textEditingController.clear();
  }

  //对话
  Future<void> getAi(String ask) async {
    final check = SignatureUtil.checkTencent();
    if (check != null) {
      //清空输入框
      clearText();
      //失去焦点
      unFocus();
      //拿到用户提问后，对话上下文中增加一项用户提问
      final askTime = DateTime.now();
      state.messages[askTime] = Message(role: 'user', content: ask);
      update();
      toBottom();
      //带着上下文请求
      final stream = await Api.getHunYuan(
        check['id']!,
        check['key']!,
        state.messages.values.toList(),
        state.modelVersion.value,
      );
      //如果收到了请求，添加一个回答上下文
      final replyTime = DateTime.now();
      state.messages[replyTime] = const Message(role: 'assistant', content: '');
      update();
      //接收stream
      stream?.listen((content) {
        if (content != '' && content.contains('data')) {
          final HunyuanResponse result = HunyuanResponse.fromJson(
            jsonDecode(content.split('data: ')[1]),
          );
          final currentMessage = state.messages[replyTime]!;
          state.messages[replyTime] = currentMessage.copyWith(
            content:
                currentMessage.content + result.choices!.first.delta!.content!,
          );
          HapticFeedback.vibrate();
          update();
          toBottom();
        }
      });
    }
  }

  void toBottom() {
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
  }

  String getText() {
    return textEditingController.text;
  }

  Future<void> checkGetAi() async {
    final text = getText();
    if (text != '') {
      await getAi(text);
    } else {
      toast.info(message: '还没有输入问题');
    }
  }

  void changeModel(version) {
    state.modelVersion.value = version;
    state.messages = {};
  }
}
