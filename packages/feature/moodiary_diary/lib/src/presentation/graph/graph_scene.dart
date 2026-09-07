import 'dart:math' as math;
import 'dart:typed_data';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

class GraphBatch {
  final int start;
  final int end;
  final double radius;
  final Color color;

  const GraphBatch(this.start, this.end, this.radius, this.color);
}

class GraphScene {
  final DiaryGraphData data;

  final Int32List adjOffsets;
  final Int32List adjTargets;

  final Int32List undirectedEdges;

  final Float32List radii;
  final List<Color> colors;

  final Int32List drawOrder;

  final Int32List orderOf;
  final List<GraphBatch> fillBatches;
  final List<GraphBatch> ringBatches;

  final Int32List labelOrder;

  final int? centerIndex;

  const GraphScene._({
    required this.data,
    required this.adjOffsets,
    required this.adjTargets,
    required this.undirectedEdges,
    required this.radii,
    required this.colors,
    required this.drawOrder,
    required this.orderOf,
    required this.fillBatches,
    required this.ringBatches,
    required this.labelOrder,
    required this.centerIndex,
  });

  int get nodeCount => data.nodeCount;
  int get edgeCount => data.edgeCount;
  Int32List get edges => data.edges;
  List<DiaryGraphNode> get nodes => data.nodes;
  bool get isEmpty => data.nodes.isEmpty;

  int degreeOf(int i) => adjOffsets[i + 1] - adjOffsets[i];

  Int32List neighborsOf(int i) =>
      .sublistView(adjTargets, adjOffsets[i], adjOffsets[i + 1]);

  bool isNeighbor(int i, int j) {
    for (var k = adjOffsets[i]; k < adjOffsets[i + 1]; k++) {
      if (adjTargets[k] == j) return true;
    }
    return false;
  }

  static GraphScene build({
    required DiaryGraphData data,
    required List<Category> categories,
    required GraphPalette palette,
    required GraphColorMode mode,
  }) {
    final n = data.nodeCount;
    final (offsets, targets) = _buildCsr(n, data.edges);
    final undirected = _undirected(offsets, targets);

    final degrees = Int32List(n);
    for (var i = 0; i < n; i++) {
      degrees[i] = offsets[i + 1] - offsets[i];
    }
    final cap = _percentile95(degrees).clamp(4, 24);

    final radii = Float32List(n);
    for (var i = 0; i < n; i++) {
      radii[i] = GraphTuning.radiusOf(degrees[i], cap);
    }
    if (data.centerIndex != null && data.centerIndex! < n) {
      radii[data.centerIndex!] = GraphTuning.centerRadius;
    }

    final colors = _resolveColors(data, categories, palette, mode);
    final (order, fills, rings) = _batch(n, radii, colors);
    final orderOf = Int32List(n);
    for (var k = 0; k < n; k++) {
      orderOf[order[k]] = k;
    }

    final labelOrder = Int32List.fromList(
      List<int>.generate(n, (i) => i)..sort((a, b) {
        if (a == data.centerIndex) return -1;
        if (b == data.centerIndex) return 1;
        final c = degrees[b].compareTo(degrees[a]);
        return c != 0 ? c : a.compareTo(b);
      }),
    );

    return ._(
      data: data,
      adjOffsets: offsets,
      adjTargets: targets,
      undirectedEdges: undirected,
      radii: radii,
      colors: colors,
      drawOrder: order,
      orderOf: orderOf,
      fillBatches: fills,
      ringBatches: rings,
      labelOrder: labelOrder,
      centerIndex: data.centerIndex,
    );
  }

  static (Int32List, Int32List) _buildCsr(int n, Int32List edges) {
    if (n == 0) return (Int32List(1), Int32List(0));
    final packed = Int64List(edges.length);
    var w = 0;
    for (var e = 0; e + 1 < edges.length; e += 2) {
      final a = edges[e], b = edges[e + 1];
      if (a == b || a < 0 || b < 0 || a >= n || b >= n) continue;
      packed[w++] = a * n + b;
      packed[w++] = b * n + a;
    }
    final keys = Int64List.sublistView(packed, 0, w)..sort();

    final offsets = Int32List(n + 1);
    var prev = -1, unique = 0;
    for (var i = 0; i < w; i++) {
      if (keys[i] == prev) continue;
      prev = keys[i];
      offsets[keys[i] ~/ n + 1]++;
      unique++;
    }
    for (var i = 0; i < n; i++) {
      offsets[i + 1] += offsets[i];
    }
    final targets = Int32List(unique);
    prev = -1;
    var k = 0;
    for (var i = 0; i < w; i++) {
      if (keys[i] == prev) continue;
      prev = keys[i];
      targets[k++] = keys[i] % n;
    }
    return (offsets, targets);
  }

  static Int32List _undirected(Int32List offsets, Int32List targets) {
    final n = offsets.length - 1;
    final out = Int32List(targets.length);
    var w = 0;
    for (var a = 0; a < n; a++) {
      for (var k = offsets[a]; k < offsets[a + 1]; k++) {
        final b = targets[k];
        if (b > a) {
          out[w++] = a;
          out[w++] = b;
        }
      }
    }
    return .sublistView(out, 0, w);
  }

  static int _percentile95(Int32List degrees) {
    if (degrees.isEmpty) return 1;
    final sorted = Int32List.fromList(degrees)..sort();
    final idx = ((sorted.length - 1) * 0.95).round();
    return sorted[idx];
  }

  static List<Color> _resolveColors(
    DiaryGraphData data,
    List<Category> categories,
    GraphPalette palette,
    GraphColorMode mode,
  ) {
    final n = data.nodeCount;
    switch (mode) {
      case .plain:
        return List<Color>.filled(n, palette.fallbackNode);
      case .time:
        var min = double.infinity, max = -double.infinity;
        for (final node in data.nodes) {
          final ms = node.time.millisecondsSinceEpoch.toDouble();
          if (ms < min) min = ms;
          if (ms > max) max = ms;
        }
        final span = max - min;
        final base = HSLColor.fromColor(palette.fallbackNode);
        return [
          for (final node in data.nodes)
            () {
              final t = span <= 0
                  ? 1.0
                  : (node.time.millisecondsSinceEpoch - min) / span;
              final l = palette.isDark
                  ? lerpDouble(0.42, 0.78, t)
                  : lerpDouble(0.72, 0.42, t);
              return base.withLightness(l).toColor();
            }(),
        ];
      case .category:
        final byId = <String, Color>{
          for (final c in categories)
            c.id: categoryColorOf(
              colorValue: c.color,
              id: c.id,
            ).harmonizeWith(palette.fallbackNode),
        };
        return [
          for (final node in data.nodes)
            byId[node.categoryId] ?? palette.fallbackNode,
        ];
    }
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  static (Int32List, List<GraphBatch>, List<GraphBatch>) _batch(
    int n,
    Float32List radii,
    List<Color> colors,
  ) {
    if (n == 0) return (Int32List(0), const [], const []);
    const buckets = 8;
    const span = GraphTuning.nodeRadiusMax - GraphTuning.nodeRadiusMin;
    final bucket = Int32List(n);
    for (var i = 0; i < n; i++) {
      bucket[i] = radii[i] > GraphTuning.nodeRadiusMax
          ? buckets
          : ((((radii[i] - GraphTuning.nodeRadiusMin) / span).clamp(0.0, 1.0)) *
                    (buckets - 1))
                .round();
    }
    final argb = Int32List(n);
    for (var i = 0; i < n; i++) {
      argb[i] = colors[i].toARGB32();
    }

    final order = Int32List.fromList(
      List<int>.generate(n, (i) => i)..sort((a, b) {
        final c = bucket[a].compareTo(bucket[b]);
        if (c != 0) return c;
        final ca = argb[a].compareTo(argb[b]);
        return ca != 0 ? ca : a.compareTo(b);
      }),
    );

    final fills = <GraphBatch>[];
    final rings = <GraphBatch>[];
    var ringStart = 0, fillStart = 0;
    for (var i = 1; i <= n; i++) {
      final atEnd = i == n;
      final ringBreak = atEnd || bucket[order[i]] != bucket[order[ringStart]];
      final fillBreak =
          atEnd ||
          bucket[order[i]] != bucket[order[fillStart]] ||
          argb[order[i]] != argb[order[fillStart]];
      if (fillBreak) {
        fills.add(
          GraphBatch(
            fillStart,
            i,
            _meanRadius(order, radii, fillStart, i),
            colors[order[fillStart]],
          ),
        );
        fillStart = i;
      }
      if (ringBreak) {
        rings.add(
          GraphBatch(
            ringStart,
            i,
            _meanRadius(order, radii, ringStart, i),
            const Color(0x00000000),
          ),
        );
        ringStart = i;
      }
    }
    return (order, fills, rings);
  }

  static double _meanRadius(
    Int32List order,
    Float32List radii,
    int start,
    int end,
  ) {
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += radii[order[i]];
    }
    return sum / (end - start);
  }
}

String graphNodeLabel(DiaryGraphNode node) {
  final title = node.title.trim();
  if (title.isNotEmpty) return _clipChars(title, GraphTuning.labelMaxChars);
  final body = node.preview?.trim() ?? '';
  if (body.isNotEmpty) return _clipChars(body, GraphTuning.labelMaxCharsBody);
  final t = node.time.toLocal();
  return '${_two(t.month)}-${_two(t.day)}';
}

String _clipChars(String s, int max) {
  final chars = s.characters;
  return chars.length <= max ? s : '${chars.take(max)}…';
}

String _two(int v) => v < 10 ? '0$v' : '$v';

final emptyGraphData = DiaryGraphData(nodes: const [], edges: Int32List(0));

DiaryGraphData filterGraph(
  DiaryGraphData full, {
  String? categoryId,
  DateTimeRange? range,
}) {
  if (categoryId == null && range == null) return full;

  bool keep(DiaryGraphNode n) {
    if (categoryId != null && n.categoryId != categoryId) return false;
    if (range != null) {
      final t = n.time.toLocal();
      if (t.isBefore(range.start) || t.isAfter(range.end)) return false;
    }
    return true;
  }

  final keptEdges = <int>[];
  final endpoints = <int>{};
  for (var e = 0; e < full.edgeCount; e++) {
    final a = full.edges[e * 2], b = full.edges[e * 2 + 1];
    if (keep(full.nodes[a]) && keep(full.nodes[b])) {
      keptEdges
        ..add(a)
        ..add(b);
      endpoints
        ..add(a)
        ..add(b);
    }
  }
  if (keptEdges.isEmpty) return emptyGraphData;
  final oldSorted = endpoints.toList()..sort();
  final newIndex = {for (var i = 0; i < oldSorted.length; i++) oldSorted[i]: i};
  final nodes = [
    for (var i = 0; i < oldSorted.length; i++)
      _reindex(full.nodes[oldSorted[i]], i),
  ];
  final edges = Int32List(keptEdges.length);
  for (var i = 0; i < keptEdges.length; i++) {
    edges[i] = newIndex[keptEdges[i]]!;
  }
  return DiaryGraphData(nodes: nodes, edges: edges);
}

DiaryGraphNode _reindex(DiaryGraphNode n, int i) => DiaryGraphNode(
  index: i,
  id: n.id,
  title: n.title,
  time: n.time,
  categoryId: n.categoryId,
  depth: n.depth,
  preview: n.preview,
);

const _goldenAngle = 2.3999632;

Float32List seedByBfs(GraphScene scene, double springLength) {
  final n = scene.nodeCount;
  final pos = Float32List(n * 2);
  if (n == 0) return pos;

  final visited = Uint8List(n);
  final ring = springLength * 0.85;
  var compOffsetX = 0.0, compOffsetY = 0.0, compIndex = 0, compRadiusAcc = 0.0;

  final byDegree = scene.labelOrder;

  for (final root in byDegree) {
    if (visited[root] == 1) continue;

    final layers = <List<int>>[
      [root],
    ];
    visited[root] = 1;
    var frontier = <int>[root];
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final u in frontier) {
        for (var k = scene.adjOffsets[u]; k < scene.adjOffsets[u + 1]; k++) {
          final v = scene.adjTargets[k];
          if (visited[v] == 1) continue;
          visited[v] = 1;
          next.add(v);
        }
      }
      if (next.isEmpty) break;
      layers.add(next);
      frontier = next;
    }

    final compRadius = ring * (layers.length - 1) + GraphTuning.nodeRadiusMax;
    if (compIndex > 0) {
      compRadiusAcc += compRadius * 0.9;
      final a = compIndex * _goldenAngle;
      compOffsetX = compRadiusAcc * math.cos(a);
      compOffsetY = compRadiusAcc * math.sin(a);
    }

    for (var d = 0; d < layers.length; d++) {
      final layer = layers[d];
      final r = ring * d;
      if (d == 0) {
        pos[layer[0] * 2] = compOffsetX;
        pos[layer[0] * 2 + 1] = compOffsetY;
        continue;
      }
      final phase = d * _goldenAngle;
      for (var i = 0; i < layer.length; i++) {
        final a = phase + 2 * math.pi * i / layer.length;
        pos[layer[i] * 2] = compOffsetX + r * math.cos(a);
        pos[layer[i] * 2 + 1] = compOffsetY + r * math.sin(a);
      }
    }
    compIndex++;
  }
  return pos;
}

enum EgoDirection { outgoing, incoming, mutual }

List<EgoDirection?> egoDirectionsOf(GraphScene scene) {
  final n = scene.nodeCount;
  final dirs = List<EgoDirection?>.filled(n, null);
  final center = scene.centerIndex;
  if (center == null) return dirs;
  final out = List<bool>.filled(n, false), inc = List<bool>.filled(n, false);
  for (var e = 0; e < scene.edgeCount; e++) {
    final a = scene.edges[e * 2], b = scene.edges[e * 2 + 1];
    if (a == center && b != center) out[b] = true;
    if (b == center && a != center) inc[a] = true;
  }
  for (var i = 0; i < n; i++) {
    if (i == center) continue;
    if (out[i] && inc[i]) {
      dirs[i] = .mutual;
    } else if (out[i]) {
      dirs[i] = .outgoing;
    } else if (inc[i]) {
      dirs[i] = .incoming;
    }
  }
  return dirs;
}

({Float32List positions, List<EgoDirection?> dirs, double outerRadius})
layoutEgoRadial(GraphScene scene) {
  final n = scene.nodeCount;
  final pos = Float32List(n * 2);
  final dirs = List<EgoDirection?>.filled(n, null);
  final center = scene.centerIndex;
  if (n == 0 || center == null) {
    return (positions: pos, dirs: dirs, outerRadius: 1);
  }

  final out = <int>{}, inc = <int>{};
  for (var e = 0; e < scene.edgeCount; e++) {
    final a = scene.edges[e * 2], b = scene.edges[e * 2 + 1];
    if (a == center && b != center) out.add(b);
    if (b == center && a != center) inc.add(a);
  }

  final first = <int>[], second = <int>[];
  for (var i = 0; i < n; i++) {
    if (i == center) continue;
    final d = scene.nodes[i].depth ?? (scene.isNeighbor(i, center) ? 1 : 2);
    (d <= 1 ? first : second).add(i);
  }

  final mutualList = <int>[], outList = <int>[], inList = <int>[];
  for (final i in first) {
    final o = out.contains(i), n2 = inc.contains(i);
    final dir = o && n2
        ? EgoDirection.mutual
        : (o ? EgoDirection.outgoing : EgoDirection.incoming);
    dirs[i] = dir;
    switch (dir) {
      case .mutual:
        mutualList.add(i);
      case .outgoing:
        outList.add(i);
      case .incoming:
        inList.add(i);
    }
  }

  final n1 = first.length;
  final r1 = (110.0 + 12.0 * n1).clamp(150.0, 420.0);

  final angles = List<double>.filled(n, 0);
  var outer = r1;
  void place(List<int> group, double centerDeg, double halfDeg, double radius) {
    if (group.isEmpty) return;
    final c = centerDeg * math.pi / 180, h = halfDeg * math.pi / 180;
    final gap = group.length > 1 ? 2 * h / group.length : math.pi;
    final split = gap < 18 * math.pi / 180 && group.length > 3;
    for (var i = 0; i < group.length; i++) {
      final a = group.length == 1
          ? c
          : c - h + 2 * h * (i + 0.5) / group.length;
      final r = split && i.isOdd ? radius * 1.32 : radius;
      if (r > outer) outer = r;
      angles[group[i]] = a;
      pos[group[i] * 2] = r * math.cos(a);
      pos[group[i] * 2 + 1] = r * math.sin(a);
    }
  }

  // 屏幕坐标 y 向下：-90° = 正上方。
  place(outList, 0, 65, r1);
  place(inList, 180, 65, r1);
  place(mutualList, -90, 22, r1);

  if (second.isNotEmpty) {
    final want = <int, double>{};
    for (final i in second) {
      var a = 0.0;
      for (var k = scene.adjOffsets[i]; k < scene.adjOffsets[i + 1]; k++) {
        final p = scene.adjTargets[k];
        if (p != center && (scene.nodes[p].depth ?? 2) <= 1) {
          a = angles[p];
          break;
        }
      }
      want[i] = a;
    }
    second.sort((a, b) => want[a]!.compareTo(want[b]!));
    final minGap = math.min(2 * math.pi / second.length, 22 * math.pi / 180);
    final r2 = r1 * 1.95;
    var prev = -double.infinity;
    for (var i = 0; i < second.length; i++) {
      final a = i == 0
          ? want[second[0]]!
          : math.max(want[second[i]]!, prev + minGap);
      prev = a;
      pos[second[i] * 2] = r2 * math.cos(a);
      pos[second[i] * 2 + 1] = r2 * math.sin(a);
    }
    if (prev - want[second[0]]! > 2 * math.pi - minGap) {
      for (var i = 0; i < second.length; i++) {
        final a = want[second[0]]! + 2 * math.pi * i / second.length;
        pos[second[i] * 2] = r2 * math.cos(a);
        pos[second[i] * 2 + 1] = r2 * math.sin(a);
      }
    }
    outer = r2;
  }
  return (positions: pos, dirs: dirs, outerRadius: outer);
}
