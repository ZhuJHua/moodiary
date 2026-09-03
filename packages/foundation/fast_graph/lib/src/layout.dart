import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi.dart' as c;

/// 布局参数。与原生侧 `GraphLayoutParams` 一一对应，语义见 rust/src/layout.rs 的字段注释。
class GraphLayoutParams {
  const GraphLayoutParams({
    required this.iterations,
    required this.theta,
    required this.repulsion,
    required this.springLength,
    required this.springStrength,
    required this.gravity,
    required this.collideRadius,
    required this.velocityDecay,
    required this.emitEvery,
    required this.frameDelayMs,
    required this.initialAlpha,
    required this.minStep,
    required this.pinnedCount,
    required this.normalizeScale,
  });

  final int iterations;
  final double theta;
  final double repulsion;
  final double springLength;
  final double springStrength;
  final double gravity;
  final double collideRadius;
  final double velocityDecay;
  final int emitEvery;
  final int frameDelayMs;
  final double initialAlpha;
  final double minStep;
  final int pinnedCount;
  final bool normalizeScale;

  void _writeTo(c.FfiLayoutParams out) {
    out
      ..iterations = iterations
      ..theta = theta
      ..repulsion = repulsion
      ..springLength = springLength
      ..springStrength = springStrength
      ..gravity = gravity
      ..collideRadius = collideRadius
      ..velocityDecay = velocityDecay
      ..emitEvery = emitEvery
      ..frameDelayMs = frameDelayMs
      ..initialAlpha = initialAlpha
      ..minStep = minStep
      ..pinnedCount = pinnedCount
      ..normalizeScale = normalizeScale ? 1 : 0;
  }
}

/// 原生侧报上来的错误（边下标越界之类）。
class FastGraphException implements Exception {
  const FastGraphException(this.message);

  final String message;

  @override
  String toString() => 'FastGraphException: $message';
}

/// 流式布局：`edges` 为 `[src0,dst0,src1,dst1,...]` 下标对，`initialPositions` 为空则确定性播种。
/// 每帧一份 `[x0,y0,...]`（长度 `2*nodeCount`）；沉降完成即 done，取消订阅即停。
///
/// 布局跑在原生线程上，帧经 `NativeCallable.listener` 回到本 isolate 的事件循环。
/// 原生侧保证终态事件恰好来一次（取消也是），回调在收到它之后才关——关早了会 UB。
Stream<Float32List> layoutGraphStream({
  required int nodeCount,
  required List<int> edges,
  required List<double> initialPositions,
  required GraphLayoutParams params,
}) {
  late final StreamController<Float32List> controller;
  NativeCallable<c.FrameCallbackNative>? callback;
  Pointer<c.LayoutHandle>? handle;

  void finish() {
    final h = handle;
    handle = null;
    if (h != null) c.fastgraphLayoutFree(h);
    callback?.close();
    callback = null;
  }

  void onEvent(int kind, Pointer<Uint8> ptr, int len) {
    final bytes = Uint8List.fromList(ptr.asTypedList(len));
    c.fastgraphBufFree(ptr, len);
    switch (kind) {
      case 0:
        if (!controller.isClosed) {
          controller.add(bytes.buffer.asFloat32List(0, len ~/ 4));
        }
      case 1:
        finish();
        if (!controller.isClosed) controller.close();
      default:
        finish();
        if (!controller.isClosed) {
          controller
            ..addError(
              FastGraphException(utf8.decode(bytes, allowMalformed: true)),
            )
            ..close();
        }
    }
  }

  void start() {
    final cb = NativeCallable<c.FrameCallbackNative>.listener(onEvent);
    callback = cb;
    final e = calloc<Int32>(edges.isEmpty ? 1 : edges.length);
    final p = calloc<Float>(
      initialPositions.isEmpty ? 1 : initialPositions.length,
    );
    final ps = calloc<c.FfiLayoutParams>();
    try {
      e.asTypedList(edges.length).setAll(0, edges);
      p.asTypedList(initialPositions.length).setAll(0, initialPositions);
      params._writeTo(ps.ref);
      // 原生侧在返回前就把输入拷走了，下面 finally 里释放是安全的。
      handle = c.fastgraphLayoutStart(
        nodeCount,
        e,
        edges.length,
        p,
        initialPositions.length,
        ps,
        cb.nativeFunction,
      );
    } finally {
      calloc.free(e);
      calloc.free(p);
      calloc.free(ps);
    }
  }

  controller = StreamController<Float32List>(
    onListen: start,
    onCancel: () {
      final h = handle;
      if (h != null) c.fastgraphLayoutCancel(h);
      // 句柄与回调等终态事件到了再收（原生线程可能还在推最后一帧）。
    },
  );
  return controller.stream;
}
