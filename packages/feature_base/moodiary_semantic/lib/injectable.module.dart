// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_data/moodiary_data.dart' as _i691;
import 'package:moodiary_ml/moodiary_ml.dart' as _i611;
import 'package:moodiary_semantic/src/embed_index_service.dart' as _i427;
import 'package:moodiary_semantic/src/embed_queue_watcher.dart' as _i395;

class MoodiarySemanticPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i427.EmbedIndexService>(
      () => _i427.EmbedIndexService(
        gh<_i691.MoodiaryDatabase>(),
        gh<_i611.SemanticEmbedder>(),
        gh<_i691.OpenDiaryRegistry>(),
      ),
    );
    gh.lazySingleton<_i395.EmbedQueueWatcher>(
      () => _i395.EmbedQueueWatcher(
        gh<_i691.DiaryRepository>(),
        gh<_i427.EmbedIndexService>(),
        gh<_i691.OpenDiaryRegistry>(),
      ),
      dispose: (i) => i.dispose(),
    );
  }
}
