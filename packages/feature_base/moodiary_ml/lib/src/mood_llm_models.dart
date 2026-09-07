import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'onnx_mood_classifier.dart';

class MoodLlmSpec {
  final String id;

  final String displayName;

  final String modelHfPath;
  final String tokenizerHfPath;

  final int sizeBytes;

  const MoodLlmSpec({
    required this.id,
    required this.displayName,
    required this.modelHfPath,
    required this.tokenizerHfPath,
    required this.sizeBytes,
  });

  String get modelFileName => '$id.onnx';

  String get tokenizerFileName => '$id.tokenizer.json';
}

const moodLlmCatalog = <MoodLlmSpec>[
  MoodLlmSpec(
    id: 'qwen3-0.6b-int8',
    displayName: 'Qwen3 0.6B',
    modelHfPath:
        'onnx-community/Qwen3-0.6B-ONNX/resolve/main/onnx/model_int8.onnx',
    tokenizerHfPath:
        'onnx-community/Qwen3-0.6B-ONNX/resolve/main/tokenizer.json',
    sizeBytes: 627048448, // 598 MB
  ),
];

@LazySingleton()
class MoodLlmModelManager {
  final IHttpClient _http;

  MoodLlmModelManager(this._http);

  static MoodLlmSpec? byId(String id) {
    for (final spec in moodLlmCatalog) {
      if (spec.id == id) return spec;
    }
    return null;
  }

  MoodLlmSpec? get active => byId(MoodiaryKVs.moodLlmModelId.get() ?? '');

  String modelPathOf(MoodLlmSpec spec) =>
      AppFiles.getRealPath('model', spec.modelFileName);

  String tokenizerPathOf(MoodLlmSpec spec) =>
      AppFiles.getRealPath('model', spec.tokenizerFileName);

  bool isDownloaded(MoodLlmSpec spec) =>
      File(modelPathOf(spec)).existsSync() &&
      File(tokenizerPathOf(spec)).existsSync();

  String _url(String hfPath) {
    final mirror = MoodiaryKVs.modelDownloadMirror.get() ?? true;
    final host = mirror ? 'hf-mirror.com' : 'huggingface.co';
    return 'https://$host/$hfPath';
  }

  Future<void> download(
    MoodLlmSpec spec, {
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
      await _probe(modelPart, tokenizerPath);
    } catch (e, s) {
      logger.e('mood llm probe failed', error: e, stackTrace: s);
      await AppFiles.deleteFile(modelPart);
      rethrow;
    }
    await File(modelPart).rename(modelPath);
  }

  void activate(MoodLlmSpec spec) {
    if (!isDownloaded(spec)) {
      throw StateError('model ${spec.id} not downloaded');
    }
    MoodiaryKVs.moodLlmModelId.set(spec.id);
  }

  void deactivate() {
    MoodiaryKVs.moodLlmModelId.set('');
  }

  Future<void> delete(MoodLlmSpec spec) async {
    if (active?.id == spec.id) deactivate();
    await AppFiles.deleteFile(modelPathOf(spec));
    await AppFiles.deleteFile(tokenizerPathOf(spec));
  }

  Future<void> _probe(String modelPath, String tokenizerPath) async {
    final classifier = OnnxMoodClassifier();
    try {
      await classifier.load(modelPath, tokenizerPath: tokenizerPath);
      final (key, _) = await classifier.ask(
        '今天天气不错。',
        question: 'What language is this diary entry written in?',
        options: const [
          (key: 'zh', description: 'Chinese'),
          (key: 'en', description: 'English'),
        ],
      );
      if (key != 'zh' && key != 'en') {
        throw StateError('probe returned unknown key $key');
      }
    } finally {
      await classifier.unload();
    }
  }
}
