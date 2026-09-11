import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show precisionErrorTolerance, visibleForTesting;
import 'package:flutter/rendering.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

typedef AssistantItemBuilder = Widget Function(
  BuildContext context,
  AssistantChatItem item,
  int index,
);

// 逐帧轨迹开关，真机排位置问题用；tree-shaking 会剔掉整个分支
const bool _kTrace = false;

void _trace(String Function() message) {
  if (_kTrace) debugPrint('CL ${message()}');
}

// 距底多近算「在底部」（用户意图，比 _kStickEpsilon 宽松）
const double _kBottomSlack = 8;

const double _kItemGap = 12;
const double _kTopPadding = 8;

const double _kStickEpsilon = 0.5;

// 首帧没有视口尺寸时，长会话先把中心放到离尾部这么多条
const int _kInitialCenterProbe = 24;

// 贴底跟随时 forward 组攒到这么多条就把中心往前推
const int _kForwardGroupCap = 32;

// 每帧尾离屏量高度的时间预算
const Duration _kMeasureBudget = Duration(milliseconds: 2);

typedef _ExtentSignature = ({
  double width,
  TextScaler scaler,
  MuiTypography text,
  Locale? locale,
});

typedef _BuildSignature = ({
  TextScaler scaler,
  MuiTypography text,
  Locale? locale,
});

// 没 build 的孩子不按平均高度外推：量过的用真值，没量过的不算
class _ExtentDelegate extends SliverChildBuilderDelegate {
  const _ExtentDelegate(
    super.builder, {
    required super.childCount,
    required super.findChildIndexCallback,
    required this.extentOf,
  });

  final double? Function(int sliverIndex) extentOf;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    var total = trailingScrollOffset;
    for (var i = lastIndex + 1; i < childCount!; i++) {
      final extent = extentOf(i);
      if (extent == null) return total;
      total += extent;
    }
    return total;
  }
}

/// 跟随只由用户动作改写，永远不加「几何」一项：程序性落位常恰好在底部
enum FollowCause { drag, pinRequest, blockTap, session }

/// 唯一实例：Scrollable 每次 MediaQuery 变化都比 runtimeType，不同就重建 position
class _ChatScrollPhysics extends ScrollPhysics {
  /// 下一次 applyContentDimensions 的落点，infinity = 落底
  final ValueGetter<double?> pendingSnap;
  final VoidCallback onSnapConsumed;

  final ValueGetter<bool> shouldStick;

  final ValueGetter<double?> forwardExtent;

  const _ChatScrollPhysics({
    required this.pendingSnap,
    required this.onSnapConsumed,
    required this.shouldStick,
    required this.forwardExtent,
    super.parent,
  });

  @override
  _ChatScrollPhysics applyTo(ScrollPhysics? ancestor) => _ChatScrollPhysics(
    pendingSnap: pendingSnap,
    onSnapConsumed: onSnapConsumed,
    shouldStick: shouldStick,
    forwardExtent: forwardExtent,
    parent: buildParent(ancestor),
  );

  /// viewport 把 max 夹在 0 之上；forward 组比视口矮时底对齐其实是 F - vp
  double bottomOf(ScrollMetrics m) => chatListBottom(m, forwardExtent());

  // AlwaysScrollableScrollPhysics 会盖掉 allowUserScrolling
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      bottomOf(position) - position.minScrollExtent > precisionErrorTolerance;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final bottom = bottomOf(position);
    if (bottom < position.maxScrollExtent &&
        value > bottom &&
        position.pixels <= bottom) {
      return value - bottom;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final snap = pendingSnap();
    final bottom = bottomOf(newPosition);
    _trace(
      () =>
          'ADJ old=${oldPosition.pixels.toStringAsFixed(1)} new=${newPosition.pixels.toStringAsFixed(1)} min=${newPosition.minScrollExtent.toStringAsFixed(1)} max=${newPosition.maxScrollExtent.toStringAsFixed(1)} bottom=${bottom.toStringAsFixed(1)} vp=${newPosition.viewportDimension.toStringAsFixed(1)} snap=$snap stick=${shouldStick()}',
    );
    if (snap != null) {
      onSnapConsumed();
      if (snap == double.infinity) return bottom;
      return math.min(
        snap.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent),
        bottom,
      );
    }
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    final clamped = bottom < newPosition.maxScrollExtent && adjusted > bottom
        ? bottom
        : adjusted;
    if (isScrolling || velocity != 0) return clamped;
    if (!oldPosition.hasPixels || !oldPosition.hasContentDimensions) {
      return clamped;
    }
    if (shouldStick()) return bottom;
    return adjusted > bottom ? bottom : adjusted;
  }
}

double chatListBottom(ScrollMetrics m, double? forwardExtent) {
  if (forwardExtent == null ||
      !m.hasContentDimensions ||
      !m.hasViewportDimension) {
    return m.maxScrollExtent;
  }
  return math.min(
    m.maxScrollExtent,
    math.max(m.minScrollExtent, forwardExtent - m.viewportDimension),
  );
}

class _ItemKey extends GlobalKey<State<StatefulWidget>> {
  const _ItemKey(this.list, this.id) : super.constructor();

  final AssistantChatListState list;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _ItemKey && identical(other.list, list) && other.id == id;

  @override
  int get hashCode => Object.hash(identityHashCode(list), id);
}

class _ItemScope extends InheritedWidget {
  const _ItemScope({required this.id, required super.child});

  final String id;

  static String? idOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ItemScope>()?.id;

  @override
  bool updateShouldNotify(_ItemScope oldWidget) => false;
}

class AssistantChatList extends StatefulWidget {
  final AssistantChatController controller;

  final AssistantItemBuilder itemBuilder;
  final ScrollController scrollController;

  final double bottomPadding;

  final Widget Function(BuildContext context, bool visible, VoidCallback onTap)
  scrollToBottomBuilder;

  final VoidCallback? onPointerDown;

  static AssistantChatListState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ChatListScope>()?.state;

  const AssistantChatList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.scrollController,
    required this.scrollToBottomBuilder,
    this.bottomPadding = 8,
    this.onPointerDown,
  });

  @override
  State<AssistantChatList> createState() => AssistantChatListState();
}

/// anchor = 0：中心线在屏幕 y = -px；min = -R（reverse 组高），max = max(0, F - vp)。
/// 中心 = 已 build 且上沿 ≤ 0 的条目里最老的一条，所以会长高的东西都在 forward 组，
/// viewport 自己冻结上方的一切。
class AssistantChatListState extends State<AssistantChatList> {
  final _beforeCenterKey = GlobalKey();
  final _centerKey = GlobalKey();

  List<AssistantChatItem> _newestFirst = const [];
  Map<String, int> _indexById = const {};

  /// 中心线 = 该条目的上沿；只在列表为空时为 null
  String? _centerId;

  int get _centerIndex {
    final last = _newestFirst.length - 1;
    final id = _centerId;
    if (id == null) return last;
    return _indexById[id] ?? last;
  }

  String? get _oldestId => _newestFirst.isEmpty ? null : _newestFirst.last.id;

  @visibleForTesting
  int get centerIndex => _centerIndex;

  @visibleForTesting
  int get holdCount => _holds.values.fold(0, (sum, n) => sum + n);

  @visibleForTesting
  int get measuredCount => _extents.length;

  double? _pendingSnap;
  bool _snapConsumed = false;
  bool _snapFallback = true;

  final ValueNotifier<bool> _following = ValueNotifier(true);

  @visibleForTesting
  bool get following => _following.value;

  final ValueNotifier<bool> _atBottom = ValueNotifier(true);

  bool _userDragging = false;

  // 正在就地变高的条目，按引用计数
  final Map<String, int> _holds = {};
  final Map<String, bool> _expanded = {};

  bool _maintainScheduled = false;
  bool _snapClearScheduled = false;

  // 条目正文高度，不含间距/顶部留白
  final Map<String, double> _extents = {};
  _ExtentSignature? _extentSignature;
  _BuildSignature? _buildSignature;
  bool _measureScheduled = false;
  bool _recordScheduled = false;

  int _lastTailRevision = -1;

  bool get contentFitsViewport {
    final p = _position;
    if (p == null || !p.hasContentDimensions) return true;
    return _bottomOf(p) - p.minScrollExtent <= 0.5;
  }

  double? get _forwardExtent {
    final sliver = _centerKey.currentContext?.findRenderObject();
    final geometry = sliver is RenderSliver ? sliver.geometry : null;
    if (geometry == null) return null;
    return geometry.scrollExtent + widget.bottomPadding;
  }

  double _bottomOf(ScrollMetrics m) => chatListBottom(m, _forwardExtent);

  late final _physics = _ChatScrollPhysics(
    pendingSnap: () => _pendingSnap,
    onSnapConsumed: () => _snapConsumed = true,
    shouldStick: () => _following.value,
    forwardExtent: () => _forwardExtent,
  );

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
    _centerId = _initialCenter();
    _lastTailRevision = widget.controller.tailRevision;
    widget.controller.addListener(_onItemsChanged);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_following.value) _requestSnap(double.infinity);
      },
    );
    if (_newestFirst.isNotEmpty) _requestSnap(double.infinity);
  }

  @override
  void didUpdateWidget(covariant AssistantChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onItemsChanged);
      widget.controller.addListener(_onItemsChanged);
      _lastTailRevision = widget.controller.tailRevision;
      _rebuildIndex();
      _centerId = _initialCenter();
      _holds.clear();
      _expanded.clear();
      _setFollowing(true, cause: .session);
      _requestSnap(double.infinity);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onItemsChanged);
    _lifecycle.dispose();
    _following.dispose();
    _atBottom.dispose();
    super.dispose();
  }

  void _rebuildIndex() {
    _newestFirst = widget.controller.items.reversed.toList(growable: false);
    _indexById = {
      for (var i = 0; i < _newestFirst.length; i++) _newestFirst[i].id: i,
    };
  }

  String? _initialCenter() {
    final total = _newestFirst.length;
    if (total == 0) return null;
    final p = _position;
    var reached = 0;
    if (p != null && p.hasViewportDimension) {
      final need =
          p.viewportDimension + RenderAbstractViewport.defaultCacheExtent;
      var sum = widget.bottomPadding;
      for (; reached < total; reached++) {
        final extent = _extentOfIndex(reached);
        if (extent == null) break;
        sum += extent;
        if (sum >= need) return _newestFirst[reached].id;
      }
      if (reached == total) return _oldestId;
    }
    final probe = math.min(_kInitialCenterProbe, total - 1);
    return _newestFirst[math.max(reached, probe)].id;
  }

  double? _extentOfIndex(int index) {
    if (index < 0 || index >= _newestFirst.length) return null;
    final content = _extents[_newestFirst[index].id];
    if (content == null) return null;
    final oldest = index == _newestFirst.length - 1;
    return content + _kItemGap + (oldest ? _kTopPadding : 0);
  }

  bool _measurable(AssistantChatItem item) =>
      item is! AssistantTurn ||
      (!item.streaming && item.toolCalls.every((c) => c.done));

  bool _checkExtentSignature() {
    final width = _listBox?.size.width;
    final built = _buildSignature;
    if (width == null || built == null) return false;
    final signature = (
      width: width,
      scaler: built.scaler,
      text: built.text,
      locale: built.locale,
    );
    if (_extentSignature != signature) {
      _extentSignature = signature;
      _extents.clear();
    }
    return true;
  }

  void _recordBuiltExtents() {
    if (!_checkExtentSignature()) return;
    final live = widget.controller.streaming.value?.id;
    final center = _centerIndex;
    void scan(GlobalKey key, int Function(int sliverIndex) toListIndex) {
      final sliver = key.currentContext?.findRenderObject();
      if (sliver is! RenderSliverMultiBoxAdaptor) return;
      for (
        var child = sliver.firstChild;
        child != null;
        child = sliver.childAfter(child)
      ) {
        if (!child.hasSize) continue;
        final index = toListIndex(sliver.indexOf(child));
        if (index < 0 || index >= _newestFirst.length) continue;
        final item = _newestFirst[index];
        if (item.id == live || _holds.containsKey(item.id)) continue;
        if (!_measurable(item)) continue;
        final oldest = index == _newestFirst.length - 1;
        _extents[item.id] =
            child.size.height - _kItemGap - (oldest ? _kTopPadding : 0);
      }
    }

    scan(_beforeCenterKey, (i) => center + 1 + i);
    scan(_centerKey, (i) => center - i);
  }

  int? _nextUnmeasured() {
    final total = _newestFirst.length;
    final center = _centerIndex;
    final live = widget.controller.streaming.value?.id;
    bool wanted(int index) {
      if (index < 0 || index >= total) return false;
      final item = _newestFirst[index];
      return item.id != live &&
          !_holds.containsKey(item.id) &&
          _measurable(item) &&
          !_extents.containsKey(item.id);
    }

    for (var d = 0; d < total; d++) {
      if (wanted(center - d)) return center - d;
      if (wanted(center + d)) return center + d;
    }
    return null;
  }

  void _scheduleMeasure() {
    if (_measureScheduled || !mounted) return;
    if (_nextUnmeasured() == null) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (mounted) _measureBatch();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool get _measureShouldYield =>
      _userDragging ||
      (_position?.isScrollingNotifier.value ?? false) ||
      widget.controller.streaming.value != null ||
      _holds.isNotEmpty ||
      _pendingSnap != null;

  void _measureBatch() {
    if (!_checkExtentSignature() || _measureShouldYield) return;
    final width = _listBox?.size.width;
    if (width == null) return;
    final measurer = OffscreenMeasurer(
      context,
      viewSize: Size(width, double.infinity),
    );
    final clock = Stopwatch()..start();
    var measured = 0;
    try {
      while (true) {
        final index = _nextUnmeasured();
        if (index == null) break;
        _extents[_newestFirst[index].id] = measurer
            .measure(_measureWidget(index))
            .height;
        measured++;
        if (clock.elapsed >= _kMeasureBudget) break;
      }
    } finally {
      measurer.dispose();
    }
    if (measured == 0) return;
    _trace(() => 'MEASURE $measured items in ${clock.elapsedMilliseconds}ms');
    if (_nextUnmeasured() != null) {
      _scheduleMeasure();
      return;
    }
    for (final key in [_beforeCenterKey, _centerKey]) {
      key.currentContext?.findRenderObject()?.markNeedsLayout();
    }
  }

  // TranslationProvider 的 key 是进程级 GlobalKey，只能补 InheritedLocaleData
  Widget _measureWidget(int index) {
    final item = _newestFirst[index];
    Widget content = _ItemScope(
      id: item.id,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _align(context, item, _newestFirst.length - 1 - index),
      ),
    );
    final locale = context
        .getInheritedWidgetOfExactType<
          InheritedLocaleData<AppLocale, Translations>
        >();
    if (locale != null) {
      content = InheritedLocaleData<AppLocale, Translations>(
        translations: locale.translations,
        child: content,
      );
    }
    return _ChatListScope(state: this, child: content);
  }

  ScrollPosition? get _position => widget.scrollController.hasClients
      ? widget.scrollController.position
      : null;

  double? get _distanceToBottom {
    final position = _position;
    if (position == null || !position.hasContentDimensions) return null;
    return _bottomOf(position) - position.pixels;
  }

  void _setFollowing(bool value, {required FollowCause cause}) {
    if (_following.value == value) return;
    _trace(() => 'following=$value cause=${cause.name}');
    _following.value = value;
  }

  void _syncAtBottom() {
    final distance = _distanceToBottom;
    if (distance == null) return;
    _atBottom.value = distance <= _kBottomSlack;
  }

  // 首帧不经 physics，没被吃掉就补 jumpTo；重定基的落点不能在旧坐标系下补
  void _requestSnap(double target, {bool fallback = true}) {
    _pendingSnap = target;
    _snapConsumed = false;
    _snapFallback = fallback;
    if (_snapClearScheduled) return;
    _snapClearScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapClearScheduled = false;
      final leftover = _snapConsumed || !_snapFallback ? null : _pendingSnap;
      _pendingSnap = null;
      _snapConsumed = false;
      if (!mounted) return;
      final p = _position;
      if (leftover != null && p != null && p.hasContentDimensions) {
        _trace(() => 'snap not consumed, jumpTo $leftover');
        p.jumpTo(
          leftover == double.infinity
              ? p.maxScrollExtent
              : leftover.clamp(p.minScrollExtent, p.maxScrollExtent),
        );
      }
      _syncAtBottom();
      _scheduleMaintainCenter();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onItemsChanged() {
    final previous = _newestFirst;
    _rebuildIndex();
    final wholesale =
        previous.isNotEmpty &&
        !previous.any((e) => _indexById.containsKey(e.id));
    _trace(
      () =>
          'ITEMS ${previous.length} -> ${_newestFirst.length} wholesale=$wholesale phase=${WidgetsBinding.instance.schedulerPhase.name}',
    );
    if (wholesale || previous.isEmpty) {
      _extents.clear();
      _centerId = _initialCenter();
      _holds.clear();
      _expanded.clear();
      _setFollowing(true, cause: .session);
      _requestSnap(double.infinity);
    } else {
      _extents.removeWhere((id, _) => !_indexById.containsKey(id));
      _syncCenter(previous);
    }

    final tail = widget.controller.tailRevision;
    final tailChanged = tail != _lastTailRevision;
    _lastTailRevision = tail;
    if (mounted) setState(() {});
    if (tailChanged && _following.value && !_userDragging) {
      final distance = _distanceToBottom;
      if (distance != null && distance > _kStickEpsilon) {
        _requestSnap(double.infinity);
      }
    }
  }

  void _syncCenter(List<AssistantChatItem> previous) {
    if (_newestFirst.isEmpty) {
      _centerId = null;
      return;
    }
    final id = _centerId;
    if (id == null) {
      _centerId = _oldestId;
      _scheduleMaintainCenter();
      return;
    }
    if (_indexById.containsKey(id)) {
      // 前插后旧最老少了 8px 顶部留白
      if (id == previous.last.id && id != _oldestId) {
        final px = _position?.pixels;
        if (px != null) _requestSnap(px - _kTopPadding, fallback: false);
      }
      _scheduleMaintainCenter();
      return;
    }
    final was = previous.indexWhere((e) => e.id == id);
    final px = _position?.pixels;
    final reverseTrusted = (px ?? 0) <= 0;
    String? pick;
    double? pickTop;
    String? older;
    for (var i = 0; i < previous.length; i++) {
      final candidate = previous[i].id;
      if (!_indexById.containsKey(candidate)) continue;
      if (i > was) {
        older ??= candidate;
        if (!reverseTrusted) continue;
      }
      final top = _topOfItem(candidate);
      if (top == null) continue;
      if (top <= 0 || pickTop == null || (pickTop > 0 && top < pickTop)) {
        pick = candidate;
        pickTop = top;
      }
    }
    final top = pickTop;
    if (pick != null && top != null) {
      _trace(() => 'center removed -> $pick px=${-top}');
      _centerId = pick;
      _requestSnap(-top, fallback: false);
    } else if (older != null) {
      _centerId = older;
      final olderTop = _topOfItem(older);
      if (_following.value) {
        _requestSnap(double.infinity);
      } else if (olderTop != null) {
        _trace(() => 'center removed -> $older px=${-olderTop}');
        _requestSnap(-olderTop, fallback: false);
      } else {
        _requestSnap(0, fallback: false);
      }
    } else {
      _centerId = _oldestId;
      _requestSnap(_following.value ? double.infinity : 0);
    }
    _scheduleMaintainCenter();
  }

  void _scheduleMaintainCenter() {
    if (_maintainScheduled) return;
    _maintainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maintainScheduled = false;
      if (mounted) _maintainCenter();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _scheduleRecordExtents() {
    if (_recordScheduled) return;
    _recordScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordScheduled = false;
      if (mounted) _recordBuiltExtents();
    });
  }

  RenderBox? get _listBox {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  double? _topOfItem(String id) {
    final listBox = _listBox;
    final box = _ItemKey(this, id).currentContext?.findRenderObject();
    if (listBox == null || box is! RenderBox) return null;
    if (!box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: listBox).dy;
  }

  // top 为 null = 视口顶之上没有条目，退到最老并落顶
  ({String id, double? top})? _desiredCenter() {
    final listBox = _listBox;
    final oldest = _oldestId;
    if (listBox == null || oldest == null) return null;
    final center = _centerIndex;
    var best = -1;
    double? bestTop;
    void scan(GlobalKey key, int Function(int sliverIndex) toListIndex) {
      final sliver = key.currentContext?.findRenderObject();
      if (sliver is! RenderSliverMultiBoxAdaptor) return;
      for (
        var child = sliver.firstChild;
        child != null;
        child = sliver.childAfter(child)
      ) {
        if (!child.hasSize) continue;
        final index = toListIndex(sliver.indexOf(child));
        final top = child.localToGlobal(Offset.zero, ancestor: listBox).dy;
        if (top <= 0 && index > best) {
          best = index;
          bestTop = top;
        }
      }
    }

    // px > 0 时 reverse 组的 paint transform 没有意义
    if ((_position?.pixels ?? 0) <= 0) {
      scan(_beforeCenterKey, (i) => center + 1 + i);
    }
    scan(_centerKey, (i) => center - i);
    for (final id in _holds.keys) {
      final index = _indexById[id];
      if (index != null && index > best) {
        best = index;
        bestTop = _topOfItem(id);
      }
    }
    if (best < 0) return (id: oldest, top: null);
    return (id: _newestFirst[best].id, top: bestTop);
  }

  void _maintainCenter() {
    _trace(
      () =>
          'MAINTAIN drag=$_userDragging holds=${_holds.length} center=$_centerIndex/${_newestFirst.length}',
    );
    if (!mounted) return;
    _syncAtBottom();
    _recordBuiltExtents();
    _scheduleMeasure();
    if (_userDragging || _holds.isNotEmpty) return;
    final p = _position;
    if (p == null || !p.hasContentDimensions) return;
    if (p.isScrollingNotifier.value) return;

    final target = _desiredCenter();
    if (target == null || target.id == _centerId) return;
    _moveCenter(target.id, target.top);
  }

  // 用实测位置而不是 Δmin：min 对未 build 的孩子是外推值
  void _moveCenter(String target, double? top) {
    if (top == null) {
      _trace(() => 'center $_centerId -> $target, top-align');
      _requestSnap(0, fallback: false);
      setState(() => _centerId = target);
      return;
    }
    final stickToBottom = _following.value && _atBottom.value;
    _trace(() {
      final p = _position;
      return 'center $_centerId -> $target top=$top px=${stickToBottom ? 'bottom' : -top} (was px=${p?.pixels.toStringAsFixed(1)} min=${p?.minScrollExtent.toStringAsFixed(1)} max=${p?.maxScrollExtent.toStringAsFixed(1)})';
    });
    _requestSnap(stickToBottom ? double.infinity : -top, fallback: false);
    setState(() => _centerId = target);
  }

  bool expandedOf(BuildContext itemContext, String key) {
    final id = _ItemScope.idOf(itemContext);
    return id != null && (_expanded['$id/$key'] ?? false);
  }

  void setExpanded(BuildContext itemContext, String key, bool value) {
    final id = _ItemScope.idOf(itemContext);
    if (id == null || _expanded['$id/$key'] == value) return;
    _expanded['$id/$key'] = value;
    _extents.remove(id);
  }

  // 块可能在动画中被回收，那时 context 已不可用，所以回 id
  String? beginItemResize(BuildContext itemContext) {
    final id = _ItemScope.idOf(itemContext);
    if (id == null) return null;
    _setFollowing(false, cause: .blockTap);
    _holds.update(id, (n) => n + 1, ifAbsent: () => 1);
    final index = _indexById[id];
    if (index != null && index > _centerIndex) {
      _moveCenter(id, _topOfItem(id));
    }
    return id;
  }

  void endItemResize(String id) {
    final left = (_holds[id] ?? 1) - 1;
    if (left > 0) {
      _holds[id] = left;
    } else {
      _holds.remove(id);
    }
    // 可能从 dispose 里来，树是锁着的
    if (mounted && _holds.isEmpty) _scheduleMaintainCenter();
  }

  void pinToBottom() {
    _setFollowing(true, cause: .pinRequest);
    _userDragging = false;
    final id = _initialCenter();
    if (id != null && id != _centerId) setState(() => _centerId = id);
    _requestSnap(double.infinity);
    final p = _position;
    if (p != null && p.hasContentDimensions) p.jumpTo(_bottomOf(p));
  }

  bool _onScrollNotification(Notification notification) {
    // 不是 ScrollNotification 的子类
    if (notification is ScrollMetricsNotification) {
      if (notification.depth == 0 && notification.metrics.axis == .vertical) {
        _syncAtBottom();
        _scheduleRecordExtents();
        if (_following.value &&
            _atBottom.value &&
            !_userDragging &&
            _holds.isEmpty &&
            _centerIndex + 1 > _kForwardGroupCap) {
          _scheduleMaintainCenter();
        }
      }
      return false;
    }
    if (notification is! ScrollNotification) return false;
    if (notification.depth != 0 || notification.metrics.axis != .vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _userDragging = true;
        _setFollowing((_distanceToBottom ?? 0) <= _kBottomSlack, cause: .drag);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      _syncAtBottom();
      if (_userDragging) {
        _setFollowing((_distanceToBottom ?? 0) <= _kBottomSlack, cause: .drag);
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final wasUserScroll = _userDragging;
      _userDragging = false;
      _syncAtBottom();
      if (wasUserScroll) {
        _setFollowing((_distanceToBottom ?? 0) <= _kBottomSlack, cause: .drag);
      }
      _scheduleMaintainCenter();
      return false;
    }

    return false;
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _newestFirst[index];
    final chronological = _newestFirst.length - 1 - index;
    // 顶部留白折进最老一条，独立 padding sliver 会让 min 多 8px
    final oldest = index == _newestFirst.length - 1;
    return KeyedSubtree(
      key: _ItemKey(this, item.id),
      child: _ItemScope(
        id: item.id,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            oldest ? _kTopPadding : 0,
            16,
            _kItemGap,
          ),
          child: item is AssistantTurn && item.streaming
              ? ValueListenableBuilder<AssistantTurn?>(
                  valueListenable: widget.controller.streaming,
                  builder: (context, live, _) => _align(
                    context,
                    live != null && live.id == item.id ? live : item,
                    chronological,
                  ),
                )
              : _align(context, item, chronological),
        ),
      ),
    );
  }

  Widget _align(BuildContext context, AssistantChatItem item, int index) {
    final fromUser = item is AssistantTurn && item.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: widget.itemBuilder(context, item, index),
    );
  }

  int? _indexOfKey(Key key) => key is _ItemKey ? _indexById[key.id] : null;

  int? _findBeforeCenter(Key key) {
    final index = _indexOfKey(key);
    if (index == null) return null;
    final center = _centerIndex;
    return index > center ? index - center - 1 : null;
  }

  int? _findCenter(Key key) {
    final index = _indexOfKey(key);
    if (index == null) return null;
    final center = _centerIndex;
    return index <= center ? center - index : null;
  }

  void _onToBottomTap() {
    widget.onPointerDown?.call();
    pinToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final center = _centerIndex;
    final total = _newestFirst.length;
    _buildSignature = (
      scaler: MediaQuery.textScalerOf(context),
      text: context.theme.typography,
      locale: Localizations.maybeLocaleOf(context),
    );
    return _ChatListScope(
      state: this,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => widget.onPointerDown?.call(),
              child: NotificationListener<Notification>(
                onNotification: _onScrollNotification,
                child: CustomScrollView(
                  controller: widget.scrollController,
                  physics: _physics,
                  anchor: 0,
                  center: _centerKey,
                  slivers: [
                    SliverList(
                      key: _beforeCenterKey,
                      delegate: _ExtentDelegate(
                        (context, i) => _buildItem(context, center + 1 + i),
                        childCount: math.max(0, total - 1 - center),
                        findChildIndexCallback: _findBeforeCenter,
                        extentOf: (i) => _extentOfIndex(center + 1 + i),
                      ),
                    ),
                    SliverList(
                      key: _centerKey,
                      delegate: _ExtentDelegate(
                        (context, i) => _buildItem(context, center - i),
                        childCount: math.min(center + 1, total),
                        findChildIndexCallback: _findCenter,
                        extentOf: (i) => _extentOfIndex(center - i),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: widget.bottomPadding),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _atBottom,
            builder: (context, atBottom, _) => widget.scrollToBottomBuilder(
              context,
              !atBottom && !contentFitsViewport,
              _onToBottomTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListScope extends InheritedWidget {
  const _ChatListScope({required this.state, required super.child});

  final AssistantChatListState state;

  @override
  bool updateShouldNotify(_ChatListScope oldWidget) => false;
}
