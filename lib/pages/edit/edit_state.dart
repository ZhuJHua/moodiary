import 'package:cross_file/cross_file.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';

class EditState {
  // 当前编辑的日记对象
  late Diary currentDiary;

  List<XFile> imageFileList = [];
  List<XFile> videoFileList = [];
  List<XFile> audioFileList = [];
  List<XFile> videoThumbnailFileList = [];

  List<String> audioNameList=[];
  // 分类名称
  String categoryName = '';

  //编辑还是新增
  bool isNew = true;

  int tabIndex = 0;

  bool isProcessing = false;

  KeyboardState keyboardState = KeyboardState.closed;

  int totalCount = 0;

  EditState();
}
