import 'dart:io';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_controller.g.dart';

/// 媒体库分页数据源：按 [MediaType] 加载含该类型媒体的在册日记（时间倒序）。
/// 每类一个 family 实例，各自维护 offset / noMore，互不干扰。展示用的按日期分组
/// 由纯函数 [buildMediaGroup] 派生，不落 state。
///
/// 订阅 [DiaryRepository.diaryEvents] 按事件原地增量更新（复用 [applyDiaryEvent]），
/// 使新增 / 编辑 / 删除日记后媒体库即时刷新，无需重查库。
@riverpod
class MediaDiaries extends _$MediaDiaries with LoadMoreMixin<Diary> {
  @override
  FutureOr<List<Diary>> build({required MediaType type}) async {
    final sub = ref
        .read(diaryRepositoryProvider)
        .diaryEvents
        .listen(_applyChange);
    ref.onDispose(sub.cancel);
    return init();
  }

  @override
  Future<Iterable<Diary>?> load({required int limit, required int offset}) {
    return ref
        .read(diaryRepositoryProvider)
        .getMediaSourceDiaries(type: type, offset: offset, limit: limit);
  }

  bool _hasMedia(Diary d) => switch (type) {
    .image => d.imageName.isNotEmpty,
    .audio => d.audioName.isNotEmpty,
    .video => d.videoName.isNotEmpty,
  };

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) {
      markMissedEvent();
      return;
    }
    state = .data(
      applyDiaryEvent(
        list,
        event,
        belongs: (d) => d.show && _hasMedia(d),
        compare: diarySortComparator(.timeDesc),
        mayHaveMore: !noMore,
      ),
    );
  }
}

/// 把日记列表（时间倒序）按「年月日」零点聚合为分组。跨分页边界的同一天会并入同
/// 一组（putIfAbsent 只首次登记日期、后续追加），日期顺序沿用时间倒序。
MediaGroup buildMediaGroup(List<Diary> diaries, MediaType type) {
  final map = <DateTime, List<String>>{};
  final order = <DateTime>[];
  for (final d in diaries) {
    final names = switch (type) {
      .image => d.imageName,
      .audio => d.audioName,
      .video => d.videoName,
    };
    if (names.isEmpty) continue;
    final t = d.time.toLocal();
    final key = DateTime(t.year, t.month, t.day);
    map
        .putIfAbsent(key, () {
          order.add(key);
          return <String>[];
        })
        .addAll(names);
  }
  return MediaGroup(dates: order, groups: map);
}

class MediaGroup {
  final List<DateTime> dates;
  final Map<DateTime, List<String>> groups;

  const MediaGroup({required this.dates, required this.groups});

  bool get isEmpty => dates.isEmpty;
}

/// 媒体清理：找出 / 删除未被任何日记引用的孤儿媒体文件。[scan] 只扫描不删除；
/// [clean] 只删文件——刷新（失效 [mediaDiariesProvider]）由调用方用自身有效 ref 触发，
/// 因本 controller 是 autoDispose，其 ref 会在确认弹窗 await 期间被回收。
@riverpod
class MediaCleanupController extends _$MediaCleanupController {
  @override
  void build() {}

  // 本类刻意用静态 `XxxRepository.get()` 而非 ref.read(xxxRepositoryProvider)：
  // autoDispose 下 ref 在确认弹窗 await 期间被回收，dispose 后碰 ref 会抛。
  Future<MediaCleanupReport> scan() async {
    final used = await DiaryRepository.get().collectReferencedMedia();
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
    final used = await DiaryRepository.get().collectReferencedMedia();
    final referenced = {...used.images, ...used.audios, ...used.videos};
    final rows = await MediaInfoRepository.get().getAllMediaInfos().run();
    for (final row in rows.getOrElse((_) => const [])) {
      if (referenced.contains(row.fileName)) continue;
      final file = File(AppFiles.getRealPath(row.mediaType, row.fileName));
      if (!await file.exists()) {
        await MediaInfoRepository.get().deleteAMediaInfo(row.fileName).run();
      }
    }
  }
}
