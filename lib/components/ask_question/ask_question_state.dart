import 'package:get/get.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';

class AskQuestionState {
  late String modelPath;

  // 提问回答列表
  late RxList<String> qaList;

  late KeyboardState keyboardState;

  AskQuestionState() {
    modelPath = 'assets/tflite/model_quant.tflite';
    qaList = <String>[].obs;
    keyboardState = KeyboardState.closed;

    ///Initialize variables
  }
}
