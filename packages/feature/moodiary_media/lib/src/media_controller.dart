import 'dart:io';

import 'package:moodiary_content/moodiary_content.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_controller.g.dart';

@riverpod
class MediaItems extends _$MediaItems
    with LoadMoreMixin<MediaItem, PagedList<MediaItem>> {
  @override
  int get pageSize => 60;

  @override
  FutureOr<PagedList<MediaItem>> build({required MediaType type}) {
    final sub = ref
        .watch(diaryRepositoryProvider)
        .diaryEvents
        .listen(_applyChange);
    ref.onDispose(sub.cancel);
    return init();
  }

  @override
  PagedList<MediaItem> buildPageState({
    required List<MediaItem> items,
    required bool hasMore,
    required bool isLoadingMore,
    Object? loadMoreError,
  }) => PagedList(
    items: items,
    hasMore: hasMore,
    isLoadingMore: isLoadingMore,
    loadMoreError: loadMoreError,
  );

  @override
  Future<Iterable<MediaItem>?> load({required int limit, required int offset}) {
    return ref
        .read(diaryRepositoryProvider)
        .getMediaItems(type: type, offset: offset, limit: limit);
  }

  List<String> _namesOf(Diary d) => switch (type) {
    .image => d.imageName,
    .audio => d.audioName,
    .video => d.videoName,
    .file => d.fileName,
  };

  Future<void> rename(String fileName, String name) async {
    final operationRef = ref;
    try {
      await ref.read(diaryRepositoryProvider).renameMedia(type, fileName, name);
    } catch (e, s) {
      if (!operationRef.mounted) return;
      logger.e('rename media failed: $fileName', error: e, stackTrace: s);
    }
  }

  void _applyChange(DiaryEvent event) {
    final page = state.value;
    if (page == null || state.hasError || state.isReloading || isRefreshing) {
      markMissedEvent();
      return;
    }
    final list = page.items;
    markPrefixMutated();
    void update(List<MediaItem> items) =>
        state = .data(page.copyWith(items: items));
    switch (event) {
      case DiaryDeleted(:final id):
        final without = list.where((m) => m.diaryId != id).toList();
        if (without.length != list.length) update(without);
      case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
        final without = list.where((m) => m.diaryId != diary.id).toList();
        final removed = without.length != list.length;
        final names = diary.show ? _namesOf(diary) : const <String>[];
        if (names.isEmpty) {
          if (removed) update(without);
          return;
        }
        final content = diary.type == DiaryType.tiptap.value
            ? TiptapContent.parse(diary.content)
            : null;
        final fresh = [
          for (final name in names)
            MediaItem(
              fileName: name,
              name: content?.mediaNames[name],
              mime: type == .audio || type == .file
                  ? content?.mediaMimes[name]
                  : null,
              diaryId: diary.id,
              time: diary.time,
            ),
        ];
        if (page.hasMore &&
            without.isNotEmpty &&
            MediaItem.compare(fresh.first, without.last) > 0) {
          if (removed) update(without);
          return;
        }
        var at = without.length;
        for (var i = 0; i < without.length; i++) {
          if (MediaItem.compare(fresh.first, without[i]) < 0) {
            at = i;
            break;
          }
        }
        update([...without.sublist(0, at), ...fresh, ...without.sublist(at)]);
    }
  }
}

// 读不出（文件还在同步下载）时不留缓存，下次显示再读
@riverpod
Future<Duration?> audioDuration(Ref ref, String fileName) async {
  final duration = await probeAudioDuration(
    AppFiles.getRealPath('audio', fileName),
  );
  if (duration != null && ref.mounted) ref.keepAlive();
  return duration;
}

@riverpod
Future<int?> attachmentSize(
  Ref ref,
  String fileName, {
  bool audio = false,
}) async {
  try {
    final file = audio
        ? File(AppFiles.getRealPath('audio', fileName))
        : AttachmentLauncher.localFile(fileName);
    if (file == null) return null;
    final size = await file.length();
    if (ref.mounted) ref.keepAlive();
    return size;
  } on FileSystemException {
    return null;
  }
}
