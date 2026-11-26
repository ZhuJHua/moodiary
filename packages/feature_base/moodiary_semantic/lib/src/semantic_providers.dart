import 'dart:async';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'embed_index_service.dart';
import 'embed_queue_watcher.dart';

part 'semantic_providers.g.dart';

@Riverpod(keepAlive: true)
EmbedIndexService embedIndexService(Ref ref) => EmbedIndexService(
  ref.watch(moodiaryDatabaseProvider),
  ref.watch(semanticEmbedderProvider),
  ref.watch(openDiaryRegistryProvider),
);

@Riverpod(keepAlive: true)
EmbedQueueWatcher embedQueueWatcher(Ref ref) {
  final watcher = EmbedQueueWatcher(
    ref.watch(diaryRepositoryProvider),
    ref.watch(embedIndexServiceProvider),
    ref.watch(openDiaryRegistryProvider),
  );
  ref.onDispose(() => unawaited(watcher.dispose()));
  return watcher;
}
