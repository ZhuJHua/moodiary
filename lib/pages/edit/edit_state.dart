import 'package:cross_file/cross_file.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/diary_type.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';

class EditState {
  // 当前编辑的日记对象
  late Diary currentDiary;

  // 编辑时的原始日记对象
  Diary? originalDiary;

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

  // 总字数
  RxInt totalCount = 0.obs;

  // 已写作时长
  Duration duration = Duration.zero;

  RxString durationString = ''.obs;

  // 是否展示保存动画
  bool isSaving = false;

  // 是否完成初始化
  bool isInit = false;

  // 日记的类型
  late DiaryType type;

  // 自动获取天气
  bool get autoWeather => PrefUtil.getValue<bool>('autoWeather')!;

  // 首行缩进
  bool get firstLineIndent =>
      (PrefUtil.getValue<bool>('firstLineIndent')!) && type == DiaryType.text;

  // 自动分类
  bool get autoCategory => PrefUtil.getValue<bool>('autoCategory')!;

  // 展示写作时长
  bool get showWriteTime => PrefUtil.getValue<bool>('showWritingTime')!;

  // 展示字数统计
  bool get showWordCount => PrefUtil.getValue<bool>('showWordCount')!;

  EditState();
}
