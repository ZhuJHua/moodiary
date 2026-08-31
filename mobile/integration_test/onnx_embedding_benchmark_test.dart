// 真机 benchmark / 冒烟：ONNX Runtime（onnxruntime_plus，FFI）统一运行时。
//   1) 嵌入性能：bge-small-zh int8 加载 / 单条 / 批量（协议与历史数据可对照：
//      llama.cpp 时代 12.4ms/86 chunks/s，ORT+ffi int8 19.0ms/49.2，见记忆与
//      docs/local-rag.md §6.8）
//   2) 一致性：int8 对 fp32 的逐条余弦（量化误差水位）
//
//   fvm flutter test integration_test/onnx_embedding_benchmark_test.dart \
//     -d <device> --flavor beta
//
// 模型 / 分词器由测试自己经 hf-mirror 下载并缓存在系统临时目录。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_rust/rust.dart';

// 双主机回退：先 hf-mirror（不经代理也稳），失败换 huggingface.co 直连。
const _hosts = ['https://hf-mirror.com', 'https://huggingface.co'];
const _bgeRepo = 'Xenova/bge-small-zh-v1.5/resolve/main';

const _singleRounds = 10;
const _batchRounds = 3;
const _batchSize = 16;

Future<String> _ensure(
  String hfPath,
  String relPath, {
  required int minBytes,
}) async {
  final file = File('${Directory.systemTemp.path}/$relPath');
  if (file.existsSync() && file.lengthSync() >= minBytes) return file.path;
  await file.parent.create(recursive: true);
  Object? lastError;
  for (var attempt = 0; attempt < 2 * _hosts.length; attempt++) {
    final url = '${_hosts[attempt % _hosts.length]}/$hfPath';
    debugPrint('BENCH: downloading $relPath ($url)...');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode}');
      }
      final sink = file.openWrite();
      await response.pipe(sink);
      if (file.lengthSync() >= minBytes) {
        debugPrint('BENCH: $relPath ready (${file.lengthSync()} bytes)');
        return file.path;
      }
      lastError = StateError('too small: ${file.lengthSync()} bytes');
    } catch (e) {
      lastError = e;
      debugPrint('BENCH: $relPath attempt ${attempt + 1} failed: $e');
    } finally {
      client.close();
    }
  }
  throw StateError('download failed: $relPath ($lastError)');
}

// 与历史 benchmark 同一份语料，保持吞吐数字可对照。
List<String> _passages() => [
  for (var i = 0; i < _batchSize; i++)
    '今天是第 $i 天，去公园散步的时候看到了很多人在跑步。'
        '天气不错，微风，阳光透过树叶洒下来。回家路上买了一杯咖啡，'
        '想起上周和朋友聊到的旅行计划，打算下个月去海边住几天，'
        '顺便把一直想读的那本书带上。晚上整理了照片，写了一会儿日记，'
        '感觉最近的生活节奏慢慢稳定下来了，心情也比前段时间好了很多。',
];

const _consistencyTexts = <String>[
  '今天心情很好，和家人一起吃了晚饭。',
  '工作压力太大了，整晚都睡不着，很焦虑。',
  '去海边看了日出，浪花拍在礁石上，特别治愈。',
  '猫生病了，跑了两趟宠物医院，又心疼又累。',
  '读完了一本关于宇宙学的书，对时间的理解完全变了。',
  '下雨天窝在家里听歌，煮了一锅热汤。',
  'Today I finally finished the marathon, exhausted but proud.',
  '面试结果出来了，没有通过，有点失落但也松了口气。',
];

typedef _BenchResult = ({
  String label,
  int loadMs,
  double singleAvgMs,
  double batchAvgMs,
  double chunksPerSec,
  List<Float32List> vectors,
});

Future<_BenchResult> _bench(
  String label,
  String modelPath,
  String tokenizerPath,
) async {
  final backend = OnnxEmbeddingBackend();
  try {
    final loadWatch = Stopwatch()..start();
    await backend.load(
      modelPath,
      tokenizerPath: tokenizerPath,
      padToken: '[PAD]',
    );
    final loadMs = loadWatch.elapsedMilliseconds;

    // 预热（首轮含图优化/内存分配，单独排除）。
    await backend.embed(const ['预热文本，避免首轮开销计入统计。']);

    final vectors = await backend.embed(_consistencyTexts);

    final single = Stopwatch()..start();
    for (var i = 0; i < _singleRounds; i++) {
      await backend.embed([_passages()[i % _batchSize]]);
    }
    final singleAvgMs = single.elapsedMilliseconds / _singleRounds;

    final batch = Stopwatch()..start();
    for (var i = 0; i < _batchRounds; i++) {
      await backend.embed(_passages());
    }
    final batchTotalMs = batch.elapsedMilliseconds;

    return (
      label: label,
      loadMs: loadMs,
      singleAvgMs: singleAvgMs,
      batchAvgMs: batchTotalMs / _batchRounds,
      chunksPerSec: _batchRounds * _batchSize / (batchTotalMs / 1000),
      vectors: vectors,
    );
  } finally {
    await backend.unload();
  }
}

double _cosine(Float32List a, Float32List b) {
  assert(a.length == b.length, 'dim mismatch: ${a.length} vs ${b.length}');
  var dot = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
  }
  return dot; // 两侧均已 L2 归一化
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  testWidgets('ONNX embedding benchmark', (tester) async {
    final tokenizerPath = await _ensure(
      '$_bgeRepo/tokenizer.json',
      'bench-bge-small.tokenizer.json',
      minBytes: 100 * 1024,
    );
    final int8Path = await _ensure(
      '$_bgeRepo/onnx/model_int8.onnx',
      'bench-bge-small-int8.onnx',
      minBytes: 15 * 1024 * 1024,
    );
    final fp32Path = await _ensure(
      '$_bgeRepo/onnx/model.onnx',
      'bench-bge-small-fp32.onnx',
      minBytes: 60 * 1024 * 1024,
    );

    final int8 = await _bench('int8', int8Path, tokenizerPath);
    final fp32 = await _bench('fp32', fp32Path, tokenizerPath);

    debugPrint('BENCH: -------- PERF (bge-small-zh) --------');
    for (final r in [int8, fp32]) {
      debugPrint(
        'BENCH: ${r.label} load=${r.loadMs}ms '
        'single=${r.singleAvgMs.toStringAsFixed(1)}ms '
        'batch16=${r.batchAvgMs.toStringAsFixed(0)}ms '
        'throughput=${r.chunksPerSec.toStringAsFixed(1)} chunks/s',
      );
    }

    debugPrint('BENCH: -------- CONSISTENCY (int8 vs fp32) --------');
    final cosines = [
      for (var i = 0; i < _consistencyTexts.length; i++)
        _cosine(fp32.vectors[i], int8.vectors[i]),
    ];
    for (var i = 0; i < cosines.length; i++) {
      debugPrint('BENCH:   #$i cos=${cosines[i].toStringAsFixed(4)}');
    }
    final minCos = cosines.reduce((a, b) => a < b ? a : b);
    debugPrint('BENCH: min cos=${minCos.toStringAsFixed(4)}');
    // 量化漂移观测线：Xenova int8 对 fp32 实测 0.96~0.97（2026-08-28 PJZ110），
    // 检索是相对排序，这个水位不影响召回；跌破 0.95 才值得追查。
    expect(minCos, greaterThan(0.95));
  }, timeout: const Timeout(Duration(minutes: 45)));
}
