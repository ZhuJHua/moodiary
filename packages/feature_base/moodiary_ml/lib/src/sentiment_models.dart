import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_rust/foundation.dart' show CancelToken;
import 'package:moodiary_storage/moodiary_storage.dart';

import 'sentiment_engine.dart';

/// 本地情感分析模型清单里的一项。
class SentimentModelSpec {
  final String id;

  /// UI 展示名（专名不进 i18n）。
  final String displayName;

  final String modelHfPath;
  final String tokenizerHfPath;

  /// 近似体积（字节，模型+分词器），仅供 UI 展示。
  final int sizeBytes;

  /// 逐标签的效价权重（按模型 id2label 的下标序，0=最差 1=最好）；
  /// 心情分 = softmax 概率对它的加权和。标签序是模型各自的契约——
  /// lxyuan 是 positive/neutral/negative（与直觉相反，0 号是正面），写错整个反向。
  final List<double> labelWeights;

  final int contextSize;
  final String padToken;

  const SentimentModelSpec({
    required this.id,
    required this.displayName,
    required this.modelHfPath,
    required this.tokenizerHfPath,
    required this.sizeBytes,
    required this.labelWeights,
    this.contextSize = 512,
    this.padToken = '[PAD]',
  });

  String get modelFileName => '$id.onnx';

  String get tokenizerFileName => '$id.tokenizer.json';
}

/// lxyuan/distilbert-base-multilingual-cased-sentiments-student（Apache-2.0，
/// 多语言 3 类，ONNX 走 Xenova 官方转换仓）。tabularisai 已否决：CC-BY-NC 许可 +
/// 合成数据在含蓄中文情绪长句上翻车（「养了八年的狗走了」判 0.80 正面）；
/// 本模型同套探针 11/11 方向正确（2026-08-28 本机 int8 实测）。
const sentimentModelCatalog = <SentimentModelSpec>[
  SentimentModelSpec(
    id: 'multilingual-sentiments-student-int8',
    displayName: '多语言情感分析',
    modelHfPath:
        'Xenova/distilbert-base-multilingual-cased-sentiments-student/'
        'resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath:
        'Xenova/distilbert-base-multilingual-cased-sentiments-student/'
        'resolve/main/tokenizer.json',
    sizeBytes: 138936320, // 132.5 MB
    labelWeights: [1.0, 0.5, 0.0], // positive / neutral / negative
  ),
];

/// 情感模型的下载 / 校验 / 激活管理，与嵌入模型同一套形态与目录。
@LazySingleton()
class SentimentModelManager {
  final IHttpClient _http;

  SentimentModelManager(this._http);

  static SentimentModelSpec? byId(String id) {
    for (final spec in sentimentModelCatalog) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  SentimentModelSpec? get active =>
      byId(MoodiaryKVs.sentimentModelId.get() ?? '');

  String modelPathOf(SentimentModelSpec spec) =>
      AppFiles.getRealPath('model', spec.modelFileName);

  String tokenizerPathOf(SentimentModelSpec spec) =>
      AppFiles.getRealPath('model', spec.tokenizerFileName);

  bool isDownloaded(SentimentModelSpec spec) =>
      File(modelPathOf(spec)).existsSync() &&
      File(tokenizerPathOf(spec)).existsSync();

  String _url(String hfPath) {
    final mirror = MoodiaryKVs.modelDownloadMirror.get() ?? true;
    final host = mirror ? 'hf-mirror.com' : 'huggingface.co';
    return 'https://$host/$hfPath';
  }

  Future<void> download(
    SentimentModelSpec spec, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  }) async {
    if (isDownloaded(spec)) return;
    final modelPath = modelPathOf(spec);
    final tokenizerPath = tokenizerPathOf(spec);
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
      logger.e('sentiment model probe failed', error: e, stackTrace: s);
      await AppFiles.deleteFile(modelPart);
      rethrow;
    }
    await File(modelPart).rename(modelPath);
  }

  void activate(SentimentModelSpec spec) {
    if (!isDownloaded(spec)) {
      throw StateError('model ${spec.id} not downloaded');
    }
    MoodiaryKVs.sentimentModelId.set(spec.id);
  }

  void deactivate() {
    MoodiaryKVs.sentimentModelId.set('');
  }

  Future<void> delete(SentimentModelSpec spec) async {
    if (active?.id == spec.id) deactivate();
    await AppFiles.deleteFile(modelPathOf(spec));
    await AppFiles.deleteFile(tokenizerPathOf(spec));
  }

  /// 校验 = 真加载 + 打一次分 + 分数在 0..1 内，通过即丢弃。
  Future<void> _probe(
    SentimentModelSpec spec,
    String modelPath,
    String tokenizerPath,
  ) async {
    final classifier = OnnxSentimentClassifier();
    try {
      await classifier.load(
        modelPath,
        tokenizerPath: tokenizerPath,
        padToken: spec.padToken,
        labelWeights: spec.labelWeights,
        contextSize: spec.contextSize,
      );
      final score = await classifier.score('探测');
      if (score.isNaN || score < 0 || score > 1) {
        throw StateError('probe score out of range: $score');
      }
    } finally {
      await classifier.unload();
    }
  }
}
