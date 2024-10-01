import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';

class MediaState {
  late Rx<MediaType> mediaType;

  late RxList<String> filePath;

  late RxBool isCleaning;

  MediaState() {
    mediaType = MediaType.image.obs;
    filePath = <String>[].obs;
    isCleaning = false.obs;

    ///Initialize variables
  }
}
