import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/hunyuan.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';
import 'package:mood_diary/pages/home/home_logic.dart';
import 'package:mood_diary/utils/utils.dart';

import 'assistant_state.dart';

class AssistantLogic extends GetxController with WidgetsBindingObserver {
  final AssistantState state = AssistantState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  //控制器
  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();

  late final HomeLogic homeLogic = Bind.find<HomeLogic>();

  List<double> heightList = [];

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var height = MediaQuery.viewInsetsOf(Get.context!).bottom;
      if (heightList.isNotEmpty && height != heightList.last) {
        if (height > heightList.last && state.keyboardState != KeyboardState.opening) {
          state.keyboardState = KeyboardState.opening;
          //正在打开
        } else if (height < heightList.last && state.keyboardState != KeyboardState.closing) {
          state.keyboardState = KeyboardState.closing;
          //正在关闭
          unFocus();
        }
      }

      // 只在高度变化时记录高度
      if (heightList.isEmpty || height != heightList.last) {
        heightList.add(height);
      }

      // 当高度为0且键盘经历了开启关闭过程时，认为键盘已完全关闭
      if (height == 0 && state.keyboardState != KeyboardState.closed) {
        state.keyboardState = KeyboardState.closed;
        heightList.clear();
        //已经关闭
      }
    });
    super.didChangeMetrics();
  }

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    super.onInit();
  }

  @override
  void onReady() {
    homeLogic.hideNavigatorBar();
    super.onReady();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
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
    state.messages = {};
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
      var askTime = DateTime.now();
      state.messages[askTime] = Message('user', ask);
      update();
      toBottom();
      //带着上下文请求
      var stream =
          await Api().getHunYuan(check['id']!, check['key']!, state.messages.values.toList(), state.modelVersion.value);
      //如果收到了请求，添加一个回答上下文
      var replyTime = DateTime.now();
      state.messages[replyTime] = Message('assistant', '');
      update();
      //接收stream
      stream?.listen((content) {
        if (content != '' && content.contains('data')) {
          HunyuanResponse result = HunyuanResponse.fromJson(jsonDecode(content.split('data: ')[1]));
          state.messages[replyTime]!.content += result.choices!.first.delta!.content!;
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
    var text = getText();
    if (text != '') {
      await getAi(text);
    } else {
      Utils().noticeUtil.showToast('还没有输入问题');
    }
  }

  void changeModel(version) {
    state.modelVersion.value = version;
    state.messages = {};
  }
}
