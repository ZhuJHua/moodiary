import 'package:flutter/material.dart';
import 'package:moodiary/common/values/keyboard_state.dart';
import 'package:moodiary/utils/literunner.dart';
import 'package:moodiary/utils/tokenization.dart';
import 'package:refreshed/refreshed.dart';

import 'ask_question_state.dart';

class AskQuestionLogic extends GetxController with WidgetsBindingObserver {
  final AskQuestionState state = AskQuestionState();

  //输入框控制器
  late TextEditingController textEditingController = TextEditingController();

  late ScrollController scrollController = ScrollController();

  //聚焦对象
  late FocusNode focusNode = FocusNode();

  late LiteRunner liteRunner = LiteRunner();

  late FullTokenizer fullTokenizer = FullTokenizer();

  List<double> heightList = [];

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var height = MediaQuery.viewInsetsOf(Get.context!).bottom;
      if (heightList.isNotEmpty && height != heightList.last) {
        if (height > heightList.last &&
            state.keyboardState != KeyboardState.opening) {
          state.keyboardState = KeyboardState.opening;
          //正在打开
        } else if (height < heightList.last &&
            state.keyboardState != KeyboardState.closing) {
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
        toBottom();
        //已经关闭
      }
    });
    super.didChangeMetrics();
  }

  @override
  void onReady() async {
    WidgetsBinding.instance.addObserver(this);
    //await fullTokenizer.init();
    //await liteRunner.initializeInterpreter(state.modelPath, fullTokenizer);
    super.onReady();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    textEditingController.dispose();
    scrollController.dispose();
    focusNode.dispose();
    // 销毁实例
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

    var answer = await liteRunner.ask(content, question);
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
    await scrollController.animateTo(scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100), curve: Curves.linear);
  }

  Future<void> ask(String content) async {
    var text = textEditingController.text;
    if (text.isNotEmpty) {
      //await getAnswer(content, text);
    }
  }
}
