import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' show CancelToken;
import 'package:moodiary_storage/moodiary_storage.dart';

import 'onnx_embedding_backend.dart';

/// 内置嵌入模型清单里的一项。ONNX 模型 = 计算图 + 配套 tokenizer.json 两个文件。
class EmbeddingModelSpec {
  final String id;

  /// UI 展示名（专名不进 i18n）。
  final String displayName;

  final int dim;

  /// Hugging Face 仓库内路径（`<repo>/resolve/main/<file>`），镜像与官方共用。
  final String modelHfPath;

  final String tokenizerHfPath;

  /// 近似体积（字节，模型+分词器），仅供 UI 展示。
  final int sizeBytes;

  /// 检索 query 侧的指令前缀（含尾部空格等格式，原样拼接）；索引侧同理。
  /// 前缀是模型契约的一部分——写错召回骤降。
  final String queryPrefix;

  final String passagePrefix;

  /// 推理上下文长度（bge-zh 系 512；m3 给 1024）。
  final int contextSize;

  /// pad token 名（BERT 系 `[PAD]`，XLM-R 系 `<pad>`）。
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
    this.padToken = '[PAD]',
  });

  String get modelFileName => '$id.onnx';

  String get tokenizerFileName => '$id.tokenizer.json';
}

const _bgeZhQueryPrefix = '为这个句子生成表示以用于检索相关文章：';

/// 内置清单，按体积升序，全部为 int8 单文件 ONNX（无 external data）。
/// 换模型 = 维度变 = 全量重嵌（EmbedIndexService 的 stale 重建路径）。
/// EmbeddingGemma 已下架：社区 ONNX 图只输出裸 hidden state，
/// 它的 mean 池化 + 双层投影不在图里，照搬 CLS 池化是错的；要回归得自转带池化的图。
const embeddingModelCatalog = <EmbeddingModelSpec>[
  EmbeddingModelSpec(
    id: 'bge-small-zh-v1.5-int8',
    displayName: 'BGE-small 中文',
    dim: 512,
    modelHfPath: 'Xenova/bge-small-zh-v1.5/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath: 'Xenova/bge-small-zh-v1.5/resolve/main/tokenizer.json',
    sizeBytes: 24117248, // 23 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-base-zh-v1.5-int8',
    displayName: 'BGE-base 中文',
    dim: 768,
    modelHfPath: 'Xenova/bge-base-zh-v1.5/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath: 'Xenova/bge-base-zh-v1.5/resolve/main/tokenizer.json',
    sizeBytes: 103809024, // 99 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-large-zh-v1.5-int8',
    displayName: 'BGE-large 中文',
    dim: 1024,
    modelHfPath: 'Xenova/bge-large-zh-v1.5/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath: 'Xenova/bge-large-zh-v1.5/resolve/main/tokenizer.json',
    sizeBytes: 327155712, // 312 MB
    queryPrefix: _bgeZhQueryPrefix,
  ),
  EmbeddingModelSpec(
    id: 'bge-m3-int8',
    displayName: 'BGE-M3 多语言',
    dim: 1024,
    modelHfPath: 'onnx-community/bge-m3-ONNX/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath: 'onnx-community/bge-m3-ONNX/resolve/main/tokenizer.json',
    sizeBytes: 585105408, // 558 MB
    // M3 官方明确不需要指令前缀（这是它相对 bge-v1.5 系的设计变化）。
    queryPrefix: '',
    contextSize: 1024,
    padToken: '<pad>',
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

  String modelPathOf(EmbeddingModelSpec spec) =>
      AppFiles.getRealPath('model', spec.modelFileName);

  String tokenizerPathOf(EmbeddingModelSpec spec) =>
      AppFiles.getRealPath('model', spec.tokenizerFileName);

  /// 模型目录（resetAllData 清理用）。
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

  /// 下载并校验（真加载一次 + 探测维度），通过后落到最终路径。
  /// 半成品带 `.part` 后缀，任何一步失败都不会留下会被误判为完整模型的文件。
  Future<void> download(
    EmbeddingModelSpec spec, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    if (isDownloaded(spec)) return;
    final modelPath = modelPathOf(spec);
    final tokenizerPath = tokenizerPathOf(spec);
    await Directory(modelPath).parent.create(recursive: true);

    // 分词器先行（不足 20MB，不占进度条）。
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
    await AppFiles.deleteFile(modelPathOf(spec));
    await AppFiles.deleteFile(tokenizerPathOf(spec));
  }

  /// 校验 = 真加载 + 嵌一句话 + 对维度，通过即丢弃（不常驻）。
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
