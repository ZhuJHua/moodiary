import 'package:cross_file/cross_file.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';

class EditState {
  // 当前编辑的日记对象
  late Diary currentDiary;

  List<XFile> imageFileList = [];

  List<String> get imagePathList => imageFileList.map((e) => e.path).toList();
  List<XFile> videoFileList = [];

  List<String> get videoPathList => videoFileList.map((e) => e.path).toList();
  List<XFile> audioFileList = [];

  List<String> get audioPathList => audioFileList.map((e) => e.path).toList();

  List<String> audioNameList = [];

  String currentAudioName = '';

  // 分类名称
  String categoryName = '';

  //编辑还是新增
  bool isNew = true;

  int tabIndex = 0;

  bool isProcessing = false;

  KeyboardState keyboardState = KeyboardState.closed;

  // 总字数
  RxInt totalCount = 0.obs;

  // 已写作时长
  Duration duration = Duration.zero;

  RxString durationString = ''.obs;

  // 是否展示保存动画
  bool isSaving = false;

  // 是否完成初始化
  bool isInit = false;

  EditState();
}
