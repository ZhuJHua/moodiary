import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary/feature/diary/application/diary_controller.dart';
import 'package:moodiary/feature/edit/data/geo_repository.dart';
import 'package:moodiary/feature/edit/data/weather_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'edit_controller.g.dart';

enum DraftSaveResult { saved, failed }

/// 编辑页状态机。`changeXxx` 仅改本地 `state`；落库统一走 [autoSave]（新建 insert、
/// 其余 update）。无手动保存、无草稿概念——创建即落盘。
@riverpod
class EditController extends _$EditController {
  DiaryRepository get _repository => DiaryRepository.get();

  /// 是否已落库：false → 首次保存走 insert，之后 update。
  bool _persisted = false;

  /// 搜索/链接索引已反映（或已入队）的 contentText 快照。打开时 = 当前内容（索引此刻正确）；
  /// 自动保存时与之比较：相同 → skip（仅元数据变，免重索引）；不同 → defer 入队。
  String? _indexedContent;

  /// 最近一次有效 state 快照。dispose 后异步收尾时 provider 已销毁，读
  /// `state`/`ref` 会抛 "Cannot use Ref after dispose"；落库/清理统一走此缓存
  /// （[DiaryRepository] 是 get_it 单例，可安全调用），写回 `state` 仍由
  /// `ref.mounted` 守卫。
  Diary? _latest;

  @override
  FutureOr<Diary> build(String? diaryId, {DiaryType? defaultType}) async {
    final diary = await ref.watch(
      getDiaryProvider(id: diaryId, defaultType: defaultType).future,
    );
    if (diary == null) throw Exception('Diary not found: $diaryId');
    // 新建（创建即落盘）带真实 id 打开，有 id 即已落库；空 id 兜底走首次 insert。
    _persisted = !(diaryId == null || diaryId.isEmpty);
    _latest = diary;
    _indexedContent = diary.contentText;
    listenSelf((_, next) {
      final value = next.value;
      if (value != null) _latest = value;
    });
    return diary;
  }

  void changeDate(DateTime date) {
    state = state.whenData((current) {
      final t = current.time;
      return current.copyWith(
        time: DateTime(
          date.year,
          date.month,
          date.day,
          t.hour,
          t.minute,
          t.second,
          t.millisecond,
          t.microsecond,
        ),
      );
    });
  }

  void changeTime(TimeOfDay time) {
    state = state.whenData((current) {
      final t = current.time;
      return current.copyWith(
        time: DateTime(t.year, t.month, t.day, time.hour, time.minute),
      );
    });
  }

  void changeTitle(String title) {
    state = state.whenData((current) => current.copyWith(title: title));
  }

  /// 同步 `content` 与纯文本镜像 `contentText`（搜索/字数用）。Markdown 传剥离语法
  /// 后的纯文本，richText 传 Delta 解析出的纯文本；未显式传时由 [content] 兜底。
  void changeContent(String content, {String? contentText}) {
    state = state.whenData(
      (current) => current.copyWith(
        content: content,
        contentText: contentText ?? content,
      ),
    );
  }

  /// 仅新建场景调用；已落库日记 type 不应被覆盖，调用方需自行判断。
  void changeType(DiaryType type) {
    state = state.whenData((current) => current.copyWith(type: type.value));
  }

  void changeMood(double mood) {
    state = state.whenData((current) => current.copyWith(mood: mood));
  }

  void changeCategory(String? categoryId) {
    state = state.whenData(
      (current) => current.copyWith(categoryId: categoryId),
    );
  }

  void changeTags(List<String> tags) {
    state = state.whenData((current) => current.copyWith(tags: tags));
  }

  void changePosition(List<String> position) {
    state = state.whenData((current) => current.copyWith(position: position));
  }

  void changeWeather(List<String> weather) {
    state = state.whenData((current) => current.copyWith(weather: weather));
  }

  Future<List<String>?> fetchPosition(BuildContext context) async {
    try {
      final result = await GeoRepository.get().getGeo(context);
      if (result == null || result.length < 2) return null;
      changePosition(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> fetchWeather(BuildContext context) async {
    final current = state.value;
    if (current == null || current.position.length < 2) {
      final pos = await fetchPosition(context);
      if (pos == null || !context.mounted) return null;
    }
    final latest = state.value;
    if (latest == null || latest.position.length < 2) return null;
    final lat = double.tryParse(latest.position[0]);
    final lng = double.tryParse(latest.position[1]);
    if (lat == null || lng == null) return null;
    try {
      final result = await WeatherRepository.get().getWeather(
        context: context,
        position: LatLng(lat, lng),
      );
      if (result == null) return null;
      changeWeather(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 原地自动保存：新建（无 id 兜底）走 insert，其余 update。抽取媒体名、刷新
  /// lastModified，不弹 toast、不导航——供统一编辑页的防抖自动保存调用。
  Future<DraftSaveResult> autoSave() async {
    final current = _latest;
    if (current == null) return DraftSaveResult.saved;
    final media = DiaryContentUtil.extractMedia(current);
    final next = current.copyWith(
      lastModified: DateTime.timestamp(),
      imageName: media.images,
      videoName: media.videos,
      audioName: media.audios,
    );
    // 内容未变（仅元数据/媒体）→ skip：倒排索引仍有效，连入队都免；内容变了 → defer：
    // 只写行 + 入队，分词/倒排推迟到关闭/启动排空。新建首存走 insert（inline 立即建索引）。
    final indexMode = next.contentText == _indexedContent
        ? IndexMode.skip
        : IndexMode.defer;
    try {
      if (_persisted) {
        await _repository.updateADiary(newDiary: next, index: indexMode);
      } else {
        await _repository.insertADiary(next);
        _persisted = true;
      }
      _indexedContent = next.contentText;
      _latest = next;
      // dispose 后 notifier 已销毁，set state 会抛 "use notifier after dispose"。
      if (ref.mounted) {
        state = AsyncValue.data(next);
      }
      return DraftSaveResult.saved;
    } catch (_) {
      return DraftSaveResult.failed;
    }
  }
}
