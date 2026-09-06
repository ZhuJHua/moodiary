library;

import 'dart:typed_data';

import 'src/runtime.dart';
import 'src/rust/api/graph_layout.dart' as api;
import 'src/rust/api/graph_layout.dart' show GraphLayoutParams;

export 'src/runtime.dart';
export 'src/rust/api/graph_layout.dart' show GraphLayoutParams;

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
