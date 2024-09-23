import 'package:collection/collection.dart';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          categoryId == other.categoryId &&
          title == other.title &&
          content == other.content &&
          contentText == other.contentText &&
          time == other.time &&
          show == other.show &&
          mood == other.mood &&
          const ListEquality().equals(weather, other.weather) &&
          const ListEquality().equals(imageName, other.imageName) &&
          const ListEquality().equals(audioName, other.audioName) &&
          const ListEquality().equals(videoName, other.videoName) &&
          const ListEquality().equals(tags, other.tags) &&
          imageColor == other.imageColor &&
          aspect == other.aspect;

  @override
  int get hashCode {
    return id.hashCode ^
        categoryId.hashCode ^
        title.hashCode ^
        content.hashCode ^
        contentText.hashCode ^
        time.hashCode ^
        show.hashCode ^
        mood.hashCode ^
        const ListEquality().hash(weather) ^
        const ListEquality().hash(imageName) ^
        const ListEquality().hash(audioName) ^
        const ListEquality().hash(videoName) ^
        const ListEquality().hash(tags) ^
        imageColor.hashCode ^
        aspect.hashCode;
  }

  @override
  String toString() {
    return 'Diary{id: $id, categoryId: $categoryId, title: $title, content: $content, contentText: $contentText, time: $time, show: $show, mood: $mood, weather: $weather, imageName: $imageName, audioName: $audioName, videoName: $videoName, tags: $tags, imageColor: $imageColor, aspect: $aspect}';
  }
}
