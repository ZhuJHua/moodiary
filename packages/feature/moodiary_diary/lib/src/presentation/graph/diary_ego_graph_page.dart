import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:moodiary_diary/src/presentation/graph/graph_canvas.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_info_card.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_scene.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';

part 'diary_ego_graph_page.g.dart';

/// 以某篇日记为中心的 k 跳邻域。全程主键批量 get（见 [DiaryRepository.buildEgoGraph]），
/// 成本随邻域规模增长、与总日记数无关，所以详情页高频进出也不心疼。
@riverpod
Future<DiaryGraphData> diaryEgoGraph(Ref ref, {required String diaryId}) async {
  final repo = DiaryRepository.get();
  Timer? debounce;
  final sub = repo.diaryEvents.listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
  return repo.buildEgoGraph(diaryId); // 只取直接关联（depth 1）
}

/// 局部关系图：以当前日记为中心的 k 跳邻域，跑**力导向布局**（ForceAtlas2 + Barnes-Hut，
/// 由 Rust [layoutGraphStream] 逐帧流式回传）。中心节点被 pin 在原点（`pinnedCount:1`），
/// 邻居受力自然铺开。方向靠边的颜色 + 选中态箭头编码：出链取 primary、入链取 tertiary。
class DiaryEgoGraphPage extends ConsumerStatefulWidget {
  final String centerId;

  const DiaryEgoGraphPage({super.key, required this.centerId});

  @override
  ConsumerState<DiaryEgoGraphPage> createState() => _DiaryEgoGraphPageState();
}

class _DiaryEgoGraphPageState extends ConsumerState<DiaryEgoGraphPage>
    with SingleTickerProviderStateMixin {
  late final List<String> _centers = [widget.centerId];
  int? _selected;

  GraphScene? _scene;
  GraphPalette? _palette;
  List<Category> _categories = const [];
  List<EgoDirection?> _dirs = const [];

  final _frame = GraphFrame();
  final _canvas = GraphCanvasController();
  StreamSubscription<Float32List>? _layoutSub;

  // 沉降展示与物理解耦：Rust 全速算出终态（几毫秒），再用缓动曲线从种子补间过去——
  // 时长与手感完全可控，不再是「物理前几帧猛跳、后面静止」的生硬观感。
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..addListener(_onSettleTick);
  Float32List? _seed;
  Float32List? _target;

  String get _centerId => _centers.last;

  @override
  void dispose() {
    _layoutSub?.cancel();
    _settle.dispose();
    _frame.dispose();
    _canvas.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final seed = _seed, target = _target;
    if (seed == null || target == null || seed.length != target.length) return;
    final t = Curves.easeInOutCubic.transform(_settle.value);
    final out = Float32List(target.length);
    for (var i = 0; i < target.length; i++) {
      out[i] = seed[i] + (target[i] - seed[i]) * t;
    }
    _frame.push(out, settled: _settle.isCompleted);
  }

  /// 起一轮力导向布局。中心（数据层保证在下标 0）pin 在原点，其余节点用确定性径向位置
  /// 作种子；Rust FA2+Barnes-Hut 不带延迟直接算到收敛，只取终态帧。
  void _startLayout(GraphScene scene) {
    _layoutSub?.cancel();
    _settle.stop();
    if (scene.nodeCount == 0) {
      _frame.push(Float32List(0), settled: true);
      return;
    }
    final seed = layoutEgoRadial(scene).positions; // 好初值：中心在原点、逐跳成环
    _seed = seed;
    _target = null;
    _frame.push(seed);
    // 中心必须在下标 0 才能 pin（buildEgoGraph 的排序保证如此）；否则退化为不 pin。
    final pin = scene.centerIndex == 0 ? 1 : 0;
    const density = GraphDensity.normal;
    Float32List? last;
    _layoutSub =
        layoutGraphStream(
          nodeCount: scene.nodeCount,
          edges: scene.undirectedEdges,
          initialPositions: seed,
          params: GraphLayoutParams(
            iterations: GraphTuning.iterations,
            theta: GraphTuning.theta,
            repulsion: GraphTuning.repulsion(density),
            springLength: GraphTuning.springLength(density),
            springStrength: GraphTuning.springStrength,
            gravity: GraphTuning.gravity(density),
            collideRadius: GraphTuning.collideRadius(density),
            velocityDecay: GraphTuning.velocityDecay,
            emitEvery: GraphTuning.iterations, // 只要终态：首帧 + 末帧
            frameDelayMs: 0,
            initialAlpha: 1.0,
            minStep: GraphTuning.minStepRatio,
            pinnedCount: pin,
            normalizeScale: true,
          ),
        ).listen(
          (f) => last = f,
          onError: (Object _, StackTrace _) {
            if (mounted) _frame.markSettled();
          },
          onDone: () {
            if (!mounted) return;
            final target = last;
            if (target == null || target.length != scene.nodeCount * 2) {
              _frame.markSettled();
              return;
            }
            _target = target;
            _settle.forward(from: 0);
          },
        );
  }

  void _setCenter(String id) {
    if (id == _centerId) return;
    HapticFeedback.selectionClick();
    setState(() {
      _centers.add(id);
      _selected = null;
      _scene = null;
    });
  }

  bool _popCenter() {
    if (_centers.length <= 1) return false;
    setState(() {
      _centers.removeLast();
      _selected = null;
      _scene = null;
    });
    return true;
  }

  Future<void> _open(DiaryGraphNode n) async {
    final diary = await DiaryRepository.get().getDiaryByBusinessId(n.id);
    if (diary == null || !mounted) return;
    openDiaryDetail(context, diary);
  }

  static (int, int) _degrees(GraphScene scene, int i) {
    var out = 0, inc = 0;
    for (var k = 0; k < scene.edgeCount; k++) {
      if (scene.edges[k * 2] == i) out++;
      if (scene.edges[k * 2 + 1] == i) inc++;
    }
    return (out, inc);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final async = ref.watch(diaryEgoGraphProvider(diaryId: _centerId));
    final categories =
        ref.watch(categoryControllerProvider).value ?? const <Category>[];

    return PopScope(
      canPop: _centers.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _popCenter();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(
              _centers.length > 1 ? LucideIcons.arrowLeft : LucideIcons.x,
            ),
            onPressed: () {
              if (!_popCenter()) Navigator.of(context).pop();
            },
          ),
          title: Text(l10n.graphLocal),
        ),
        body: async.buildLoading(
          data: (graph) {
            if (graph.isEmpty) {
              return Center(
                child: Text(
                  l10n.graphNoLocalLinks,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            _ensureScene(graph, theme, categories);
            final scene = _scene!;
            if (scene.nodeCount <= 1) {
              return Center(
                child: Text(
                  l10n.graphNoLocalLinks,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return _buildBody(theme, l10n, scene);
          },
        ),
      ),
    );
  }

  void _ensureScene(
    DiaryGraphData graph,
    ThemeData theme,
    List<Category> categories,
  ) {
    final palette = GraphPalette.of(theme, edgeCount: graph.edgeCount);
    if (_scene != null &&
        identical(_scene!.data, graph) &&
        _palette == palette &&
        identical(_categories, categories)) {
      return;
    }
    // 只是主题 / 分类色变了（节点数据没变）：重建场景配色，但不重跑布局，保住当前坐标。
    final sameGraph = _scene != null && identical(_scene!.data, graph);
    _palette = palette;
    _categories = categories;
    _scene = .build(
      data: graph,
      categories: categories,
      palette: palette,
      mode: .category,
    );
    _dirs = egoDirectionsOf(_scene!);
    if (!sameGraph) {
      _selected = null;
      _startLayout(_scene!);
    }
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n, GraphScene scene) {
    final cs = theme.colorScheme;
    final center = scene.centerIndex ?? 0;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final infoIndex = _selected ?? center;
    final (out, inc) = _degrees(scene, infoIndex);

    return Stack(
      children: [
        Positioned.fill(
          child: GraphCanvas(
            scene: scene,
            frame: _frame,
            palette: _palette!,
            selected: _selected,
            controller: _canvas,
            egoDirections: _dirs,
            onSelect: (i) => setState(() => _selected = i),
          ),
        ),
        // 图例：边色的方向语义（primary=出链 / tertiary=入链），屏幕空间固定不随相机。
        Positioned(
          left: 12,
          right: 12,
          top: 10,
          child: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              _Legend(
                color: cs.tertiary,
                label: l10n.graphIncomingCount(
                  _countAtCenter(scene, out: false),
                ),
              ),
              _Legend(
                color: cs.primary,
                label: l10n.graphOutgoingCount(
                  _countAtCenter(scene, out: true),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 96 + bottomSafe,
          child: ListenableBuilder(
            listenable: _canvas,
            builder: (_, _) => AnimatedScale(
              scale: _canvas.userMoved ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: l10n.graphBackToCenter,
                elevation: 2,
                backgroundColor: cs.surfaceContainerHigh,
                foregroundColor: cs.onSurfaceVariant,
                onPressed: _canvas.fit,
                child: const Icon(LucideIcons.focus),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12 + bottomSafe,
          child: GraphInfoCard(
            key: ValueKey(scene.nodes[infoIndex].id),
            node: scene.nodes[infoIndex],
            accent: scene.colors[infoIndex],
            outgoing: out,
            incoming: inc,
            onOpen: () => _open(scene.nodes[infoIndex]),
            onCenter: infoIndex == center
                ? null
                : () => _setCenter(scene.nodes[infoIndex].id),
            onClose: _selected == null
                ? null
                : () => setState(() => _selected = null),
          ),
        ),
      ],
    );
  }

  int _countAtCenter(GraphScene scene, {required bool out}) {
    final center = scene.centerIndex ?? 0;
    final (o, i) = _degrees(scene, center);
    return out ? o : i;
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 26,
      padding: const .symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: .circular(13),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: .circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
