import 'package:isar/isar.dart';

part 'diary.g.dart';

@collection
class Diary {
  @Id()
  late String id;

  //分类id
  @Index()
  String? categoryId;

  //标题
  String? title;

  //原始Delta格式内容
  late String content;

  //纯文本的内容，用于搜索以及字数统计
  late String contentText;

  //年月索引
  @Index()
  String get yM => '${time.year.toString()}/${time.month.toString()}';

  //年月日索引
  @Index()
  String get yMd => '${time.year.toString()}/${time.month.toString()}/${time.day.toString()}';

  //日期
  @Index()
  late DateTime time;

  //是否显示，用于回收站
  @Index()
  late bool show;

  //心情指数
  late double mood;

  //天气
  late List<String> weather;

  //图片名称
  late List<String> imageName;

  //音频名称
  late List<String> audioName;

  //视频名称
  late List<String> videoName;

  //标签列表
  late List<String> tags;

  //封面颜色，如果有的话
  int? imageColor;

  //封面比例，如果有的话
  double? aspect;

  Diary({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.content,
    required this.contentText,
    required this.time,
    required this.show,
    required this.mood,
    required this.weather,
    required this.imageName,
    required this.audioName,
    required this.videoName,
    required this.tags,
    required this.imageColor,
    required this.aspect,
  });
}
