import 'dart:typed_data';

/// 知识图谱的一个节点(一篇至少有一条双链的日记)。[index] 是密集下标,对应
/// [DiaryGraphData.edges] 里的编号,以及 Rust 布局回传坐标数组 `[x0,y0,x1,y1,...]`
/// 中第 `index` 个点的位置。
class DiaryGraphNode {
  final int index;
  final String id;
  final String title;
  final DateTime time;
  final String? categoryId;

  /// ego 图专用:到中心节点的 BFS 跳数(0 = 中心)。全图恒 null。
  final int? depth;

  /// 正文摘要:纯文本折叠空白后的开头一小截(装配时就截断,整篇正文不进内存)。
  /// 无标题的节点靠它显示标签;正文也为空则为 null。
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

/// 只含有链接日记的图。[edges] 是**有向**密集下标对 `[src0,dst0,src1,dst1,...]`(srcN→dstN
/// 即"srcN 的正文链接到 dstN"),供 UI 画箭头;A↔B 互链为两条。可直接喂给 Rust 布局引擎
/// (力导向按无向弹簧处理,方向不影响布局)。节点顺序即下标,坐标数组与之一一对应。
class DiaryGraphData {
  final List<DiaryGraphNode> nodes;
  final Int32List edges;

  /// ego 图专用:中心节点在 [nodes] 里的下标(排序保证恒为 0)。全图恒 null。
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
