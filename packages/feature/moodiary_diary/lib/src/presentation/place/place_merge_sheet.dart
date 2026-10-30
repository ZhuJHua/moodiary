import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../map/map_tile_source.dart';
import '../map/map_tiles.dart';
import 'place_editor.dart';

/// 合并流程的退出结果，交给调用方决定后续（如退出多选态）。
enum PlaceMergeOutcome {
  /// 合并生效（含倒计时自然结束、撤销失败但合并已落地）。
  completed,

  /// 用户在倒计时窗口内撤销，数据已还原。
  undone,

  /// 用户在编辑阶段取消。
  cancelled,
}

/// 撤销窗口的时长：3 秒起步，每篇受影响的日记加 0.4 秒，最多 8 秒。
///
/// 窗口里跑的是一段"假的"进度动画（见 `_buildTicker`）：每篇日记均分一段时间，
/// 篇数越多窗口越长，用户来得及看清哪些日记改了指向。
@visibleForTesting
Duration undoWindowFor(int diaryCount) =>
    Duration(milliseconds: (3000 + 400 * diaryCount).clamp(3000, 8000));

class _MergeDraft {
  String selectedId;
  String name;

  /// 用户手动改过名称后，切换候选不再覆盖输入。
  bool nameEdited = false;

  _MergeDraft({required this.selectedId, required this.name});
}

enum _Phase {
  /// 选择最终地点与名称。
  editing,

  /// 二次确认后正在执行合并。
  merging,

  /// 合并成功，倒计时撤销窗口开放中。
  running,

  /// 用户点了撤销，正在还原。
  undoing,
}

/// 弹出合并底部窗并驱动完整流程：选最终地点 → 二次确认（向上叠加对话框）
/// → 回到本窗进入进度 + 撤销倒计时 → 一路回退关闭。错误一律以 toast 呈现。
Future<PlaceMergeOutcome?> showPlaceMergeSheet(
  BuildContext context, {
  required List<Place> candidates,
}) {
  return MSheet.show<PlaceMergeOutcome>(
    context,
    // 合并一旦落地就有撤销凭据要守，而官方下拉关闭走的是 Navigator.pop，
    // 绕开下面 running 阶段的 PopScope —— 整窗不可拖，只能走自身动作退出。
    enableDrag: false,
    builder: (_) => _PlaceMergeSheet(candidates: candidates),
  );
}

class _PlaceMergeSheet extends ConsumerStatefulWidget {
  final List<Place> candidates;

  const _PlaceMergeSheet({required this.candidates});

  @override
  ConsumerState<_PlaceMergeSheet> createState() => _PlaceMergeSheetState();
}

class _PlaceMergeSheetState extends ConsumerState<_PlaceMergeSheet>
    with SingleTickerProviderStateMixin {
  late final _MergeDraft _draft = _MergeDraft(
    selectedId: widget.candidates.first.id,
    name: widget.candidates.first.name,
  );
  late final TextEditingController _controller = TextEditingController(
    text: _draft.name,
  );
  // 真时长在合并落地时按受影响的日记数定（见 _merge），这里只给下限占位。
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: undoWindowFor(0),
  )..addStatusListener(_onCountdownStatus);
  final _map = MapController();

  _Phase _phase = _Phase.editing;
  PlaceMergeRecord? _record;

  /// 这次合并真正改了指向的日记，最新在前 —— 撤销窗口里的假进度按它走。
  List<Diary> _affected = const [];

  bool _edited = false;
  bool _mapReady = false;

  bool get _running => _phase != _Phase.editing;

  @override
  void dispose() {
    _controller.dispose();
    _countdown.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onCountdownStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _phase != _Phase.running) {
      return;
    }
    // 倒计时耗尽：合并落定，回退整个流程，气泡提示操作结束。
    toast.success(message: context.l10n.diary.placeMerged(name: _finalName));
    Navigator.of(context).pop(PlaceMergeOutcome.completed);
  }

  String get _finalName => _draft.name.trim();

  void _onMapReady() {
    _mapReady = true;
    _fitBounds();
  }

  void _fitBounds() {
    if (!_mapReady || widget.candidates.length < 2) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final p in widget.candidates) LatLng(p.latitude, p.longitude),
        ]),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  void _select(Place place) {
    setState(() {
      _draft.selectedId = place.id;
      if (!_draft.nameEdited) {
        _draft.name = place.name;
        _controller.text = place.name;
      }
    });
  }

  Future<void> _confirm() async {
    if (_finalName.isEmpty) {
      setState(() => _edited = true);
      return;
    }
    final l10n = context.l10n;
    final controller = ref.read(placeControllerProvider.notifier);
    // 合并会连回收站里的日记一起重指，所以确认数量与撤销窗口的进度都按
    // 同一份"真正会被改写的日记"算 —— placeFootprints 只统计可见日记。
    final affected = await controller.affectedDiaries(_candidateIds);
    if (!mounted) return;
    // 二次确认对话框叠在底部窗之上。
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.diary.placeMergeConfirmTitle,
      message: l10n.diary.placeMergeConfirmMessage(
        name: _finalName,
        count: widget.candidates.length,
        diaries: affected.length,
      ),
      confirmLabel: l10n.diary.placeMerge,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _merge(controller, affected);
  }

  List<String> get _candidateIds => [for (final p in widget.candidates) p.id];

  Future<void> _merge(PlaceController controller, List<Diary> affected) async {
    setState(() => _phase = _Phase.merging);
    final record = await controller.mergePlaces(
      keptId: _draft.selectedId,
      finalName: _finalName,
      removedIds: [
        for (final p in widget.candidates)
          if (p.id != _draft.selectedId) p.id,
      ],
    );
    if (!mounted) return;
    if (record == null) {
      toast.error(message: context.l10n.diary.placeSaveFailed);
      setState(() => _phase = _Phase.editing);
      return;
    }
    _record = record;
    // 只留真正被改写的那些：并发的同步/迁移可能让名单和凭据对不上。
    _affected = [
      for (final d in affected)
        if (record.diaryRemap.containsKey(d.id)) d,
    ];
    _countdown.duration = undoWindowFor(_affected.length);
    setState(() => _phase = _Phase.running);
    _countdown.forward(from: 0);
  }

  Future<void> _undo() async {
    final record = _record;
    if (record == null || _phase != _Phase.running) return;
    setState(() => _phase = _Phase.undoing);
    _countdown.stop();
    final ok = await ref
        .read(placeControllerProvider.notifier)
        .undoMerge(record);
    if (!mounted) return;
    if (ok) {
      toast.success(message: context.l10n.diary.placeUndone);
      Navigator.of(context).pop(PlaceMergeOutcome.undone);
    } else {
      // 数据仍以合并后状态落地，错误提示后照常退出流程。
      toast.error(message: context.l10n.diary.placeUndoFailed);
      Navigator.of(context).pop(PlaceMergeOutcome.completed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = MapTileSource.of(MoodiaryKVs.mapTileSource.get()!);
    final tiandituKey =
        ref.watch(secretKvProvider(MoodiarySecureKVs.tiandituKey)).value ?? '';

    if (_running) return _buildRunning(source, tiandituKey);

    return MSheetScaffold<PlaceMergeOutcome>(
      title: context.l10n.diary.placeMergeSheetTitle,
      actions: [
        MAction(
          label: context.l10n.common.cancel,
          value: PlaceMergeOutcome.cancelled,
        ),
        // 用 onPressed 自行驱动后续流程，提交成功后不自动关闭弹层。
        MAction(
          label: context.l10n.common.ok,
          isPrimary: true,
          onPressed: _confirm,
        ),
      ],
      child: _buildBody(source, tiandituKey),
    );
  }

  /// 合并执行 / 撤销倒计时阶段：一路回退式布局，底部按钮区换成
  /// 进度条 + 撤销，编辑内容禁点置灰。
  Widget _buildRunning(MapTileSource? source, String tiandituKey) {
    final colors = context.theme.colors;
    return PopScope(
      canPop: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 20),
            child: Text(
              context.l10n.diary.placeMergeSheetTitle,
              style: context.theme.typography.titleLarge.emphasized.onSurface,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const .fromLTRB(20, 16, 20, 4),
              child: IgnorePointer(
                child: Opacity(
                  opacity: context.theme.states.disabledOpacity,
                  child: _buildBody(source, tiandituKey),
                ),
              ),
            ),
          ),
          Container(
            padding: const .fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: _buildRunningBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningBar() {
    final colors = context.theme.colors;
    final progress = AnimatedBuilder(
      animation: _countdown,
      builder: (_, _) => LinearProgressIndicator(
        // 顺数：从 0 填满到 1，时间到即合并落定
        value: _phase == _Phase.merging ? null : _countdown.value,
        minHeight: 6,
        borderRadius: .circular(3),
        backgroundColor: colors.surfaceContainerHighest,
        color: colors.primary,
      ),
    );
    final merging = _phase == _Phase.merging;
    final undoing = _phase == _Phase.undoing;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(child: progress),
            if (!merging) ...[
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('place-merge-undo'),
                onPressed: undoing ? null : _undo,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurfaceVariant,
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(
                    borderRadius: MuiRadius.md,
                  ),
                ),
                child: Tooltip(
                  message: context.l10n.diary.placeUndo,
                  child: undoing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : const Icon(LucideIcons.undo2, size: 20),
                ),
              ),
            ],
          ],
        ),
        _buildTicker(),
      ],
    );
  }

  /// 撤销窗口里的"假进度"：进度条走时间，这行文案走篇数。
  ///
  /// 篇数按倒计时均分，所以条填到哪，就有几篇日记"正在被改写"。窗口期真的
  /// 只是倒计时，这里一个字节都不写。
  Widget _buildTicker() {
    final typography = context.theme.typography;
    final l10n = context.l10n;
    final idle = typography.labelMedium.onSurfaceVariant;
    if (_phase == _Phase.merging) {
      return Text(l10n.diary.placeMerging, style: idle);
    }
    if (_phase == _Phase.undoing) {
      return Text(l10n.diary.placeUndoing, style: idle);
    }
    final total = _affected.length;
    if (total == 0) {
      return Text(l10n.diary.placeMergeNoDiary, style: idle);
    }
    return AnimatedBuilder(
      animation: _countdown,
      builder: (_, _) {
        final done = (_countdown.value * total).floor().clamp(0, total - 1);
        final diary = _affected[done];
        final title = diary.title.trim();
        return Row(
          children: [
            Text(
              l10n.diary.placeMergeProgress(done: done + 1, total: total),
              style: idle,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.isEmpty ? l10n.common.untitled : title,
                maxLines: 1,
                overflow: .ellipsis,
                style: typography.bodySmall.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(TimeFormat.relative(diary.time), style: idle),
          ],
        );
      },
    );
  }

  Widget _buildBody(MapTileSource? source, String tiandituKey) {
    final showMap =
        source != null && (source != .tianditu || tiandituKey.isNotEmpty);
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        if (showMap) ...[
          _buildMap(source, tiandituKey),
          const SizedBox(height: 12),
        ],
        _buildCandidates(),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: !showMap,
          enabled: !_running,
          textInputAction: .done,
          onChanged: (value) => setState(() {
            _edited = true;
            _draft.nameEdited = true;
            _draft.name = value;
          }),
          style: context.theme.typography.bodyLarge.onSurface,
          decoration: InputDecoration(
            labelText: context.l10n.diary.placeNameLabel,
            errorText: _edited && _finalName.isEmpty
                ? context.l10n.diary.placeNameEmpty
                : null,
            filled: true,
            isDense: true,
            fillColor: context.theme.colors.surfaceContainerHighest,
            contentPadding: const .symmetric(horizontal: 16, vertical: 13),
            border: const OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              borderSide: .none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              borderSide: .none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorderRadius,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCandidates() {
    final colors = context.theme.colors;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: .horizontal,
        itemCount: widget.candidates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final place = widget.candidates[index];
          final selected = place.id == _draft.selectedId;
          final color = placeIconColor(context, place.icon);
          // 颜色说不出"谁留下"：选中态交给读屏，候选组标成互斥。
          return Semantics(
            key: ValueKey('place-merge-candidate-${place.id}'),
            container: true,
            button: true,
            selected: selected,
            inMutuallyExclusiveGroup: true,
            child: MInkWell(
              onTap: () => _select(place),
              borderRadius: .circular(22),
              child: AnimatedContainer(
                duration: Durations.short4,
                curve: Easing.emphasizedDecelerate,
                padding: const .symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected ? color : colors.surfaceContainerHighest,
                  borderRadius: .circular(22),
                  border: selected
                      ? null
                      : Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    Icon(
                      placeIconOf(place.icon),
                      size: 16,
                      color: selected
                          ? onCategoryColor(color)
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      place.name,
                      style: context.theme.typography.labelLarge.onSurface
                          .copyWith(
                            color: selected
                                ? onCategoryColor(color)
                                : colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap(MapTileSource source, String tiandituKey) {
    final theme = context.theme;
    final count = widget.candidates.length;
    final center = LatLng(
      widget.candidates.map((p) => p.latitude).reduce((a, b) => a + b) / count,
      widget.candidates.map((p) => p.longitude).reduce((a, b) => a + b) / count,
    );
    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: .circular(theme.radii.lg),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 18,
                backgroundColor: theme.colors.surfaceContainerHighest,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
              ),
              children: [
                ...mapTileLayers(
                  source,
                  tiandituKey: tiandituKey,
                  retina: MediaQuery.devicePixelRatioOf(context) > 1,
                ),
                MarkerLayer(
                  markers: [
                    for (final p in widget.candidates)
                      Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _select(p),
                          child: _CandidateMarker(
                            place: p,
                            selected: p.id == _draft.selectedId,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: MapAttribution(source: source),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateMarker extends StatelessWidget {
  final Place place;
  final bool selected;

  const _CandidateMarker({required this.place, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return AnimatedScale(
      scale: selected ? 1.2 : 1,
      duration: Durations.short4,
      curve: Easing.emphasizedDecelerate,
      child: Container(
        padding: const .all(3),
        decoration: BoxDecoration(
          shape: .circle,
          color: colors.surface.withValues(alpha: selected ? 0.9 : 0.6),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: PlaceBadge(place: place, size: 24),
      ),
    );
  }
}
