import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'diary.g.dart';

@collection
class Diary {
  // 业务主键，使用 uuid
  String id = const Uuid().v7();

  // 数据库主键，使用 hash 业务主键
  @Id()
  int get isarId => fastHash(id);

  //分类id
  @Index()
  String? categoryId;

  //标题
  String title = '';

  //原始Delta格式内容
  String content = '';

  //纯文本的内容，用于搜索以及字数统计
  String contentText = '';

  //年月索引
  @Index()
  String get yM => '${time.year.toString()}/${time.month.toString()}';

  //年月日索引
  @Index()
  String get yMd => '${time.year.toString()}/${time.month.toString()}/${time.day.toString()}';

  //日期
  @Index()
  DateTime time = DateTime.now();

  //上次更新的时间，用于增量同步
  DateTime lastModified = DateTime.now();

  //是否显示，用于回收站
  @Index()
  bool show = true;

  //心情指数
  double mood = 0.5;

  //天气
  List<String> weather = [];

  //图片名称
  List<String> imageName = [];

  //音频名称
  List<String> audioName = [];

  //视频名称
  List<String> videoName = [];

  //标签列表
  List<String> tags = [];

  // 位置信息
  List<String> position = [];

  // 类型，富文本还是纯文本，不会为空，延迟加载
  late String type;

  //封面颜色，如果有的话
  int? imageColor;

  //封面比例，如果有的话
  double? aspect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Diary &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isarId == other.isarId &&
          categoryId == other.categoryId &&
          title == other.title &&
          content == other.content &&
          contentText == other.contentText &&
          time == other.time &&
          lastModified == other.lastModified &&
          show == other.show &&
          mood == other.mood &&
          const ListEquality().equals(weather, other.weather) &&
          const ListEquality().equals(imageName, other.imageName) &&
          const ListEquality().equals(audioName, other.audioName) &&
          const ListEquality().equals(videoName, other.videoName) &&
          const ListEquality().equals(tags, other.tags) &&
          const ListEquality().equals(position, other.position) &&
          type == other.type &&
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
        lastModified.hashCode ^
        show.hashCode ^
        mood.hashCode ^
        const ListEquality().hash(weather) ^
        const ListEquality().hash(imageName) ^
        const ListEquality().hash(audioName) ^
        const ListEquality().hash(videoName) ^
        const ListEquality().hash(tags) ^
        const ListEquality().hash(position) ^
        type.hashCode ^
        imageColor.hashCode ^
        aspect.hashCode;
  }

  Diary();

  // 深拷贝方法
  Diary clone() {
    return Diary()
      ..id = id
      ..categoryId = categoryId
      ..title = title
      ..content = content
      ..contentText = contentText
      ..time = DateTime.fromMillisecondsSinceEpoch(time.millisecondsSinceEpoch)
      ..lastModified = DateTime.fromMillisecondsSinceEpoch(lastModified.millisecondsSinceEpoch)
      ..show = show
      ..mood = mood
      ..weather = List<String>.from(weather)
      ..imageName = List<String>.from(imageName)
      ..audioName = List<String>.from(audioName)
      ..videoName = List<String>.from(videoName)
      ..tags = List<String>.from(tags)
      ..position = List<String>.from(position)
      ..type = type
      ..imageColor = imageColor
      ..aspect = aspect;
  }

  // 将 Diary 对象转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'title': title,
      'content': content,
      'contentText': contentText,
      'time': time.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'show': show,
      'mood': mood,
      'weather': weather,
      'imageName': imageName,
      'audioName': audioName,
      'videoName': videoName,
      'tags': tags,
      'position': position,
      'type': type,
      'imageColor': imageColor,
      'aspect': aspect,
    };
  }

  factory Diary.fromJson(Map<String, dynamic> json) {
    return Diary()
      ..id = json['id'] as String
      ..categoryId = json['categoryId'] as String?
      ..title = json['title'] as String
      ..content = json['content'] as String
      ..contentText = json['contentText'] as String
      ..time = DateTime.parse(json['time'] as String)
      ..lastModified = DateTime.parse(json['lastModified'] as String)
      ..show = json['show'] as bool
      ..mood = (json['mood'] as num).toDouble()
      ..weather = List<String>.from(json['weather'] as List)
      ..imageName = List<String>.from(json['imageName'] as List)
      ..audioName = List<String>.from(json['audioName'] as List)
      ..videoName = List<String>.from(json['videoName'] as List)
      ..tags = List<String>.from(json['tags'] as List)
      ..position = List<String>.from(json['position'] as List)
      ..type = json['type'] as String
      ..imageColor = json['imageColor'] as int?
      ..aspect = (json['aspect'] as num?)?.toDouble();
  }
}

int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}
