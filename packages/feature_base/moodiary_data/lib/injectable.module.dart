// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_data/src/category_repository.dart' as _i428;
import 'package:moodiary_data/src/db/database.dart' as _i527;
import 'package:moodiary_data/src/diary_repository.dart' as _i1068;
import 'package:moodiary_data/src/embed_index_service.dart' as _i768;
import 'package:moodiary_data/src/font_repository.dart' as _i377;
import 'package:moodiary_data/src/media_info_repository.dart' as _i297;
import 'package:moodiary_data/src/open_diary_registry.dart' as _i107;
import 'package:moodiary_data/src/sync_pending.dart' as _i931;
import 'package:moodiary_data/src/tombstone_repository.dart' as _i952;
import 'package:moodiary_ml/moodiary_ml.dart' as _i611;

class MoodiaryDataPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.singleton<_i107.OpenDiaryRegistry>(() => _i107.OpenDiaryRegistry());
    gh.singleton<_i931.SyncPendingTracker>(() => _i931.SyncPendingTracker());
    gh.singleton<_i931.SyncDirtyTracker>(() => _i931.SyncDirtyTracker());
    gh.lazySingleton<_i768.EmbedIndexService>(
      () => _i768.EmbedIndexService(
        gh<_i527.MoodiaryDatabase>(),
        gh<_i611.SemanticEmbedder>(),
      ),
    );
    gh.lazySingleton<_i428.CategoryRepository>(
      () => _i428.CategoryRepository(gh<_i527.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i1068.DiaryRepository>(
      () => _i1068.DiaryRepository(gh<_i527.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i377.FontRepository>(
      () => _i377.FontRepository(gh<_i527.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i297.MediaInfoRepository>(
      () => _i297.MediaInfoRepository(gh<_i527.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i952.TombstoneRepository>(
      () => _i952.TombstoneRepository(gh<_i527.MoodiaryDatabase>()),
    );
  }
}
