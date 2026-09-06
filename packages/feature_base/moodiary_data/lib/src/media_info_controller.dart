import 'dart:async';

import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'media_info_repository.dart';

part 'media_info_controller.g.dart';

Map<String, MediaInfo> _applyEvent(
  Map<String, MediaInfo> map,
  MediaInfoEvent event,
) {
  switch (event) {
    case MediaInfoDeleted(:final fileName):
      if (!map.containsKey(fileName)) return map;
      return {...map}..remove(fileName);
    case MediaInfoUpserted(:final mediaInfo):
      return {...map, mediaInfo.fileName: mediaInfo};
  }
}

@riverpod
class MediaInfoController extends _$MediaInfoController {
  late final _repository = getIt<MediaInfoRepository>();

  bool _missedEvent = false;

  @override
  FutureOr<Map<String, MediaInfo>> build() async {
    final sub = _repository.mediaInfoEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var list = await _repository.getAllMediaInfos();
    for (var i = 0; _missedEvent && i < 3; i++) {
      _missedEvent = false;
      list = await _repository.getAllMediaInfos();
    }
    return {for (final info in list) info.fileName: info};
  }

  void _applyChange(MediaInfoEvent event) {
    final map = state.value;
    if (map == null) {
      _missedEvent = true;
      return;
    }
    state = .data(_applyEvent(map, event));
  }

  Future<bool> upsertMediaInfo(MediaInfo mediaInfo) async {
    try {
      await _repository.insertAMediaInfo(mediaInfo);
      return true;
    } catch (e, s) {
      logger.e('upsert media info failed', error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> deleteMediaInfo(String fileName) async {
    try {
      return await _repository.deleteAMediaInfo(fileName);
    } catch (e, s) {
      logger.e('delete media info failed', error: e, stackTrace: s);
      return false;
    }
  }
}

@riverpod
MediaInfo? mediaInfoByFileName(Ref ref, String fileName) {
  final map = ref.watch(mediaInfoControllerProvider).value;
  return map?[fileName];
}
