import 'package:media_kit/media_kit.dart';
import 'package:refreshed/refreshed.dart';

class VideoState {
  //视频路径
  late List<String> videoPathList;

  late Playable playable;

  //当前位置
  late Rx<int> videoIndex;

  VideoState();
}
