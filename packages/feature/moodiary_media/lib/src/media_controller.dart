import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_controller.g.dart';

/// 媒体库分页数据源：按 [MediaType] 分页加载**媒体条目**（一页 [pageSize] 个文件，
/// 日记时间倒序）。每类一个 family 实例，各自维护 offset / noMore。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新：一篇日记的变更 = 先摘掉它
/// 已加载的全部条目，再把新条目按序插回（只在已加载窗口内；比窗口末尾还旧且还有下一页
/// 时不插，翻页自然带来）。
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
  };

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
        final fresh = [
          for (final name in names)
            MediaItem(fileName: name, diaryId: diary.id, time: diary.time),
        ];
        // 比已加载窗口末尾还旧且还有下一页：不插，翻页自然带来，插了反而重复。
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

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaItemsProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。
@riverpod
class MediaCleanupController extends _$MediaCleanupController {
  @override
  void build() {}

  Future<MediaCleanupReport> scan() async {
    final used = await getIt<DiaryRepository>().collectReferencedMedia();
    return AppFiles.scanOrphanMedia(
      usedImages: used.images,
      usedAudios: used.audios,
      usedVideos: used.videos,
    );
  }

  Future<void> clean(MediaCleanupReport report) async {
    await AppFiles.deleteOrphanMedia(report);
    // MediaInfo 行对账：只删「无日记引用 + 本机无文件」的悬空行（写墓碑，随同步扩散）。
    // 覆盖两条路径——刚删掉的孤儿音频，以及日记永久删除时文件先没了、孤儿
    // 扫描永远扫不到的悬空行（行否则无任何回收通道）。
    //
    // **被引用的行文件缺失时必须保留**：多设备下「文件还没从远端下载下来」与
    // 「文件已不存在」在本机不可区分（媒体下载失败只记日志、pull 照常推进），
    // 按文件存在性删行会把用户手工起的名字做成墓碑推向全网、永久抹掉——
    // 本表是名字的唯一事实源，media_page 的懒补行防的就是同一类事故。
    final used = await getIt<DiaryRepository>().collectReferencedMedia();
    final referenced = {...used.images, ...used.audios, ...used.videos};
    final rows = await getIt<MediaInfoRepository>().getAllMediaInfos();
    for (final row in rows) {
      if (referenced.contains(row.fileName)) continue;
      final file = File(AppFiles.getRealPath(row.mediaType, row.fileName));
      if (!await file.exists()) {
        await getIt<MediaInfoRepository>().deleteAMediaInfo(row.fileName);
      }
    }
  }
}
