import 'package:mood_diary/common/models/hunyuan.dart';

class AssistantState {
  //对话上下文
  late List<Message> messages;

  //模型版本
  late int modelVersion;

  AssistantState() {
    messages = [];
    modelVersion = 0;

    ///Initialize variables
  }
}
