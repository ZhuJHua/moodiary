import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_repository.dart';
import 'embed_index_service.dart';
import 'open_diary_registry.dart';

@lazySingleton
class EmbedQueueWatcher {
  EmbedQueueWatcher(this._diaries, this._index, this._openDiaries);

  final DiaryRepository _diaries;
  final EmbedIndexService _index;
  final OpenDiaryRegistry _openDiaries;

  static const Duration _debounce = Duration(seconds: 10);

  StreamSubscription<DiaryEvent>? _sub;
  StreamSubscription<String>? _editingEndedSub;
  Timer? _timer;

  void start() {
    _sub ??= _diaries.diaryEvents.listen((_) => _scheduleDrain());
    _editingEndedSub ??= _openDiaries.editingEnded.listen(
      (_) => _scheduleDrain(),
    );
  }

  void _scheduleDrain() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_index.drain()));
  }

  @disposeMethod
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    final subCancelled = _sub?.cancel();
    _sub = null;
    final editingEndedSubCancelled = _editingEndedSub?.cancel();
    _editingEndedSub = null;
    await subCancelled;
    await editingEndedSubCancelled;
  }
}
