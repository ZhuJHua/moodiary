import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';

class MediaState {
  late Rx<MediaType> mediaType;

  late RxList<String> filePath;

  late RxMap<String, String> videoThumbnailMap;

  bool isCleaning = false;

  MediaState() {
    mediaType = MediaType.image.obs;
    filePath = <String>[].obs;
    videoThumbnailMap = <String, String>{}.obs;

    ///Initialize variables
  }
}
