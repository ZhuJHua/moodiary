/// graph 门面：力导向图布局流。只给 `moodiary_diary`。
library;

import 'dart:typed_data';

import 'src/runtime.dart';
import 'src/rust/api/graph_layout.dart' as api;
import 'src/rust/api/graph_layout.dart' show GraphLayoutParams;

export 'src/runtime.dart';
export 'src/rust/api/graph_layout.dart' show GraphLayoutParams;

/// 流式布局：`edges` 为 `[src0,dst0,src1,dst1,...]` 下标对，`initialPositions` 为空则确定性播种。
/// 每帧一份 `[x0,y0,...]`（长度 `2*nodeCount`）；沉降完成即 done，取消订阅即停。
/// 先保证库已装载再开流，调用方不用 init。
Stream<Float32List> layoutGraphStream({
  required int nodeCount,
  required List<int> edges,
  required List<double> initialPositions,
  required GraphLayoutParams params,
}) async* {
  await MoodiaryRust.ensureInitialized();
  yield* api.layoutGraphStream(
    nodeCount: nodeCount,
    edges: Int32List.fromList(edges),
    initialPositions: Float32List.fromList(initialPositions),
    params: params,
  );
}
