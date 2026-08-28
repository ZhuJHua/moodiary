import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' show CancelToken;
import 'package:moodiary_storage/moodiary_storage.dart';

import 'embedding_backend.dart';

/// 内置嵌入模型清单里的一项。
class EmbeddingModelSpec {
  final String id;

  /// UI 展示名（专名不进 i18n）。
  final String displayName;

  final String fileName;
  final int dim;

  /// Hugging Face 仓库内路径（`<repo>/resolve/main/<file>`），镜像与官方共用。
  final String hfPath;

  /// 近似体积（字节），仅供 UI 展示。
  final int sizeBytes;

  /// 检索 query 侧的指令前缀（含尾部空格等格式，原样拼接）；索引侧同理。
  /// 前缀是模型契约的一部分——bge-zh 与 EmbeddingGemma 完全不同，写错召回骤降。
  final String queryPrefix;

  final String passagePrefix;

  /// 推理上下文长度（bge 系 512；gemma 前缀更长、中文 token 更碎，给 1024）。
  final int contextSize;

  const EmbeddingModelSpec({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.dim,
    required this.hfPath,
    required this.sizeBytes,
    required this.queryPrefix,
    this.passagePrefix = '',
    this.contextSize = 512,
  });
}

const _bgeZhQueryPrefix = '为这个句子生成表示以用于检索相关文章：';

/// 内置清单，按体积升序。全部为 llama.cpp 官方支持的架构（BERT / gemma-embedding），
/// 换模型 = 维度变 = 全量重嵌（EmbedIndexService 的 stale 重建路径）。
const embeddingModelCatalog = <EmbeddingModelSpec>[
  EmbeddingModelSpec(
    id: 'bge-small-zh-v1.5-q8_0',
    displayName: 'BGE-small 中文',
    fileName: 'bge-small-zh-v1.5-q8_0.gguf',
    dim: 512,
    hfPath:
        'CompendiumLabs/bge-small-zh-v1.5-gguf/resolve/main/'
        'bge-small-zh-v1.5-q8_0.gguf',
    sizeBytes: 27262976, // 26 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-base-zh-v1.5-q8_0',
    displayName: 'BGE-base 中文',
    fileName: 'bge-base-zh-v1.5-q8_0.gguf',
    dim: 768,
    hfPath:
        'CompendiumLabs/bge-base-zh-v1.5-gguf/resolve/main/'
        'bge-base-zh-v1.5-q8_0.gguf',
    sizeBytes: 110100480, // 105 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-large-zh-v1.5-q8_0',
    displayName: 'BGE-large 中文',
    fileName: 'bge-large-zh-v1.5-q8_0.gguf',
    dim: 1024,
    hfPath:
        'CompendiumLabs/bge-large-zh-v1.5-gguf/resolve/main/'
        'bge-large-zh-v1.5-q8_0.gguf',
    sizeBytes: 348127232, // 332 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-m3-q8_0',
    displayName: 'BGE-M3 多语言',
    fileName: 'bge-m3-Q8_0.gguf',
    dim: 1024,
    hfPath: 'gpustack/bge-m3-GGUF/resolve/main/bge-m3-Q8_0.gguf',
    sizeBytes: 665845760, // 635 MB
    // M3 官方明确不需要指令前缀（这是它相对 bge-v1.5 系的设计变化）。
    queryPrefix: '',
    contextSize: 1024,
  ),
  EmbeddingModelSpec(
    id: 'embeddinggemma-300m-q8_0',
    displayName: 'EmbeddingGemma 多语言',
    fileName: 'embeddinggemma-300M-Q8_0.gguf',
    dim: 768,
    hfPath:
        'ggml-org/embeddinggemma-300M-GGUF/resolve/main/'
        'embeddinggemma-300M-Q8_0.gguf',
    sizeBytes: 350224384, // 334 MB
    // EmbeddingGemma 的官方 prompt 契约（model card）：
    queryPrefix: 'task: search result | query: ',
    passagePrefix: 'title: none | text: ',
    contextSize: 1024,
  ),
];

/// 嵌入模型的下载 / 校验 / 激活管理。模型文件落 `model/` 目录；
/// 「激活了哪个模型」与「维度」记在 KV，切换即置 `embeddingIndexStale`。
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

  /// 当前激活的模型；未激活或清单里已不存在则为 null。
  EmbeddingModelSpec? get active =>
      byId(MoodiaryKVs.embeddingModelId.get() ?? '');

  String pathOf(EmbeddingModelSpec spec) =>
      AppFiles.getRealPath('model', spec.fileName);

  /// 模型目录（resetAllData 清理用）。
  static String get modelsDirPath =>
      File(AppFiles.getRealPath('model', 'x')).parent.path;

  bool isDownloaded(EmbeddingModelSpec spec) => File(pathOf(spec)).existsSync();

  String _url(EmbeddingModelSpec spec) {
    final mirror = MoodiaryKVs.modelDownloadMirror.get() ?? true;
    final host = mirror ? 'hf-mirror.com' : 'huggingface.co';
    return 'https://$host/${spec.hfPath}';
  }

  /// 下载并校验（真加载一次 + 探测维度），通过后落到最终路径。
  /// 半成品带 `.part` 后缀，任何一步失败都不会留下会被误判为完整模型的文件。
  Future<void> download(
    EmbeddingModelSpec spec, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    if (isDownloaded(spec)) return;
    final destPath = pathOf(spec);
    await Directory(destPath).parent.create(recursive: true);
    final partPath = '$destPath.part';
    await _http.downloadFile(
      _url(spec),
      partPath,
      onProgress: onProgress,
      cancel: cancel,
    );
    try {
      await _probe(spec, partPath);
    } catch (e, s) {
      logger.e('embedding model probe failed', error: e, stackTrace: s);
      await AppFiles.deleteFile(partPath);
      rethrow;
    }
    await File(partPath).rename(destPath);
  }

  /// 激活：置 KV 并标记语义索引需全量重建（维度可能已变）。
  Future<void> activate(EmbeddingModelSpec spec) async {
    if (!isDownloaded(spec)) {
      throw StateError('model ${spec.id} not downloaded');
    }
    if (MoodiaryKVs.embeddingModelId.get() == spec.id) return;
    MoodiaryKVs.embeddingModelId.set(spec.id);
    MoodiaryKVs.embeddingDim.set(spec.dim);
    MoodiaryKVs.embeddingIndexStale.set(true);
  }

  /// 停用：语义检索整体下线，向量数据由 data 层的重建入口清理。
  void deactivate() {
    MoodiaryKVs.embeddingModelId.set('');
    MoodiaryKVs.embeddingDim.set(0);
    MoodiaryKVs.embeddingIndexStale.set(false);
  }

  Future<void> delete(EmbeddingModelSpec spec) async {
    if (active?.id == spec.id) deactivate();
    await AppFiles.deleteFile(pathOf(spec));
  }

  /// 校验 = 真加载 + 嵌一句话 + 对维度，通过即丢弃（不常驻）。
  Future<void> _probe(EmbeddingModelSpec spec, String path) async {
    final backend = LlamaEmbeddingBackend();
    try {
      await backend.load(path);
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
