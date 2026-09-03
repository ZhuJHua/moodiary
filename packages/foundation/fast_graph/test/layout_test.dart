import 'package:fast_graph/fast_graph.dart';
import 'package:flutter_test/flutter_test.dart';

GraphLayoutParams params({
  int iterations = 20,
  int emitEvery = 1,
  int delay = 0,
}) => GraphLayoutParams(
  iterations: iterations,
  theta: 0.9,
  repulsion: 1,
  springLength: 30,
  springStrength: 0.1,
  gravity: 0.05,
  collideRadius: 8,
  velocityDecay: 0.4,
  emitEvery: emitEvery,
  frameDelayMs: delay,
  initialAlpha: 1,
  minStep: 0,
  pinnedCount: 0,
  normalizeScale: true,
);

void main() {
  test('逐帧回传直到沉降，每帧 2*n 个坐标', () async {
    final frames = await layoutGraphStream(
      nodeCount: 3,
      edges: [0, 1, 1, 2],
      initialPositions: const [],
      params: params(),
    ).toList();
    expect(frames, isNotEmpty);
    expect(frames.every((f) => f.length == 6), isTrue);
  });

  test('边下标越界以 FastGraphException 收场', () {
    expect(
      layoutGraphStream(
        nodeCount: 2,
        edges: [0, 9],
        initialPositions: const [],
        params: params(),
      ).toList(),
      throwsA(isA<FastGraphException>()),
    );
  });

  test('取消订阅后原生线程停下，不再推帧', () async {
    var count = 0;
    final sub = layoutGraphStream(
      nodeCount: 50,
      edges: [
        for (var i = 0; i < 49; i++) ...[i, i + 1],
      ],
      initialPositions: const [],
      params: params(iterations: 10000, delay: 5),
    ).listen((_) => count++);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await sub.cancel();
    final seen = count;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(count, seen);
  });
}
