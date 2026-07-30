import 'package:flutter/widgets.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 媒体库 → 视频播放页。路径解析、封面比例预读、锁方向编排全在
/// [MoodiaryVideoPlayerPage.showByName]（与正文交接那条路共用同一份），这里只留调用点。
class MediaVideoViewer {
  const MediaVideoViewer._();

  static Future<void> show(BuildContext context, {required String name}) =>
      MoodiaryVideoPlayerPage.showByName(context, name: name);
}
