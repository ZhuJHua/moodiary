// 真机 benchmark：同一嵌入模型分别用 CPU（full 变体，运行时自动挑最优）与
// Vulkan 加载，对比加载耗时 / 单条延迟 / 批量吞吐。结果经 debugPrint 输出。
//
//   fvm flutter test integration_test/embedding_benchmark_test.dart \
//     -d <device> --flavor beta
//
// 模型（bge-small-zh q8_0，26MB）由测试自己经 hf-mirror 下载并缓存在应用
// 缓存目录，重复运行不再下载。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:llamadart/llamadart.dart';

typedef _ModelSpec = ({String name, String url, String file, int ctx});

const _models = <_ModelSpec>[
  (
    name: 'bge-small-zh q8',
    url:
        'https://hf-mirror.com/CompendiumLabs/bge-small-zh-v1.5-gguf/resolve/main/'
        'bge-small-zh-v1.5-q8_0.gguf',
    file: 'bench-bge-small-q8.gguf',
    ctx: 512,
  ),
  (
    name: 'bge-m3 q8',
    url: 'https://hf-mirror.com/gpustack/bge-m3-GGUF/resolve/main/bge-m3-Q8_0.gguf',
    file: 'bench-bge-m3-q8.gguf',
    ctx: 1024,
  ),
];

const _singleRounds = 10;
const _batchRounds = 3;
const _batchSize = 16;

Future<String> _ensureModel(_ModelSpec spec) async {
  final file = File('${Directory.systemTemp.path}/${spec.file}');
  if (file.existsSync() && file.lengthSync() > 20 * 1024 * 1024) {
    return file.path;
  }
  debugPrint('BENCH: downloading ${spec.name}...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(spec.url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('download failed: HTTP ${response.statusCode}');
    }
    final sink = file.openWrite();
    await response.pipe(sink);
  } finally {
    client.close();
  }
  debugPrint('BENCH: ${spec.name} ready (${file.lengthSync()} bytes)');
  return file.path;
}

List<String> _passages() => [
  for (var i = 0; i < _batchSize; i++)
    '今天是第 $i 天，去公园散步的时候看到了很多人在跑步。'
        '天气不错，微风，阳光透过树叶洒下来。回家路上买了一杯咖啡，'
        '想起上周和朋友聊到的旅行计划，打算下个月去海边住几天，'
        '顺便把一直想读的那本书带上。晚上整理了照片，写了一会儿日记，'
        '感觉最近的生活节奏慢慢稳定下来了，心情也比前段时间好了很多。',
];

typedef BenchResult = ({
  String backendName,
  int loadMs,
  double singleAvgMs,
  double batchAvgMs,
  double chunksPerSec,
});

Future<BenchResult> _bench(
  String modelPath, {
  required GpuBackend backend,
  required int gpuLayers,
  required int contextSize,
}) async {
  final engine = LlamaEngine(LlamaBackend());
  try {
    final loadWatch = Stopwatch()..start();
    await engine.loadModel(
      modelPath,
      modelParams: ModelParams(
        contextSize: contextSize,
        preferredBackend: backend,
        gpuLayers: gpuLayers,
      ),
    );
    final loadMs = loadWatch.elapsedMilliseconds;
    final backendName = await engine.getBackendName();

    // 预热（首次推理含内核编译/上载，单独排除）。
    await engine.embedBatch(['预热文本，避免首轮开销计入统计。']);

    final single = Stopwatch()..start();
    for (var i = 0; i < _singleRounds; i++) {
      await engine.embedBatch([_passages()[i % _batchSize]]);
    }
    final singleAvgMs = single.elapsedMilliseconds / _singleRounds;

    final batch = Stopwatch()..start();
    for (var i = 0; i < _batchRounds; i++) {
      await engine.embedBatch(_passages());
    }
    final batchTotalMs = batch.elapsedMilliseconds;
    final batchAvgMs = batchTotalMs / _batchRounds;
    final chunksPerSec = _batchRounds * _batchSize / (batchTotalMs / 1000);

    return (
      backendName: backendName,
      loadMs: loadMs,
      singleAvgMs: singleAvgMs,
      batchAvgMs: batchAvgMs,
      chunksPerSec: chunksPerSec,
    );
  } finally {
    await engine.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CPU vs Vulkan embedding benchmark', (tester) async {
    String row(String label, BenchResult r) =>
        'BENCH: $label backend=${r.backendName} load=${r.loadMs}ms '
        'single=${r.singleAvgMs.toStringAsFixed(1)}ms '
        'batch16=${r.batchAvgMs.toStringAsFixed(0)}ms '
        'throughput=${r.chunksPerSec.toStringAsFixed(1)} chunks/s';

    for (final spec in _models) {
      final modelPath = await _ensureModel(spec);
      debugPrint('BENCH: === ${spec.name} / CPU ===');
      final cpu = await _bench(
        modelPath,
        backend: GpuBackend.cpu,
        gpuLayers: 0,
        contextSize: spec.ctx,
      );
      debugPrint('BENCH: === ${spec.name} / Vulkan ===');
      final vulkan = await _bench(
        modelPath,
        backend: GpuBackend.vulkan,
        gpuLayers: ModelParams.maxGpuLayers,
        contextSize: spec.ctx,
      );
      debugPrint('BENCH: -------- RESULT ${spec.name} --------');
      debugPrint(row('CPU   ', cpu));
      debugPrint(row('Vulkan', vulkan));
      debugPrint(
        'BENCH: ${spec.name} speedup single x'
        '${(cpu.singleAvgMs / vulkan.singleAvgMs).toStringAsFixed(2)}, '
        'batch x${(cpu.batchAvgMs / vulkan.batchAvgMs).toStringAsFixed(2)}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
