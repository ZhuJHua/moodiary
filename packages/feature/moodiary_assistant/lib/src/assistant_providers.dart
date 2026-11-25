import 'dart:async';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'data/assistant.dart';
import 'data/assistant_tool_definitions.dart';
import 'data/chat_repository.dart';
import 'data/impl/rig_assistant.dart';
import 'data/llm_preset_repository.dart';
import 'data/llm_provider_repository.dart';
import 'data/memory_repository.dart';
import 'data/model_catalog_repository.dart';

part 'assistant_providers.g.dart';

@Riverpod(keepAlive: true)
AssistantService assistantService(Ref ref) =>
    RigAssistantService(assistantToolContext(ref));

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  final repository = ChatRepository(ref.watch(moodiaryDatabaseProvider));
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
LlmProviderRepository llmProviderRepository(Ref ref) {
  final repository = LlmProviderRepository(
    ref.watch(moodiaryDatabaseProvider),
    ref.watch(secureKvStorageProvider),
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
}

@Riverpod(keepAlive: true)
LlmPresetRepository llmPresetRepository(Ref ref) =>
    LlmPresetRepository(ref.watch(httpClientProvider));

@Riverpod(keepAlive: true)
ModelCatalogRepository modelCatalogRepository(Ref ref) =>
    ModelCatalogRepository(ref.watch(httpClientProvider));

@Riverpod(keepAlive: true)
MemoryRepository memoryRepository(Ref ref) =>
    MemoryRepository(ref.watch(moodiaryDatabaseProvider));
