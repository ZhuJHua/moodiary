import 'package:latlong2/latlong.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/src/data/geo_repository.dart';
import 'package:moodiary_editor/src/data/weather_repository.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../editor_providers.dart';

part 'edit_controller.g.dart';

enum DraftSaveResult { saved, failed }

typedef PlaceResult = ({Place? place, GeoFailure? failure});

@riverpod
class EditController extends _$EditController {
  bool _persisted = false;

  bool _wasNewDraft = false;

  Diary? _latest;

  Diary? _saved;

  Future<DraftSaveResult>? _inFlight;

  @override
  FutureOr<Diary> build(
    String? diaryId, {
    DiaryType? defaultType,
    String? defaultCategoryId,
  }) async {
    final operationRef = ref;
    final repository = ref.watch(diaryRepositoryProvider);
    _persisted = !(diaryId == null || diaryId.isEmpty);
    _wasNewDraft = !_persisted;
    final Diary diary;
    if (_persisted) {
      final stored = await repository.getDiaryByBusinessId(diaryId!);
      if (stored == null) throw StateError('Diary not found: $diaryId');
      diary = stored;
    } else {
      if (defaultType == null) {
        throw ArgumentError('新建空白日记必须显式提供 defaultType（id 为空时）');
      }
      diary = Diary.empty(type: defaultType)
          .copyWith(categoryId: defaultCategoryId);
    }
    if (!operationRef.mounted) return diary;
    _latest = diary;
    _saved = diary;
    final sub = repository.diaryEvents.listen((event) {
      switch (event) {
        // 同步拉取用 upsert 覆盖已有日记，发的是 DiaryCreated
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          if (diary.id != _latest?.id ||
              _inFlight != null ||
              !identical(_latest, _saved)) {
            return;
          }
          _latest = diary;
          _saved = diary;
          state = .data(diary);
        case DiaryDeleted(:final id):
          if (id == _latest?.id) {
            state = .error(
              StateError('Diary not found: $id'),
              StackTrace.current,
            );
          }
      }
    });
    ref.onDispose(sub.cancel);
    listenSelf((_, next) {
      final value = next.value;
      if (value != null) _latest = value;
    });
    return diary;
  }

  // time 是绝对时刻（新建为 UTC、库读为本地），取墙钟分量前必须 toLocal。
  void changeDate(DateTime date) {
    state = state.whenData((current) {
      final t = current.time.toLocal();
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
      final t = current.time.toLocal();
      return current.copyWith(
        time: DateTime(t.year, t.month, t.day, time.hour, time.minute),
      );
    });
  }

  void changeTitle(String title) {
    state = state.whenData((current) => current.copyWith(title: title));
  }

  void changeContent(String content, {String? contentText}) {
    state = state.whenData(
      (current) => current.copyWith(
        content: content,
        contentText: contentText ?? content,
      ),
    );
  }

  void changeType(DiaryType type) {
    state = state.whenData((current) => current.copyWith(type: type.value));
  }

  void changeMood(DiaryMood? mood) {
    state = state.whenData((current) => current.copyWith(mood: mood));
  }

  void changeCategory(String? categoryId) {
    state = state.whenData(
      (current) => current.copyWith(categoryId: categoryId),
    );
  }

  void changeTags(List<String> tagIds) {
    state = state.whenData((current) => current.copyWith(tagIds: tagIds));
  }

  void changePlace(String? placeId) {
    state = state.whenData((current) => current.copyWith(placeId: placeId));
  }

  void changeWeather(DiaryWeather? weather) {
    state = state.whenData((current) => current.copyWith(weather: weather));
  }

  Future<CoordinatesResult> locate() =>
      ref.read(geoRepositoryProvider).currentCoordinates();

  Future<PlaceResult> fetchPosition(
    BuildContext context, {
    LatLng? coords,
    bool onlyIfUnset = false,
  }) async {
    final operationRef = ref;
    try {
      final geo = await operationRef
          .read(geoRepositoryProvider)
          .getGeo(context, coords: coords);
      if (!operationRef.mounted) return (place: null, failure: null);
      final name = geo.name;
      final at = geo.coords;
      if (name == null || at == null) {
        return (place: null, failure: geo.failure);
      }
      final places = operationRef.read(placeRepositoryProvider);
      var place = await places.getPlaceById(Place.idForName(name));
      if (!operationRef.mounted) return (place: null, failure: null);
      place ??= await places.getPlaceByName(name);
      if (!operationRef.mounted) return (place: null, failure: null);
      if (place == null) {
        place = Place.forName(
          name,
          latitude: at.latitude,
          longitude: at.longitude,
        );
        await places.insertAPlace(place);
      }
      if (!operationRef.mounted) return (place: place, failure: null);
      if (!onlyIfUnset || state.value?.placeId == null) changePlace(place.id);
      return (place: place, failure: null);
    } catch (_) {
      return (place: null, failure: GeoFailure.lookupFailed);
    }
  }

  Future<WeatherResult> fetchWeather(
    BuildContext context, {
    LatLng? coords,
    bool onlyIfUnset = false,
  }) async {
    final operationRef = ref;
    try {
      var at = coords;
      if (at == null) {
        final located = await operationRef
            .read(geoRepositoryProvider)
            .currentCoordinates();
        at = located.coords;
        if (at == null) return (weather: null, failure: located.failure);
      }
      if (!operationRef.mounted || !context.mounted) {
        return (weather: null, failure: GeoFailure.lookupFailed);
      }
      final result = await operationRef
          .read(weatherRepositoryProvider)
          .getWeather(context: context, coords: at);
      if (!operationRef.mounted) return result;
      final weather = result.weather;
      if (weather != null && (!onlyIfUnset || state.value?.weather == null)) {
        changeWeather(weather);
      }
      return result;
    } catch (_) {
      return (weather: null, failure: GeoFailure.lookupFailed);
    }
  }

  Future<DraftSaveResult> autoSave() async {
    final operationRef = ref;
    while (_inFlight != null) {
      await _inFlight;
      if (!operationRef.mounted) return .failed;
    }
    final repository = operationRef.read(diaryRepositoryProvider);
    final keepAlive = operationRef.keepAlive();
    final future = _doAutoSave(operationRef, repository);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
      keepAlive.close();
    }
  }

  Future<DraftSaveResult> _doAutoSave(
    Ref operationRef,
    DiaryRepository repository,
  ) async {
    while (true) {
      final current = _latest;
      if (current == null) return .saved;
      if (_persisted && identical(current, _saved)) return .saved;
      final derived = withDerivedMedia(current);
      final saved = _saved;
      final rowDirty =
          !_persisted ||
          saved == null ||
          derived.copyWith(lastModified: saved.lastModified) != saved;
      final next = rowDirty ? touched(derived) : saved;
      try {
        if (_wasNewDraft && _isBlank(next)) {
          if (_persisted) {
            await repository.hardDeleteDiary(next.id);
            if (operationRef.mounted) _persisted = false;
          }
        } else if (rowDirty) {
          final indexMode =
              next.contentText == saved?.contentText &&
                  next.title == saved?.title
              ? IndexMode.skip
              : IndexMode.inline;
          if (_persisted) {
            await repository.updateADiary(newDiary: next, index: indexMode);
          } else {
            await repository.insertADiary(next);
            if (operationRef.mounted) _persisted = true;
          }
        }
        if (!operationRef.mounted) {
          return identical(_latest, current) ? .saved : .failed;
        }
        _saved = next;
        // 写入期间有新编辑时，保留最新状态并继续保存。
        if (!identical(_latest, current)) continue;
        _latest = next;
        state = .data(next);
        return .saved;
      } catch (_) {
        return .failed;
      }
    }
  }

  bool _isBlank(Diary d) =>
      d.title.trim().isEmpty &&
      d.contentText.trim().isEmpty &&
      d.imageName.isEmpty &&
      d.audioName.isEmpty &&
      d.videoName.isEmpty &&
      d.fileName.isEmpty;
}
