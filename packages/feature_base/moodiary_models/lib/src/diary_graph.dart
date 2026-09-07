import 'dart:typed_data';

class DiaryGraphNode {
  final int index;
  final String id;
  final String title;
  final DateTime time;
  final String? categoryId;

  final int? depth;

  final String? preview;

  const DiaryGraphNode({
    required this.index,
    required this.id,

    required this.title,
    required this.time,
    required this.categoryId,
    this.depth,
    this.preview,
  });
}

class DiaryGraphData {
  final List<DiaryGraphNode> nodes;
  final Int32List edges;

  final int? centerIndex;

  const DiaryGraphData({
    required this.nodes,
    required this.edges,
    this.centerIndex,
  });

  bool get isEmpty => nodes.isEmpty;
  int get nodeCount => nodes.length;
  int get edgeCount => edges.length ~/ 2;
}
