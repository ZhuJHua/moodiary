// 真机 benchmark / 冒烟：ONNX Runtime（onnxruntime_plus，FFI）统一运行时。
//   1) 嵌入性能：Qwen3-Embedding-0.6B int8 加载 / 单条 / 批量（历史对照：
//      bge-small int8 19.0ms/49.2 chunks/s，参数量 25 倍差距，见 docs/local-rag.md §6.8）
//   2) 检索方向：5 组 query→passage 的 top-1 命中（int8 fp32 对照不可行——
//      fp32 图带 external data，单文件架构装不下；桌面侧已验 5/5）
//   3) 心情建议冒烟：Qwen3-0.6B int8 两段式提问的方向正确性
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
const _embRepo = 'onnx-community/Qwen3-Embedding-0.6B-ONNX/resolve/main';
const _llmRepo = 'onnx-community/Qwen3-0.6B-ONNX/resolve/main';

const _singleRounds = 5;
const _batchRounds = 2;
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

// 检索方向冒烟：query i 应命中 passage i（桌面侧 int8 实测 5/5）。
const _retrievalPassages = <String>[
  '今天部门开了一整天的会，方案改了三版还是被打回，心力交瘁。',
  '周末去了趟青岛，海边风很大，但日落真的值。',
  '养了八年的狗今天走了，我一直以为还有很多时间。',
  '中午和同事去吃了新开的川菜馆，毛血旺一绝。',
  '高数期中成绩出来了，比预期好，这个月刷题总算有回报。',
];

const _retrievalQueries = <String>[
  '工作不顺心的日子',
  '海边旅行',
  '宠物离世的伤心事',
  '好吃的川菜',
  '考试成绩',
];

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

  testWidgets('Qwen3 embedding benchmark + retrieval smoke', (tester) async {
    final spec = embeddingModelCatalog.single;
    final tokenizerPath = await _ensure(
      '$_embRepo/tokenizer.json',
      'bench-qwen3-emb.tokenizer.json',
      minBytes: 10 * 1024 * 1024,
    );
    final modelPath = await _ensure(
      '$_embRepo/onnx/model_int8.onnx',
      'bench-qwen3-emb-int8.onnx',
      minBytes: 500 * 1024 * 1024,
    );

    final backend = OnnxEmbeddingBackend();
    try {
      final loadWatch = Stopwatch()..start();
      await backend.load(
        modelPath,
        tokenizerPath: tokenizerPath,
        padToken: spec.padToken,
        contextSize: spec.contextSize,
      );
      debugPrint('BENCH: load=${loadWatch.elapsedMilliseconds}ms');

      // 预热（首轮含图优化/内存分配，单独排除）。
      await backend.embed(const ['预热文本，避免首轮开销计入统计。']);

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
      debugPrint(
        'BENCH: single=${singleAvgMs.toStringAsFixed(1)}ms '
        'batch16=${(batchTotalMs / _batchRounds).toStringAsFixed(0)}ms '
        'throughput=${(_batchRounds * _batchSize / (batchTotalMs / 1000)).toStringAsFixed(1)} chunks/s',
      );

      final docs = await backend.embed(_retrievalPassages);
      final queries = await backend.embed([
        for (final q in _retrievalQueries) '${spec.queryPrefix}$q',
      ]);
      var hit = 0;
      for (var i = 0; i < queries.length; i++) {
        var best = 0;
        for (var j = 1; j < docs.length; j++) {
          if (_cosine(queries[i], docs[j]) > _cosine(queries[i], docs[best])) {
            best = j;
          }
        }
        debugPrint('BENCH: retrieval "${_retrievalQueries[i]}" -> $best');
        if (best == i) hit++;
      }
      expect(hit, _retrievalQueries.length);
      expect(queries.first.length, spec.dim);
    } finally {
      await backend.unload();
    }
  }, timeout: const Timeout(Duration(minutes: 60)));

  testWidgets('Qwen3 mood llm two-stage smoke', (tester) async {
    final tokenizerPath = await _ensure(
      '$_llmRepo/tokenizer.json',
      'bench-qwen3-llm.tokenizer.json',
      minBytes: 8 * 1024 * 1024,
    );
    final modelPath = await _ensure(
      '$_llmRepo/onnx/model_int8.onnx',
      'bench-qwen3-llm-int8.onnx',
      minBytes: 500 * 1024 * 1024,
    );

    const themeOptions = <MoodOption>[
      (
        key: 'food',
        description: 'food — a meal, cooking, a restaurant, dessert, snacks',
      ),
      (
        key: 'travel',
        description: 'travel — a trip, sightseeing, being away from home',
      ),
      (
        key: '__emotion__',
        description:
            'none of these activities — the entry is mainly about a feeling',
      ),
    ];
    const emotionOptions = <MoodOption>[
      (
        key: 'positive',
        description: 'happy — in a good mood, something worth celebrating',
      ),
      (key: 'negative', description: 'sad — down, upset, heartbroken'),
      (
        key: 'tired',
        description: 'tired — exhausted, drained, only want to sleep',
      ),
    ];

    final classifier = OnnxMoodClassifier();
    try {
      final loadWatch = Stopwatch()..start();
      await classifier.load(modelPath, tokenizerPath: tokenizerPath);
      debugPrint('BENCH: mood llm load=${loadWatch.elapsedMilliseconds}ms');

      const themeQuestion =
          'Which option best describes what this diary entry is mainly about?';
      final watch = Stopwatch()..start();
      final (theme1, p1) = await classifier.ask(
        '中午和同事去吃了新开的川菜馆，毛血旺一绝，就是排队排了四十分钟。',
        question: themeQuestion,
        options: themeOptions,
      );
      debugPrint(
        'BENCH: mood q1=${watch.elapsedMilliseconds}ms '
        '-> $theme1 (${p1.toStringAsFixed(2)})',
      );
      expect(theme1, 'food');

      watch.reset();
      const emotionSample = '连续加班一周，今天下班回家倒头就睡，什么都不想干。';
      final (theme2, _) = await classifier.ask(
        emotionSample,
        question: themeQuestion,
        options: themeOptions,
      );
      expect(theme2, '__emotion__');
      final (emotion, p3) = await classifier.ask(
        emotionSample,
        question: "What is the writer's dominant emotion in this diary entry?",
        options: emotionOptions,
      );
      debugPrint(
        'BENCH: mood q2+q3=${watch.elapsedMilliseconds}ms '
        '-> $emotion (${p3.toStringAsFixed(2)})',
      );
      expect(emotion, 'tired');
    } finally {
      await classifier.unload();
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
