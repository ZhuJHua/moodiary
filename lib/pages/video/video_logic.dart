import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit;
import 'package:refreshed/refreshed.dart';

import 'video_state.dart';

class VideoLogic extends GetxController {
  final VideoState state = VideoState();
  late final player = Player();

  late final videoController = media_kit.VideoController(player);

  @override
  void onInit() {
    state.playable = Playlist(
        List.generate(state.videoPathList.length, (index) {
          return Media(state.videoPathList[index]);
        }),
        index: state.videoIndex.value);
    super.onInit();
  }

  @override
  void onReady() async {
    await player.open(state.playable, play: true);
    player.stream.playlist.listen((data) {
      state.videoIndex.value = data.index;
    });
    super.onReady();
  }

  @override
  void onClose() {
    player.dispose();
    super.onClose();
  }

  void play() {}
}
