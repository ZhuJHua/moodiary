import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_repository.dart';
import 'embed_index_service.dart';

@lazySingleton
class EmbedQueueWatcher {
  EmbedQueueWatcher(this._diaries, this._index);

  final DiaryRepository _diaries;
  final EmbedIndexService _index;

  static const Duration _debounce = Duration(seconds: 10);

  StreamSubscription<DiaryEvent>? _sub;
  Timer? _timer;

  void start() {
    _sub ??= _diaries.diaryEvents.listen((_) {
      _timer?.cancel();
      _timer = Timer(_debounce, () => unawaited(_index.drain()));
    });
  }

  @disposeMethod
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
  }
}
