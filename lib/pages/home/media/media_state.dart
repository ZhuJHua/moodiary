import 'package:get/get.dart';
import 'package:mood_diary/common/values/media_type.dart';

class MediaState {
  late Rx<MediaType> mediaType = MediaType.image.obs;

  Map<DateTime, List<String>> datetimeMediaMap = {};
  List<DateTime> dateTimeList = [];

  bool isFetching = true;

  bool isCleaning = false;

  MediaState();
}
