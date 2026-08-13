import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_canvas.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_info_card.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_scene.dart';
import 'package:moodiary_diary/src/presentation/graph/graph_style.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_nav.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diary_graph_page.g.dart';

/// 知识图谱数据（只含有双链的日记）。订阅 [DiaryRepository.diaryEvents]，任何日记增删改都
/// 令其失效重建；从双链快照直接装配，免解析 content。
///
/// 事件做 400ms 防抖：同步拉取 / 批量编辑会连续触发多次，不防抖就是连续多次全量重建。
@riverpod
Future<DiaryGraphData> diaryGraph(Ref ref) async {
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
  return repo.buildLinkGraph();
}

class DiaryGraphPage extends ConsumerWidget {
  const DiaryGraphPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(diaryGraphProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diary.knowledgeGraph)),
      body: async.buildLoading(
        data: (graph) =>
            graph.isEmpty ? const GraphEmptyState() : _GraphView(graph: graph),
      ),
    );
  }
}

/// 全图为空（一条双链都没有）。装饰图示比一个 Icon 更切题：三个节点两条弧，就是双链本身。
class GraphEmptyState extends StatelessWidget {
  const GraphEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final cs = theme.colors;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          SizedBox(
            width: 120,
            height: 88,
            child: CustomPaint(painter: _EmptyGlyph(cs.outlineVariant)),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.diary.graphEmptyTitle,
            style: theme.typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const .symmetric(horizontal: 40),
            child: Text(
              context.l10n.diary.graphEmptyDesc,
              textAlign: .center,
              style: theme.typography.bodySmall.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => const NewDiaryRoute(type: 'tiptap').push(context),
            child: Text(context.l10n.diary.graphEmptyAction),
          ),
        ],
      ),
    );
  }
}

class _EmptyGlyph extends CustomPainter {
  final Color color;

  _EmptyGlyph(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    final a = Offset(size.width * 0.16, size.height * 0.72);
    final b = Offset(size.width * 0.5, size.height * 0.2);
    final c = Offset(size.width * 0.86, size.height * 0.68);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(size.width * 0.3, size.height * 0.32, b.dx, b.dy)
        ..moveTo(b.dx, b.dy)
        ..quadraticBezierTo(size.width * 0.78, size.height * 0.34, c.dx, c.dy),
      stroke,
    );
    canvas.drawCircle(a, 10, stroke);
    canvas.drawCircle(b, 14, stroke);
    canvas.drawCircle(c, 10, stroke);
  }

  @override
  bool shouldRepaint(covariant _EmptyGlyph old) => old.color != color;
}

enum _TimeFilter { all, last30, thisYear, last365 }

class _GraphView extends ConsumerStatefulWidget {
  final DiaryGraphData graph;

  const _GraphView({required this.graph});

  @override
  ConsumerState<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends ConsumerState<_GraphView> {
  // —— 会话级视图状态（不持久化）——
  String? _categoryId;
  _TimeFilter _time = .all;
  GraphDensity _density = .normal;
  GraphColorMode _colorMode = .category;
  bool _showLabels = true;

  DiaryGraphData _sub = emptyGraphData;
  GraphScene? _scene;
  GraphPalette? _palette;
  List<Category> _categories = const [];
  int? _selected;
  bool _pendingLayout = true;

  final _frame = GraphFrame();
  final _canvas = GraphCanvasController();
  StreamSubscription<Float32List>? _layoutSub;

  /// 上一次的世界坐标，按业务 id 记。数据刷新 / 换筛选时作为新布局的种子，
  /// 配合低 initialAlpha 让图原地微调而不是整体炸开重排。
  final _memory = <String, Offset>{};

  @override
  void initState() {
    super.initState();
    _sub = filterGraph(widget.graph);
  }

  @override
  void dispose() {
    _layoutSub?.cancel();
    _frame.dispose();
    _canvas.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _GraphView old) {
    super.didUpdateWidget(old);
    // didUpdateWidget 之后本就要重建，直接改字段即可，不必 setState。
    if (!identical(old.graph, widget.graph)) _invalidate(keepSelection: true);
  }

  void _ensureScene(MuiThemeData theme, List<Category> categories) {
    final palette = GraphPalette.of(theme.colors, edgeCount: _sub.edgeCount);
    if (_scene != null &&
        _palette == palette &&
        identical(_categories, categories)) {
      return;
    }
    _palette = palette;
    _categories = categories;
    _scene = .build(
      data: _sub,
      categories: categories,
      palette: palette,
      mode: _colorMode,
    );
  }

  /// 重算子图并（可选）重跑布局。[keepSelection] 用于数据刷新：按业务 id 把选中态
  /// 挪到新下标，否则用户正在看的信息卡会凭空消失。
  void _invalidate({bool relayout = true, bool keepSelection = false}) {
    final selectedId =
        keepSelection && _selected != null && _selected! < _sub.nodeCount
        ? _sub.nodes[_selected!].id
        : null;
    _sub = filterGraph(
      widget.graph,
      categoryId: _categoryId,
      range: _timeRange(_time),
    );
    _scene = null; // 交给 _ensureScene 按新数据 + 当前主题重建
    _palette = null;
    if (selectedId == null) {
      _selected = null;
    } else {
      final i = _sub.nodes.indexWhere((n) => n.id == selectedId);
      _selected = i < 0 ? null : i;
    }
    _pendingLayout = relayout;
  }

  void _startLayout() {
    _layoutSub?.cancel();
    final scene = _scene;
    if (scene == null) return;
    if (scene.nodeCount == 0) {
      _frame.push(Float32List(0), settled: true);
      return;
    }
    final springLength = GraphTuning.springLength(_density);
    // 结构感知播种 + 复用上次坐标：相连节点开局就在一起，力只做精修。
    final seed = seedByBfs(scene, springLength);
    var reused = 0;
    for (var i = 0; i < scene.nodeCount; i++) {
      final p = _memory[scene.nodes[i].id];
      if (p == null) continue;
      seed[i * 2] = p.dx;
      seed[i * 2 + 1] = p.dy;
      reused++;
    }
    final warm = reused > scene.nodeCount * 0.6;
    _frame.push(seed);

    final big = scene.nodeCount > GraphTuning.bigNodeCount;
    final iterations = big ? GraphTuning.bigIterations : GraphTuning.iterations;
    _layoutSub =
        layoutGraphStream(
          nodeCount: scene.nodeCount,
          edges: scene.undirectedEdges,
          initialPositions: seed,
          params: GraphLayoutParams(
            iterations: iterations,
            theta: GraphTuning.theta,
            repulsion: GraphTuning.repulsion(_density),
            springLength: springLength,
            springStrength: GraphTuning.springStrength,
            gravity: GraphTuning.gravity(_density),
            collideRadius: GraphTuning.collideRadius(_density),
            velocityDecay: GraphTuning.velocityDecay,
            // 帧数恒定：动画时长与图规模脱钩（旧公式在 2000 节点时算出 1，等于 100Hz 空转）。
            emitEvery: (iterations / GraphTuning.targetFrames).ceil().clamp(
              1,
              64,
            ),
            frameDelayMs: GraphTuning.frameDelayMs,
            initialAlpha: warm ? GraphTuning.refreshAlpha : 1.0,
            minStep: GraphTuning.minStepRatio,
            pinnedCount: 0,
            normalizeScale: true,
          ),
        ).listen(
          (f) {
            if (!mounted) return;
            _frame.push(f);
          },
          onError: (Object _, StackTrace _) {
            if (mounted) _frame.markSettled();
          },
          onDone: () {
            if (!mounted) return;
            _remember();
            _frame.markSettled();
          },
        );
  }

  void _remember() {
    final scene = _scene;
    final pos = _frame.positions;
    if (scene == null || pos.length != scene.nodeCount * 2) return;
    for (var i = 0; i < scene.nodeCount; i++) {
      _memory[scene.nodes[i].id] = Offset(pos[i * 2], pos[i * 2 + 1]);
    }
  }

  (DateTime, DateTime)? _timeRangeRaw(_TimeFilter f) {
    final now = DateTime.now();
    return switch (f) {
      .all => null,
      .last30 => (now.subtract(const Duration(days: 30)), now),
      .thisYear => (DateTime(now.year), now),
      .last365 => (now.subtract(const Duration(days: 365)), now),
    };
  }

  DateTimeRange? _timeRange(_TimeFilter f) {
    final r = _timeRangeRaw(f);
    return r == null ? null : DateTimeRange(start: r.$1, end: r.$2);
  }

  Future<void> _open(DiaryGraphNode n) async {
    final diary = await DiaryRepository.get().getDiaryByBusinessId(n.id);
    if (diary == null || !mounted) return;
    openDiaryDetail(context, diary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    final categories =
        ref.watch(categoryControllerProvider).value ?? const <Category>[];
    _ensureScene(theme, categories);
    if (_pendingLayout) {
      _pendingLayout = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startLayout();
      });
    }
    final scene = _scene!;
    final palette = _palette!;

    return Column(
      children: [
        Padding(
          padding: const .only(top: 8, bottom: 8),
          child: MChipBar<String?>(
            selected: _categoryId,
            onSelected: (v) => setState(() {
              _categoryId = v;
              _invalidate();
            }),
            items: [
              MChipData(value: null, label: l10n.diary.categoryAll),
              for (final c in categories)
                MChipData(
                  value: c.id,
                  label: c.categoryName,
                  // chip 上的分类色圆点与画布节点色一一对应，筛选条本身就是图例。
                  accentColor: categoryColorOf(colorValue: c.color, id: c.id),
                ),
            ],
            fadeColor: theme.colors.surface,
          ),
        ),
        Expanded(
          child: scene.nodeCount == 0
              ? _FilteredEmpty(
                  onClear: () => setState(() {
                    _categoryId = null;
                    _time = .all;
                    _invalidate();
                  }),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: GraphCanvas(
                        scene: scene,
                        frame: _frame,
                        palette: palette,
                        selected: _selected,
                        showLabels: _showLabels,
                        controller: _canvas,
                        onSelect: (i) => setState(() => _selected = i),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: _selected == null ? 1 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          l10n.diary.graphCount(
                            nodes: scene.edgeCount,
                            edges: scene.nodeCount,
                          ),
                          style: theme.typography.labelSmall.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: .min,
                        children: [
                          ListenableBuilder(
                            listenable: _canvas,
                            builder: (_, _) => AnimatedScale(
                              scale: _canvas.userMoved ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: _MiniFab(
                                tooltip: l10n.diary.graphResetCamera,
                                icon: LucideIcons.focus,
                                onTap: _canvas.fit,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _MiniFab(
                            tooltip: l10n.diary.graphView,
                            icon: LucideIcons.slidersHorizontal,
                            onTap: _openViewSheet,
                          ),
                        ],
                      ),
                    ),
                    if (_selected != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: GraphInfoCard(
                          node: scene.nodes[_selected!],
                          accent: scene.colors[_selected!],
                          outgoing: _countDirected(
                            scene,
                            _selected!,
                            out: true,
                          ),
                          incoming: _countDirected(
                            scene,
                            _selected!,
                            out: false,
                          ),
                          onOpen: () => _open(scene.nodes[_selected!]),
                          onCenter: () => DiaryGraphRoute(
                            diaryId: scene.nodes[_selected!].id,
                          ).push(context),
                          onClose: () => setState(() => _selected = null),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  static int _countDirected(GraphScene scene, int i, {required bool out}) {
    var c = 0;
    for (var k = 0; k < scene.edgeCount; k++) {
      final a = scene.edges[k * 2], b = scene.edges[k * 2 + 1];
      if (out ? a == i : b == i) c++;
    }
    return c;
  }

  Future<void> _openViewSheet() async {
    final l10n = context.l10n;
    await MSheet.show<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          void apply(VoidCallback change, {bool relayout = false}) {
            setSheet(change);
            if (relayout) {
              setState(_invalidate);
            } else {
              // 只换着色 / 标签开关：场景重建即可，不必重跑布局。
              setState(() {
                _scene = null;
                _palette = null;
              });
            }
          }

          return MSheetScaffold<void>(
            title: l10n.diary.graphStyle,
            icon: LucideIcons.chartNetwork,
            actions: [MAction(label: l10n.common.ok, isPrimary: true)],
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                _SheetGroup(
                  label: l10n.diary.rangeAll,
                  icon: LucideIcons.clock,
                  child: SegmentedButton<_TimeFilter>(
                    showSelectedIcon: false,
                    selected: {_time},
                    segments: [
                      ButtonSegment(
                        value: _TimeFilter.all,
                        label: Text(l10n.diary.rangeAll),
                      ),
                      ButtonSegment(
                        value: _TimeFilter.last30,
                        label: Text(l10n.diary.rangeLast30),
                      ),
                      ButtonSegment(
                        value: _TimeFilter.thisYear,
                        label: Text(l10n.diary.rangeThisYear),
                      ),
                      ButtonSegment(
                        value: _TimeFilter.last365,
                        label: Text(l10n.diary.graphTimeLast365),
                      ),
                    ],
                    onSelectionChanged: (v) =>
                        apply(() => _time = v.first, relayout: true),
                  ),
                ),
                const SizedBox(height: 20),
                _SheetGroup(
                  label: l10n.diary.graphStyle,
                  icon: LucideIcons.chartNetwork,
                  child: SegmentedButton<GraphDensity>(
                    showSelectedIcon: false,
                    selected: {_density},
                    segments: [
                      ButtonSegment(
                        value: GraphDensity.sparse,
                        label: Text(l10n.diary.graphStyleSparse),
                      ),
                      ButtonSegment(
                        value: GraphDensity.normal,
                        label: Text(l10n.diary.graphStyleNormal),
                      ),
                      ButtonSegment(
                        value: GraphDensity.dense,
                        label: Text(l10n.diary.graphStyleDense),
                      ),
                    ],
                    onSelectionChanged: (v) => apply(() {
                      _density = v.first;
                      _memory.clear(); // 换疏密即换尺度，旧坐标不能当种子
                    }, relayout: true),
                  ),
                ),
                const SizedBox(height: 20),
                _SheetGroup(
                  label: l10n.diary.graphColorBy,
                  icon: LucideIcons.palette,
                  child: SegmentedButton<GraphColorMode>(
                    showSelectedIcon: false,
                    selected: {_colorMode},
                    segments: [
                      ButtonSegment(
                        value: GraphColorMode.category,
                        label: Text(l10n.common.category),
                      ),
                      ButtonSegment(
                        value: GraphColorMode.time,
                        label: Text(l10n.diary.graphColorByTime),
                      ),
                      ButtonSegment(
                        value: GraphColorMode.plain,
                        label: Text(l10n.diary.graphColorByPlain),
                      ),
                    ],
                    onSelectionChanged: (v) =>
                        apply(() => _colorMode = v.first),
                  ),
                ),
                const SizedBox(height: 20),
                MSwitchField(
                  label: l10n.diary.graphShowLabels,
                  value: _showLabels,
                  onChanged: (v) => apply(() => _showLabels = v),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SheetGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;

  const _SheetGroup({
    required this.label,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colors.onSurfaceVariant),
            const SizedBox(width: 6),
            // 分组小标题，弱前景。
            Text(label, style: theme.typography.titleSmall.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: .horizontal, child: child),
      ],
    );
  }
}

class _MiniFab extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _MiniFab({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colors;
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: tooltip,
      elevation: 2,
      backgroundColor: cs.surfaceContainerHigh,
      foregroundColor: cs.onSurfaceVariant,
      onPressed: onTap,
      child: Icon(icon),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  final VoidCallback onClear;

  const _FilteredEmpty({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(LucideIcons.filterX, size: 40, color: theme.colors.outline),
          const SizedBox(height: 12),
          Text(
            context.l10n.diary.graphFilterEmpty,
            style: theme.typography.bodyMedium.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClear,
            child: Text(context.l10n.diary.graphClearFilter),
          ),
        ],
      ),
    );
  }
}
