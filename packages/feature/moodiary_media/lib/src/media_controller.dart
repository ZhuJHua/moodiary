import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_controller.g.dart';

@riverpod
class MediaItems extends _$MediaItems with LoadMoreMixin<MediaItem> {
  @override
  int get pageSize => 60;

  @override
  FutureOr<List<MediaItem>> build({required MediaType type}) async {
    final sub = getIt<DiaryRepository>().diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    return init();
  }

  @override
  Future<Iterable<MediaItem>?> load({required int limit, required int offset}) {
    return getIt<DiaryRepository>().getMediaItems(
      type: type,
      offset: offset,
      limit: limit,
    );
  }

  List<String> _namesOf(Diary d) => switch (type) {
    .image => d.imageName,
    .audio => d.audioName,
    .video => d.videoName,
    .file => d.fileName,
  };

  Future<void> rename(String fileName, String name) async {
    try {
      await getIt<DiaryRepository>().renameMedia(type, fileName, name);
    } catch (e, s) {
      logger.e('rename media failed: $fileName', error: e, stackTrace: s);
    }
  }

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) {
      markMissedEvent();
      return;
    }
    switch (event) {
      case DiaryDeleted(:final id):
        final without = list.where((m) => m.diaryId != id).toList();
        if (without.length != list.length) state = .data(without);
      case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
        final without = list.where((m) => m.diaryId != diary.id).toList();
        final removed = without.length != list.length;
        final names = diary.show ? _namesOf(diary) : const <String>[];
        if (names.isEmpty) {
          if (removed) state = .data(without);
          return;
        }
        final labels = diary.type == DiaryType.tiptap.value
            ? TiptapContent.parse(diary.content).mediaNames
            : const <String, String>{};
        final fresh = [
          for (final name in names)
            MediaItem(
              fileName: name,
              name: labels[name],
              diaryId: diary.id,
              time: diary.time,
            ),
        ];
        if (!noMore &&
            without.isNotEmpty &&
            MediaItem.compare(fresh.first, without.last) > 0) {
          if (removed) state = .data(without);
          return;
        }
        var at = without.length;
        for (var i = 0; i < without.length; i++) {
          if (MediaItem.compare(fresh.first, without[i]) < 0) {
            at = i;
            break;
          }
        }
        state = .data([
          ...without.sublist(0, at),
          ...fresh,
          ...without.sublist(at),
        ]);
    }
  }
}

// 读不出（文件还在同步下载）时不留缓存，下次显示再读
@riverpod
Future<Duration?> audioDuration(Ref ref, String fileName) async {
  final duration = await probeAudioDuration(
    AppFiles.getRealPath('audio', fileName),
  );
  if (duration != null) ref.keepAlive();
  return duration;
}
