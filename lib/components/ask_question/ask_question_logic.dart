import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/components/keyboard_listener/keyboard_listener.dart';
import 'package:moodiary/utils/literunner.dart';
import 'package:moodiary/utils/tokenization.dart';

import 'ask_question_state.dart';

class AskQuestionLogic extends GetxController {
  final AskQuestionState state = AskQuestionState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();

  late LiteRunner liteRunner = LiteRunner();

  late FullTokenizer fullTokenizer = FullTokenizer();

  List<double> heightList = [];

  late final KeyboardObserver keyboardObserver;

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
            toBottom();
            break;
          case KeyboardState.unknown:
            break;
        }
      },
    );
    super.onInit();
  }

  @override
  void onReady() async {
    //await fullTokenizer.init();
    //await liteRunner.initializeInterpreter(state.modelPath, fullTokenizer);
    super.onReady();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    liteRunner.close();
    super.onClose();
  }

  void unFocus() {
    focusNode.unfocus();
  }

  Future<void> getAnswer(String content, String question) async {
    textEditingController.clear();
    unFocus();
    // 添加提问
    state.qaList.add(question);

    final answer = await liteRunner.ask(content, question);
    // 添加回答
    if (answer != null) {
      state.qaList.add(answer);
    } else {
      state.qaList.add('我不知道');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      toBottom();
    });
  }

  Future<void> toBottom() async {
    await scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
    );
  }

  Future<void> ask(String content) async {
    final text = textEditingController.text;
    if (text.isNotEmpty) {
      //await getAnswer(content, text);
    }
  }
}
