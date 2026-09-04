// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:injectable/injectable.dart' as _i526;
import 'package:moodiary_assistant/src/data/agent_preset_repository.dart'
    as _i773;
import 'package:moodiary_assistant/src/data/assistant.dart' as _i808;
import 'package:moodiary_assistant/src/data/chat_repository.dart' as _i349;
import 'package:moodiary_assistant/src/data/impl/rig_assistant.dart' as _i192;
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart'
    as _i997;
import 'package:moodiary_assistant/src/data/llm_provider_repository.dart'
    as _i19;
import 'package:moodiary_assistant/src/data/memory_repository.dart' as _i682;
import 'package:moodiary_assistant/src/data/model_catalog_repository.dart'
    as _i803;
import 'package:moodiary_data/moodiary_data.dart' as _i691;
import 'package:moodiary_http/moodiary_http.dart' as _i765;
import 'package:moodiary_storage/moodiary_storage.dart' as _i877;

class MoodiaryAssistantPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i808.AssistantService>(() => _i192.RigAssistantService());
    gh.lazySingleton<_i997.LlmPresetRepository>(
      () => _i997.LlmPresetRepository(gh<_i765.IHttpClient>()),
    );
    gh.lazySingleton<_i803.ModelCatalogRepository>(
      () => _i803.ModelCatalogRepository(gh<_i765.IHttpClient>()),
    );
    gh.lazySingleton<_i19.LlmProviderRepository>(
      () => _i19.LlmProviderRepository(
        gh<_i691.MoodiaryDatabase>(),
        gh<_i877.ISecureKVStorage>(),
      ),
    );
    gh.lazySingleton<_i773.AgentPresetRepository>(
      () => _i773.AgentPresetRepository(gh<_i691.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i349.ChatRepository>(
      () => _i349.ChatRepository(gh<_i691.MoodiaryDatabase>()),
    );
    gh.lazySingleton<_i682.MemoryRepository>(
      () => _i682.MemoryRepository(gh<_i691.MoodiaryDatabase>()),
    );
  }
}
