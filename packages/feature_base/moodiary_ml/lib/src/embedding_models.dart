import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'onnx_embedding_backend.dart';

class EmbeddingModelSpec {
  final String id;

  final String displayName;

  final int dim;

  final String modelHfPath;

  final String tokenizerHfPath;

  final int sizeBytes;

  final String queryPrefix;

  final String passagePrefix;

  final int contextSize;

  final String padToken;

  const EmbeddingModelSpec({
    required this.id,
    required this.displayName,
    required this.dim,
    required this.modelHfPath,
    required this.tokenizerHfPath,
    required this.sizeBytes,
    required this.queryPrefix,
    this.passagePrefix = '',
    this.contextSize = 512,
    this.padToken = '<|endoftext|>',
  });

  String get modelFileName => '$id.onnx';

  String get tokenizerFileName => '$id.tokenizer.json';
}

const embeddingModelCatalog = <EmbeddingModelSpec>[
  EmbeddingModelSpec(
    id: 'qwen3-embedding-0.6b-int8',
    displayName: 'Qwen3-Embedding 0.6B',
    dim: 1024,
    modelHfPath: 'onnx-community/Qwen3-Embedding-0.6B-ONNX/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath:
        'onnx-community/Qwen3-Embedding-0.6B-ONNX/resolve/main/tokenizer.json',
    sizeBytes: 624951296, // 596 MB
    // query 侧带 Instruct 前缀，"Query:" 后不加空格；passage 侧裸文本。
    queryPrefix: 'Instruct: Given a diary search query, retrieve relevant diary passages\nQuery:',
  ),
];

@LazySingleton()
class EmbeddingModelManager {
  final IHttpClient _http;

  EmbeddingModelManager(this._http);

  static EmbeddingModelSpec? byId(String id) {
    for (final spec in embeddingModelCatalog) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  EmbeddingModelSpec? get active =>
      byId(MoodiaryKVs.embeddingModelId.get() ?? '');

  String modelPathOf(EmbeddingModelSpec spec) =>
      AppFiles.getRealPath('model', spec.modelFileName);

  String tokenizerPathOf(EmbeddingModelSpec spec) =>
      AppFiles.getRealPath('model', spec.tokenizerFileName);

  static String get modelsDirPath =>
      File(AppFiles.getRealPath('model', 'x')).parent.path;

  bool isDownloaded(EmbeddingModelSpec spec) =>
      File(modelPathOf(spec)).existsSync() &&
      File(tokenizerPathOf(spec)).existsSync();

  String _url(String hfPath) {
    final mirror = MoodiaryKVs.modelDownloadMirror.get() ?? true;
    final host = mirror ? 'hf-mirror.com' : 'huggingface.co';
    return 'https://$host/$hfPath';
  }

  static final _activeParts = <String>{};

  /// `.part` files a running download or probe still owns. A stalled download
  /// can leave its file untouched for a long time, so age alone can't tell
  /// storage cleanup that it is abandoned.
  static bool ownsPartialDownload(String path) => _activeParts.contains(path);

  @visibleForTesting
  static void debugHoldPartialDownload(String path, {bool held = true}) =>
      held ? _activeParts.add(path) : _activeParts.remove(path);

  Future<void> download(
    EmbeddingModelSpec spec, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    if (isDownloaded(spec)) return;
    final modelPath = modelPathOf(spec);
    final tokenizerPath = tokenizerPathOf(spec);
    final parts = {'$modelPath.part', '$tokenizerPath.part'};
    _activeParts.addAll(parts);
    try {
      await _download(spec, modelPath, tokenizerPath, onProgress, cancel);
    } finally {
      _activeParts.removeAll(parts);
    }
  }

  Future<void> _download(
    EmbeddingModelSpec spec,
    String modelPath,
    String tokenizerPath,
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    await Directory(modelPath).parent.create(recursive: true);

    if (!File(tokenizerPath).existsSync()) {
      final tokenizerPart = '$tokenizerPath.part';
      await _http.downloadFile(
        _url(spec.tokenizerHfPath),
        tokenizerPart,
        cancel: cancel,
      );
      await File(tokenizerPart).rename(tokenizerPath);
    }

    final modelPart = '$modelPath.part';
    await _http.downloadFile(
      _url(spec.modelHfPath),
      modelPart,
      onProgress: onProgress,
      cancel: cancel,
    );
    try {
      await _probe(spec, modelPart, tokenizerPath);
    } catch (e, s) {
      logger.e('embedding model probe failed', error: e, stackTrace: s);
      await AppFiles.deleteFile(modelPart);
      rethrow;
    }
    await File(modelPart).rename(modelPath);
  }

  Future<void> activate(EmbeddingModelSpec spec) async {
    if (!isDownloaded(spec)) {
      throw StateError('model ${spec.id} not downloaded');
    }
    if (MoodiaryKVs.embeddingModelId.get() == spec.id) return;
    MoodiaryKVs.embeddingModelId.set(spec.id);
    MoodiaryKVs.embeddingDim.set(spec.dim);
    MoodiaryKVs.embeddingIndexStale.set(true);
  }

  void deactivate() {
    MoodiaryKVs.embeddingModelId.set('');
    MoodiaryKVs.embeddingDim.set(0);
    MoodiaryKVs.embeddingIndexStale.set(false);
  }

  Future<void> delete(EmbeddingModelSpec spec) async {
    if (active?.id == spec.id) deactivate();
    await AppFiles.deleteFile(modelPathOf(spec));
    await AppFiles.deleteFile(tokenizerPathOf(spec));
  }

  Future<void> _probe(
    EmbeddingModelSpec spec,
    String modelPath,
    String tokenizerPath,
  ) async {
    final backend = OnnxEmbeddingBackend();
    try {
      await backend.load(
        modelPath,
        tokenizerPath: tokenizerPath,
        padToken: spec.padToken,
        contextSize: spec.contextSize,
      );
      final vectors = await backend.embed(const ['探测']);
      if (vectors.single.length != spec.dim) {
        throw StateError(
          'dim mismatch: expect ${spec.dim}, got ${vectors.single.length}',
        );
      }
    } finally {
      await backend.unload();
    }
  }
}
