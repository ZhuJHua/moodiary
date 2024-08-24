import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/hunyuan.dart';
import 'package:mood_diary/utils/utils.dart';

import 'assistant_state.dart';

class AssistantLogic extends GetxController {
  final AssistantState state = AssistantState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  //ListView控制器
  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.onClose();
  }

  void handleBack() {
    if (focusNode.hasFocus) {
      unFocus();
      Future.delayed(const Duration(seconds: 1), () {
        Get.backLegacy();
      });
    } else {
      Get.backLegacy();
    }
  }

  void unFocus() {
    focusNode.unfocus();
  }

  void newChat() {
    state.messages = [];
    update();
  }

  void clearText() {
    textEditingController.clear();
  }

  //对话
  Future<void> getAi(String ask) async {
    var check = Utils().signatureUtil.checkTencent();
    if (check != null) {
      //清空输入框
      clearText();
      //失去焦点
      unFocus();
      //拿到用户提问后，对话上下文中增加一项用户提问
      state.messages.add(Message('user', ask));
      update();
      //带着上下文请求
      var stream = await Api().getHunYuan(check['id']!, check['key']!, state.messages, state.modelVersion);
      //如果收到了请求，添加一个回答上下文
      state.messages.add(Message('assistant', ''));
      update();
      //接收stream
      stream?.listen((content) {
        if (content != '' && content.contains('data')) {
          HunyuanResponse result = HunyuanResponse.fromJson(jsonDecode(content.split('data: ')[1]));
          state.messages.last.content += result.choices!.first.delta!.content!;
          HapticFeedback.vibrate();
          update();
        }
      }).onDone(() {
        toBottom();
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
    var text = getText();
    if (text != '') {
      await getAi(text);
    } else {
      Utils().noticeUtil.showToast('还没有输入问题');
    }
  }

  Future<void> changeModel() async {
    await showDialog(
        context: Get.context!,
        builder: (context) {
          return SimpleDialog(
            title: const Text('选择模型'),
            children: [
              SimpleDialogOption(
                child: Row(
                  children: [
                    const Text('hunyuan-lite'),
                    if (state.modelVersion == 0) ...[const Icon(Icons.check)]
                  ],
                ),
                onPressed: () {
                  state.modelVersion = 0;
                  state.messages = [];
                  update();
                  Get.backLegacy();
                },
              ),
              SimpleDialogOption(
                child: Row(
                  children: [
                    const Text('hunyuan-standard'),
                    if (state.modelVersion == 1) ...[const Icon(Icons.check)]
                  ],
                ),
                onPressed: () {
                  state.modelVersion = 1;
                  state.messages = [];
                  update();
                  Get.backLegacy();
                },
              ),
              SimpleDialogOption(
                child: Row(
                  children: [
                    const Text('hunyuan-pro'),
                    if (state.modelVersion == 2) ...[const Icon(Icons.check)]
                  ],
                ),
                onPressed: () {
                  state.modelVersion = 2;
                  state.messages = [];
                  update();
                  Get.backLegacy();
                },
              )
            ],
          );
        });
  }
}
