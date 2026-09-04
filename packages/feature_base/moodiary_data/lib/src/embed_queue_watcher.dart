import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moodiary_models/moodiary_models.dart';

import 'diary_repository.dart';
import 'embed_index_service.dart';

/// 写日记（含同步落库）后去抖排空补嵌队列。10s 去抖：编辑器自动保存每次都发
/// DiaryUpdated，停笔后才真正嵌入，避免打字期间反复重嵌同一篇。
///
/// 与 AutoSyncWatcher 同款：容器懒单例、构造器注入；[start] 由组合根在启动维护里
/// 显式调用（模型未激活时 drain 是 no-op，队列自然累积）。
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
