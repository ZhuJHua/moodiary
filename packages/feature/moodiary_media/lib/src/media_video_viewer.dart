import 'package:moodiary_components/moodiary_components.dart';

/// 媒体库 → 视频播放页。路径解析、封面比例预读、锁方向编排全在
/// [MVideoPlayerPage.showByName]（与正文交接那条路共用同一份），这里只留调用点。
class MediaVideoViewer {
  const MediaVideoViewer._();

  static Future<void> show(BuildContext context, {required String name}) =>
      MVideoPlayerPage.showByName(context, name: name);
}
