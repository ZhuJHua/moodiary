import 'dart:async';

import 'package:moodiary_http/moodiary_http.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'embedding_backend.dart';
import 'embedding_engine.dart';
import 'embedding_models.dart';
import 'onnx_embedding_backend.dart';

part 'ml_providers.g.dart';

@Riverpod(keepAlive: true)
EmbeddingModelManager embeddingModelManager(Ref ref) =>
    EmbeddingModelManager(ref.watch(httpClientProvider));

@Riverpod(keepAlive: true)
EmbeddingBackend embeddingBackend(Ref ref) => OnnxEmbeddingBackend();

@Riverpod(keepAlive: true)
SemanticEmbedder semanticEmbedder(Ref ref) {
  final engine = EmbeddingEngine(
    ref.watch(embeddingModelManagerProvider),
    ref.watch(embeddingBackendProvider),
  );
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
}
