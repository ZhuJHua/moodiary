import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
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
    final sub = DiaryRepository.get().diaryEvents.listen(_applyChange);
    ref.onDispose(sub.cancel);
    return init();
  }

  @override
  Future<Iterable<Diary>?> load({required int limit, required int offset}) {
    return DiaryRepository.get().getMediaSourceDiaries(
      type: type,
      offset: offset,
      limit: limit,
    );
  }

  bool _hasMedia(Diary d) => switch (type) {
    MediaType.image => d.imageName.isNotEmpty,
    MediaType.audio => d.audioName.isNotEmpty,
    MediaType.video => d.videoName.isNotEmpty,
  };

  void _applyChange(DiaryEvent event) {
    final list = state.value;
    if (list == null) return;
    state = AsyncValue.data(
      applyDiaryEvent(
        list,
        event,
        belongs: (d) => d.show && !d.deleted && _hasMedia(d),
        compare: diarySortComparator(DiarySort.timeDesc),
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
      MediaType.image => d.imageName,
      MediaType.audio => d.audioName,
      MediaType.video => d.videoName,
    };
    if (names.isEmpty) continue;
    final key = DateTime(d.time.year, d.time.month, d.time.day);
    map.putIfAbsent(key, () {
      order.add(key);
      return <String>[];
    }).addAll(names);
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

  Future<MediaCleanupReport> scan() async {
    final used = await DiaryRepository.get().collectReferencedMedia();
    return FileUtil.scanOrphanMedia(
      usedImages: used.images,
      usedAudios: used.audios,
      usedVideos: used.videos,
    );
  }

  Future<void> clean(MediaCleanupReport report) async {
    await FileUtil.deleteOrphanMedia(report);
  }
}
