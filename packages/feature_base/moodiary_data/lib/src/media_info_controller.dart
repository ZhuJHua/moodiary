import 'dart:async';

import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'media_info_repository.dart';
import 'repository_providers.dart';

part 'media_info_controller.g.dart';

/// 把单条 [MediaInfoEvent] 原地并入映射（fileName → MediaInfo）。
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

/// 订阅 [MediaInfoRepository.mediaInfoEvents]，按事件原地增量更新，无需重查库。
/// 以 fileName 为键——消费方（媒体库 / 播放页）都按文件名点查。
@riverpod
class MediaInfoController extends _$MediaInfoController {
  MediaInfoRepository get _repository => ref.read(mediaInfoRepositoryProvider);

  // 首次加载期间事件无处可并，标记后补一次重查（同 LoadMoreMixin.markMissedEvent）。
  bool _missedEvent = false;

  @override
  FutureOr<Map<String, MediaInfo>> build() async {
    final sub = _repository.mediaInfoEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    var either = await _repository.getAllMediaInfos().run();
    if (_missedEvent) {
      _missedEvent = false;
      either = await _repository.getAllMediaInfos().run();
    }
    final list = either.getOrElse((_) => <MediaInfo>[]);
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
    final either = await _repository.insertAMediaInfo(mediaInfo).run();
    return either.isRight();
  }

  /// 删除元数据行（行硬删 + 同步墓碑），清理孤儿媒体时联动调用。
  Future<bool> deleteMediaInfo(String fileName) async {
    final either = await _repository.deleteAMediaInfo(fileName).run();
    return either.getOrElse((_) => false);
  }
}

@riverpod
MediaInfo? mediaInfoByFileName(Ref ref, String fileName) {
  final map = ref.watch(mediaInfoControllerProvider).value;
  return map?[fileName];
}
