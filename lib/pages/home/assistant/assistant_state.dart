import 'package:mood_diary/common/models/hunyuan.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';
import 'package:refreshed/refreshed.dart';

class AssistantState {
  //对话上下文
  late Map<DateTime, Message> messages;

  //模型版本
  late RxInt modelVersion;

  late KeyboardState keyboardState;

  late int totalToken;

  AssistantState() {
    messages = {};

    modelVersion = 0.obs;
    keyboardState = KeyboardState.closed;

    ///Initialize variables
  }
}
