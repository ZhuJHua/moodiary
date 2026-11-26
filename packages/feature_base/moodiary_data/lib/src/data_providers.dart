import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'backup_archive.dart';
import 'category_repository.dart';
import 'database_provider.dart';
import 'diary_repository.dart';
import 'font_repository.dart';
import 'mood_insights_repository.dart';
import 'open_diary_registry.dart';
import 'place_repository.dart';
import 'tag_repository.dart';
import 'tombstone_repository.dart';

part 'data_providers.g.dart';

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  final repository = DiaryRepository(ref.watch(moodiaryDatabaseProvider));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  final repository = CategoryRepository(ref.watch(moodiaryDatabaseProvider));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) {
  final repository = TagRepository(ref.watch(moodiaryDatabaseProvider));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
PlaceRepository placeRepository(Ref ref) {
  final repository = PlaceRepository(
    ref.watch(moodiaryDatabaseProvider),
    ref.watch(diaryRepositoryProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
FontRepository fontRepository(Ref ref) =>
    FontRepository(ref.watch(moodiaryDatabaseProvider));

@Riverpod(keepAlive: true)
MoodInsightsRepository moodInsightsRepository(Ref ref) =>
    MoodInsightsRepository(ref.watch(moodiaryDatabaseProvider));

@Riverpod(keepAlive: true)
TombstoneRepository tombstoneRepository(Ref ref) =>
    TombstoneRepository(ref.watch(moodiaryDatabaseProvider));

@Riverpod(keepAlive: true)
OpenDiaryRegistry openDiaryRegistry(Ref ref) {
  final registry = OpenDiaryRegistry();
  ref.onDispose(() => unawaited(registry.dispose()));
  return registry;
}

@Riverpod(keepAlive: true)
IBackupArchive backupArchive(Ref ref) =>
    throw UnimplementedError('backupArchiveProvider must be overridden');
