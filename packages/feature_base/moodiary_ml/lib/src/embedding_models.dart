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

  /// 推理上下文长度。
  final int contextSize;

  /// pad token 名（Qwen 系 `<|endoftext|>`）。
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

/// 内置清单：固定 Qwen3-Embedding-0.6B（2026-08-31 拍板，bge 系整体下架——
/// 该体积下多语言检索质量最优，含蓄中文表达召回明显好于 bge）。int8 单文件
/// ONNX（无 external data）。换模型 = 维度变 = 全量重嵌（stale 重建路径）。
/// EmbeddingGemma 已下架：社区图无池化且它的 mean 池化 + 双层投影没法在图外补。
/// tokenizer 的 TemplateProcessing 自动在末尾补 `<|endoftext|>`，last-token
/// 池化取的就是这个 EOS 位——这是模型契约，动 tokenizer 就破功。
const embeddingModelCatalog = <EmbeddingModelSpec>[
  EmbeddingModelSpec(
    id: 'qwen3-embedding-0.6b-int8',
    displayName: 'Qwen3-Embedding 0.6B',
    dim: 1024,
    modelHfPath: 'onnx-community/Qwen3-Embedding-0.6B-ONNX/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath:
        'onnx-community/Qwen3-Embedding-0.6B-ONNX/resolve/main/tokenizer.json',
    sizeBytes: 624951296, // 596 MB
    // 官方非对称检索契约：query 侧带 Instruct 前缀（Query: 后不加空格），
    // passage 侧裸文本。
    queryPrefix: 'Instruct: Given a diary search query, retrieve relevant diary passages\nQuery:',
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
