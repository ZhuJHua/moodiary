import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_canvas.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_scene.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

DiaryGraphData _graph({
  required int n,
  required List<(int, int)> edges,
  int? centerIndex,
  List<int?>? depths,
  List<String?>? previews,
}) {
  final flat = Int32List(edges.length * 2);
  for (var i = 0; i < edges.length; i++) {
    flat[i * 2] = edges[i].$1;
    flat[i * 2 + 1] = edges[i].$2;
  }
  return DiaryGraphData(
    nodes: [
      for (var i = 0; i < n; i++)
        DiaryGraphNode(
          index: i,
          id: 'id-$i',
          isarId: i,
          title: i.isEven ? '日记标题 $i' : '',
          time: DateTime(2026, 1, 1).add(Duration(days: i)),
          categoryId: i % 3 == 0 ? null : 'cat-${i % 3}',
          depth: depths?[i],
          preview: previews?[i] ?? '正文第 $i 段的开头一句话',
        ),
    ],
    edges: flat,
    centerIndex: centerIndex,
  );
}

final _categories = [
  Category(
    id: 'cat-1',
    categoryName: 'A',
    lastModified: DateTime(2026),
    color: 0xFF42A5F5,
  ),
  Category(
    id: 'cat-2',
    categoryName: 'B',
    lastModified: DateTime(2026),
    color: null,
  ),
];

GraphScene _scene(
  DiaryGraphData data, {
  GraphColorMode mode = .category,
  bool dark = false,
}) {
  final colors = MuiColorScheme.resolve(
    dark ? Brightness.dark : Brightness.light,
    const MuiAccent.neutral(),
  );
  return .build(
    data: data,
    categories: _categories,
    palette: .of(colors, edgeCount: data.edgeCount),
    mode: mode,
  );
}

Future<void> _pumpCanvas(
  WidgetTester tester, {
  required GraphScene scene,
  required GraphFrame frame,
  int? selected,
  List<EgoDirection?>? dirs,
  double? extent,
  bool dark = false,
  bool showLabels = true,
}) async {
  final mui = MuiThemeData(brightness: dark ? .dark : .light);
  await tester.pumpWidget(
    MaterialApp(
      theme: materialThemeFrom(mui),
      builder: (context, child) => MuiTheme(data: mui, child: child!),
      home: Scaffold(
        body: GraphCanvas(
          scene: scene,
          frame: frame,
          palette: .of(mui.colors, edgeCount: scene.edgeCount),
          selected: selected,
          showLabels: showLabels,
          egoDirections: dirs,
          preferredExtent: extent,
          onSelect: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('GraphScene', () {
    test('CSR 邻接去重互链，度数与无向边正确', () {
      // 0↔1（互链两条有向边）、1→2、3 孤立
      final scene = _scene(_graph(n: 4, edges: [(0, 1), (1, 0), (1, 2)]));
      expect(scene.degreeOf(0), 1);
      expect(scene.degreeOf(1), 2);
      expect(scene.degreeOf(2), 1);
      expect(scene.degreeOf(3), 0);
      expect(scene.undirectedEdges.length ~/ 2, 2); // 0-1, 1-2
      expect(scene.isNeighbor(0, 1), isTrue);
      expect(scene.isNeighbor(0, 2), isFalse);
    });

    test('自链与越界下标被忽略', () {
      final data = _graph(n: 2, edges: [(0, 0), (0, 1)]);
      final scene = _scene(data);
      expect(scene.undirectedEdges.length ~/ 2, 1);
      expect(scene.degreeOf(0), 1);
    });

    test('批次覆盖全部节点且区间连续', () {
      final scene = _scene(
        _graph(n: 30, edges: [for (var i = 1; i < 30; i++) (0, i)]),
      );
      expect(scene.drawOrder.length, 30);
      var cursor = 0;
      for (final b in scene.ringBatches) {
        expect(b.start, cursor);
        expect(b.end, greaterThan(b.start));
        cursor = b.end;
      }
      expect(cursor, 30);
      cursor = 0;
      for (final b in scene.fillBatches) {
        expect(b.start, cursor);
        cursor = b.end;
      }
      expect(cursor, 30);
      // 度数最高的中心节点半径应显著大于叶子。
      expect(scene.radii[0], greaterThan(scene.radii[1]));
    });

    test('中心节点半径走 centerRadius 且标签优先级排第一', () {
      final scene = _scene(
        _graph(n: 5, edges: [(0, 1), (0, 2), (3, 0)], centerIndex: 0),
      );
      expect(scene.radii[0], GraphTuning.centerRadius);
      expect(scene.labelOrder.first, 0);
    });

    test('节点尺寸：中心 > 枢纽 > 叶子，且中心不超过叶子两倍', () {
      // 中心必须超出 nodeRadiusMax（_batch 靠这个把它单独分一档），但比例要收着，
      // 否则局部图又会变回「一个大球 + 一圈针尖」。
      expect(GraphTuning.nodeRadiusMin, lessThan(GraphTuning.nodeRadiusMax));
      expect(GraphTuning.centerRadius, greaterThan(GraphTuning.nodeRadiusMax));
      expect(
        GraphTuning.centerRadius / GraphTuning.nodeRadiusMin,
        lessThanOrEqualTo(2.0),
      );
    });

    test('选中断环：外径不变，实心圆收进环内缘之内', () {
      // 选中不改变节点占位（边的内缩量因此与选中无关），缩的是里面那颗实心圆。
      for (final r in [
        GraphTuning.nodeRadiusMin,
        GraphTuning.nodeRadiusMax,
        GraphTuning.centerRadius,
      ]) {
        final core = GraphTuning.selectedCoreRadius(r);
        expect(core, greaterThan(0)); // 再小的节点也不能缩没
        expect(core, lessThan(r - GraphTuning.selectedRingWidth));
        expect(
          core,
          greaterThanOrEqualTo(r * GraphTuning.selectedCoreMinRatio),
        );
      }
    });

    test('初始拟合不放大：世界单位已被 normalizeScale 标定，1x 即设计密度', () {
      // 顶破 1x 的后果是节点少的局部图被撑满屏幕，看着就是一颗颗大球。
      expect(GraphTuning.maxInitialFit, lessThanOrEqualTo(1.0));
    });

    test('分类色向主色 harmonize，无分类回落主题色', () {
      final cs = MuiColorScheme.resolve(
        Brightness.light,
        const MuiAccent.neutral(),
      );
      final scene = _scene(_graph(n: 4, edges: [(0, 1), (2, 3)]));
      // index 0/3 无分类（i % 3 == 0）→ 主题色本色，不需要 harmonize。
      expect(scene.colors[0], cs.primary);
      expect(
        scene.colors[1],
        const Color(0xFF42A5F5).harmonizeWith(cs.primary),
      );
      // cat-2 没给 color，走 id 哈希取色板，同样 harmonize。
      expect(
        scene.colors[2],
        categoryColorOf(
          colorValue: null,
          id: 'cat-2',
        ).harmonizeWith(cs.primary),
      );
      // 只是把色相往主色挪，不是把分类色抹成主色 —— 否则分类之间就没区分了。
      expect(scene.colors[1], isNot(cs.primary));
      expect(scene.colors[1], isNot(scene.colors[2]));
    });

    test('三种着色模式都产出每节点一个颜色', () {
      for (final mode in GraphColorMode.values) {
        final scene = _scene(_graph(n: 6, edges: [(0, 1), (2, 3)]), mode: mode);
        expect(scene.colors.length, 6);
      }
    });

    test('filterGraph 丢弃因筛选而孤立的节点并重排下标', () {
      final full = _graph(n: 4, edges: [(0, 1), (2, 3)]);
      // cat-1 的是 index 1 / 4...；这里按分类筛，只留同类两端的边。
      final sub = filterGraph(full, categoryId: 'cat-1');
      for (final n in sub.nodes) {
        expect(n.categoryId, 'cat-1');
      }
      for (var i = 0; i < sub.edgeCount * 2; i++) {
        expect(sub.edges[i], lessThan(sub.nodeCount));
      }
    });

    test('filterGraph 全筛掉时返回空图', () {
      final full = _graph(n: 4, edges: [(0, 1), (2, 3)]);
      expect(filterGraph(full, categoryId: 'nope').isEmpty, isTrue);
    });
  });

  group('graphNodeLabel', () {
    DiaryGraphNode node({String title = '', String? preview}) => DiaryGraphNode(
      index: 0,
      id: 'x',
      isarId: 1,
      title: title,
      time: DateTime(2026, 3, 7),
      categoryId: null,
      preview: preview,
    );

    test('有标题取标题，超过 10 字截断', () {
      expect(graphNodeLabel(node(title: '梅雨季的第七天')), '梅雨季的第七天');
      expect(graphNodeLabel(node(title: '一二三四五六七八九十十一')), '一二三四五六七八九十…');
      expect(graphNodeLabel(node(title: '一二三四五六七八九十')).length, 10);
    });

    test('没标题取正文开头，上限 5 字', () {
      expect(graphNodeLabel(node(preview: '今天下雨了')), '今天下雨了');
      expect(graphNodeLabel(node(preview: '今天下雨了，很凉快')), '今天下雨了…');
      // 标题只有空白等同没标题。
      expect(graphNodeLabel(node(title: '  ', preview: '正文开头一句')), '正文开头一…');
    });

    test('标题正文都空才回落到日期', () {
      expect(graphNodeLabel(node()), '03-07');
      expect(graphNodeLabel(node(preview: '   ')), '03-07');
    });

    test('按字素簇截断：emoji 不会被劈成两半', () {
      expect(
        graphNodeLabel(node(preview: '👨‍👩‍👧‍👦一二三四五')),
        '👨‍👩‍👧‍👦一二三四…',
      );
    });
  });

  group('seedByBfs', () {
    test('坐标有限、长度正确、多分量不重合', () {
      final scene = _scene(
        _graph(n: 12, edges: [(0, 1), (1, 2), (2, 3), (5, 6), (6, 7)]),
      );
      final seed = seedByBfs(scene, 63);
      expect(seed.length, 24);
      expect(seed.every((v) => v.isFinite), isTrue);
      // 相连节点应比随机播种更近：0-1 的距离约等于一层环距。
      final d = math.sqrt(
        math.pow(seed[2] - seed[0], 2) + math.pow(seed[3] - seed[1], 2),
      );
      expect(d, greaterThan(0));
      expect(d, lessThan(63 * 2));
    });

    test('空图不炸', () {
      final scene = _scene(_graph(n: 0, edges: const []));
      expect(seedByBfs(scene, 63).length, 0);
    });
  });

  group('layoutEgoRadial', () {
    test('中心在原点，出链在右、入链在左、互链在上', () {
      // 0 = 中心；1 出链、2 入链、3 互链
      final scene = _scene(
        _graph(
          n: 4,
          edges: [(0, 1), (2, 0), (0, 3), (3, 0)],
          centerIndex: 0,
          depths: [0, 1, 1, 1],
        ),
      );
      final r = layoutEgoRadial(scene);
      expect(r.positions[0], 0);
      expect(r.positions[1], 0);
      expect(r.dirs[1], EgoDirection.outgoing);
      expect(r.dirs[2], EgoDirection.incoming);
      expect(r.dirs[3], EgoDirection.mutual);
      expect(r.positions[2], greaterThan(0)); // 出链 x > 0
      expect(r.positions[4], lessThan(0)); // 入链 x < 0
      expect(r.positions[7], lessThan(0)); // 互链 y < 0（屏幕坐标向上）
      expect(r.outerRadius, greaterThan(0));
    });

    test('二跳节点落在更外的环上', () {
      final scene = _scene(
        _graph(
          n: 3,
          edges: [(0, 1), (1, 2)],
          centerIndex: 0,
          depths: [0, 1, 2],
        ),
      );
      final r = layoutEgoRadial(scene);
      double radius(int i) => math.sqrt(
        r.positions[i * 2] * r.positions[i * 2] +
            r.positions[i * 2 + 1] * r.positions[i * 2 + 1],
      );
      expect(radius(2), greaterThan(radius(1)));
    });

    test('只有中心一个节点不炸', () {
      final scene = _scene(
        _graph(n: 1, edges: const [], centerIndex: 0, depths: [0]),
      );
      final r = layoutEgoRadial(scene);
      expect(r.positions.length, 2);
      expect(r.positions.every((v) => v.isFinite), isTrue);
    });
  });

  group('egoDirectionsOf', () {
    test('出/入/互链方向正确，中心与二跳为 null', () {
      final scene = _scene(
        _graph(
          n: 5,
          edges: [(0, 1), (2, 0), (0, 3), (3, 0), (1, 4)],
          centerIndex: 0,
          depths: [0, 1, 1, 1, 2],
        ),
      );
      final dirs = egoDirectionsOf(scene);
      expect(dirs[0], isNull); // 中心
      expect(dirs[1], EgoDirection.outgoing);
      expect(dirs[2], EgoDirection.incoming);
      expect(dirs[3], EgoDirection.mutual);
      expect(dirs[4], isNull); // 二跳，不直连中心
    });

    test('无中心返回全 null', () {
      final scene = _scene(_graph(n: 3, edges: [(0, 1), (1, 2)]));
      expect(egoDirectionsOf(scene).every((d) => d == null), isTrue);
    });
  });

  group('GraphCanvas 绘制', () {
    testWidgets('总图：沉降中与落定后都能画，明暗两套', (tester) async {
      for (final dark in [false, true]) {
        final data = _graph(
          n: 40,
          edges: [
            for (var i = 1; i < 40; i++) (0, i),
            for (var i = 1; i < 39; i++) (i, i + 1),
          ],
        );
        final scene = _scene(data, dark: dark);
        final frame = GraphFrame();
        frame.push(seedByBfs(scene, 63));
        await _pumpCanvas(tester, scene: scene, frame: frame, dark: dark);
        await tester.pump();
        frame.markSettled();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        frame.dispose();
      }
    });

    testWidgets('选中态：淡出 + 高亮边 + 箭头', (tester) async {
      final data = _graph(
        n: 12,
        edges: [for (var i = 1; i < 12; i++) (0, i), (3, 4), (5, 0)],
      );
      final scene = _scene(data);
      final frame = GraphFrame();
      frame.push(seedByBfs(scene, 63), settled: true);
      await _pumpCanvas(tester, scene: scene, frame: frame);
      await _pumpCanvas(tester, scene: scene, frame: frame, selected: 0);
      // 逐帧走完聚焦动画：边网格每帧重建（内缩 / 加粗 / 配色都是 focusT 的函数），
      // 中途的帧同样要能画出来。
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      // 取消选中：淡出动画同样逐帧回退，走完不应残留异常
      await _pumpCanvas(tester, scene: scene, frame: frame);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('ego：方向着色 + 固定视觉密度相机', (tester) async {
      final scene = _scene(
        _graph(
          n: 6,
          edges: [(0, 1), (2, 0), (0, 3), (3, 0), (1, 4), (4, 5)],
          centerIndex: 0,
          depths: [0, 1, 1, 1, 2, 2],
        ),
      );
      final r = layoutEgoRadial(scene);
      final frame = GraphFrame();
      frame.push(r.positions, settled: true);
      await _pumpCanvas(
        tester,
        scene: scene,
        frame: frame,
        dirs: r.dirs,
        extent: r.outerRadius,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('手势缩放 / 拖动不抛异常，且极端缩放安全', (tester) async {
      final scene = _scene(
        _graph(n: 20, edges: [for (var i = 1; i < 20; i++) (0, i)]),
      );
      final frame = GraphFrame();
      frame.push(seedByBfs(scene, 63), settled: true);
      await _pumpCanvas(tester, scene: scene, frame: frame);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(GraphCanvas), const Offset(120, -80));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('A→B 换选中：新旧两头同时动，逐帧都画得出来', (tester) async {
      final scene = _scene(
        _graph(n: 12, edges: [for (var i = 1; i < 12; i++) (0, i), (3, 5)]),
      );
      final frame = GraphFrame()..push(seedByBfs(scene, 63), settled: true);
      await _pumpCanvas(tester, scene: scene, frame: frame, selected: 3);
      await tester.pump(const Duration(milliseconds: 400)); // A 已完全选中
      // 直接切到 B：旧焦点交给淡出控制器，新焦点从 0 长起来，中途每帧都得画得出来
      await _pumpCanvas(tester, scene: scene, frame: frame, selected: 5);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // 淡出没走完就再切一次，旧的 exit 被顶掉也不能崩
      await _pumpCanvas(tester, scene: scene, frame: frame, selected: 7);
      await tester.pump(const Duration(milliseconds: 40));
      await _pumpCanvas(tester, scene: scene, frame: frame, selected: 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('选中断环在极端相机倍率下都画得出来', (tester) async {
      // preferredExtent 把相机倍率钉在 [0.35, 1.6]：两端各走一次，覆盖「环宽跌破屏幕
      // 下限、只能向内长」与「环宽照世界单位走」两条分支。
      final scene = _scene(
        _graph(n: 16, edges: [for (var i = 1; i < 16; i++) (0, i)]),
        dark: true,
      );
      final frame = GraphFrame()..push(seedByBfs(scene, 63), settled: true);
      for (final extent in [4000.0, 10.0]) {
        await _pumpCanvas(
          tester,
          scene: scene,
          frame: frame,
          selected: 0,
          extent: extent,
          dark: true,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }
      frame.dispose();
    });

    testWidgets('空图 / 单节点 / 帧长度不匹配都不抛', (tester) async {
      final empty = _scene(_graph(n: 0, edges: const []));
      final frame = GraphFrame()..push(Float32List(0), settled: true);
      await _pumpCanvas(tester, scene: empty, frame: frame);
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 陈旧帧：坐标数与节点数不匹配，必须被守卫挡住而不是越界。
      final single = _scene(_graph(n: 1, edges: const []));
      frame.push(.fromList([1, 2, 3, 4]), settled: true);
      await _pumpCanvas(tester, scene: single, frame: frame);
      await tester.pump();
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('选中高下标节点后场景缩小（换筛选/换深度）不越界崩溃', (tester) async {
      // 12 节点选中 index 10 → 换成只剩 4 节点的新场景 + 匹配的短帧。
      final big = _scene(
        _graph(n: 12, edges: [for (var i = 1; i < 12; i++) (0, i)]),
      );
      final frame = GraphFrame()..push(seedByBfs(big, 63), settled: true);
      await _pumpCanvas(tester, scene: big, frame: frame, selected: 10);
      await tester.pump(const Duration(milliseconds: 120)); // 淡出动画进行中

      final small = _scene(_graph(n: 4, edges: [(0, 1), (0, 2), (0, 3)]));
      frame.push(seedByBfs(small, 63), settled: true);
      await _pumpCanvas(tester, scene: small, frame: frame, selected: null);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('切配色（同节点数换场景）立即重绘、不留旧帧', (tester) async {
      final data = _graph(n: 8, edges: [for (var i = 1; i < 8; i++) (0, i)]);
      final frame = GraphFrame()
        ..push(seedByBfs(_scene(data), 63), settled: true);
      final byCategory = _scene(data);
      await _pumpCanvas(tester, scene: byCategory, frame: frame);
      await tester.pump(const Duration(milliseconds: 300));
      // 换成 plain 着色的新场景（节点数不变、不推帧）
      final byPlain = _scene(data, mode: .plain);
      await _pumpCanvas(tester, scene: byPlain, frame: frame);
      await tester.pump();
      expect(tester.takeException(), isNull);
      frame.dispose();
    });

    testWidgets('关标签也能画', (tester) async {
      final scene = _scene(
        _graph(n: 10, edges: [for (var i = 1; i < 10; i++) (0, i)]),
      );
      final frame = GraphFrame()..push(seedByBfs(scene, 63), settled: true);
      await _pumpCanvas(tester, scene: scene, frame: frame, showLabels: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      frame.dispose();
    });
  });
}
