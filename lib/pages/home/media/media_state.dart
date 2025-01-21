import 'package:moodiary/common/values/media_type.dart';
import 'package:refreshed/refreshed.dart';

class MediaState {
  late Rx<MediaType> mediaType = MediaType.image.obs;

  Map<DateTime, List<String>> datetimeMediaMap = {};
  List<DateTime> dateTimeList = [];

  bool isFetching = true;

  bool isCleaning = false;

  MediaState();
}
