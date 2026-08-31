// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_http/moodiary_http.dart' as _i765;
import 'package:moodiary_ml/src/embedding_backend.dart' as _i172;
import 'package:moodiary_ml/src/embedding_engine.dart' as _i618;
import 'package:moodiary_ml/src/embedding_models.dart' as _i444;

class MoodiaryMlPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final embeddingBackendModule = _$EmbeddingBackendModule();
    gh.lazySingleton<_i172.EmbeddingBackend>(
      () => embeddingBackendModule.backend(),
    );
    gh.lazySingleton<_i444.EmbeddingModelManager>(
      () => _i444.EmbeddingModelManager(gh<_i765.IHttpClient>()),
    );
    gh.lazySingleton<_i618.EmbeddingEngine>(
      () => _i618.EmbeddingEngine(
        gh<_i444.EmbeddingModelManager>(),
        gh<_i172.EmbeddingBackend>(),
      ),
    );
  }
}

class _$EmbeddingBackendModule extends _i618.EmbeddingBackendModule {}
