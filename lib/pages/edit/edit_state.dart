import 'package:cross_file/cross_file.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';

class EditState {
  //当前天气
  late List<String> currentWeather;

  //标题
  String? title;

  //内容
  late String content;

  //媒体文件名称
  late List<String> imageNameList = [];
  late List<String> videoNameList = [];
  late List<String> videoThumbnailNameList = [];
  late List<String> audioNameList = [];

  //媒体文件内容，音频不需要
  late List<XFile> imageFileList = [];
  late List<XFile> videoFileList = [];
  late List<XFile> videoThumbnailFileList = [];

  // 标签
  late List<String> tagList;

  String? categoryId;

  //日记的日期
  late DateTime currentDateTime;

  //编辑还是新增
  late bool isNew;

  //编辑的原始对象
  late Diary? oldDiary;

  late RxInt tabIndex;

  //拷贝一份第一次打开时的时间
  late DateTime oldDateTime;
  late DateTime? oldTime;

  late RxDouble currentMoodRate;
  late bool isProcessing;

  late String categoryName;
  late KeyboardState keyboardState;

  late RxInt totalCount;

  EditState() {
    totalCount = 0.obs;
    oldTime = null;
    categoryId = null;
    tabIndex = 0.obs;
    categoryName = '';
    //默认为中性心情
    currentMoodRate = 0.5.obs;
    content = '';
    isProcessing = false;
    tagList = [];
    currentWeather = [];
    oldDiary = null;
    isNew = false;
    //默认值为当天
    currentDateTime = DateTime.now();
    keyboardState = KeyboardState.closed;
    oldDateTime = currentDateTime;

    ///Initialize variables
  }
}
