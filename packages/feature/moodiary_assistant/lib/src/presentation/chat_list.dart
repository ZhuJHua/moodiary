import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:mui/mui.dart';

typedef AssistantItemBuilder = Widget Function(
  BuildContext context,
  AssistantChatItem item,
  int index,
);

const double _kBottomSlack = 8;

const double _kItemGap = 12;
const double _kTopPadding = 8;

const double _kStickEpsilon = 0.5;

const int _kShrinkWrapProbe = 24;

class _StickToBottomScrollPhysics extends AlwaysScrollableScrollPhysics {
  final ValueGetter<bool> shouldStick;

  final ValueGetter<bool> userScrollingEnabled;
  final ValueGetter<bool> snapToBottomNow;

  const _StickToBottomScrollPhysics({
    required this.shouldStick,
    required this.userScrollingEnabled,
    required this.snapToBottomNow,
    super.parent,
  });

  @override
  _StickToBottomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _StickToBottomScrollPhysics(
      shouldStick: shouldStick,
      userScrollingEnabled: userScrollingEnabled,
      snapToBottomNow: snapToBottomNow,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool get allowUserScrolling => userScrollingEnabled();

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (snapToBottomNow()) return newPosition.maxScrollExtent;
    if (!userScrollingEnabled()) {
      return adjusted.clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    if (isScrolling || velocity != 0) return adjusted;
    if (!shouldStick()) return adjusted;
    if (!oldPosition.hasPixels || !oldPosition.hasContentDimensions) {
      return adjusted;
    }
    if (oldPosition.maxScrollExtent - oldPosition.pixels > _kStickEpsilon) {
      return adjusted;
    }
    return newPosition.maxScrollExtent;
  }
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

class AssistantChatList extends StatefulWidget {
  final AssistantChatController controller;

  final AssistantItemBuilder itemBuilder;
  final ScrollController scrollController;

  final double bottomPadding;

  final Widget Function(BuildContext context, bool visible, VoidCallback onTap)
  scrollToBottomBuilder;

  final VoidCallback? onPointerDown;

  static AssistantChatListState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChatListScope>()?.state;

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

class AssistantChatListState extends State<AssistantChatList> {
  final _listKey = GlobalKey();

  final _beforeCenterKey = GlobalKey();

  final _centerKey = GlobalKey();

  List<AssistantChatItem> _newestFirst = const [];
  Map<String, int> _indexById = const {};
  String? _centerId;

  int get _centerIndex {
    final id = _centerId;
    if (id == null) return 0;
    return _indexById[id] ?? 0;
  }

  bool _isShrinkWrap = true;

  double _viewportMainExtent = 0;
  bool _branchCheckScheduled = false;

  bool _flipSnapPending = false;

  final ValueNotifier<bool> _following = ValueNotifier(true);

  int _pinGeneration = 0;

  bool _pinning = false;

  bool _userDragging = false;

  int _lastTailRevision = -1;

  bool get contentFitsViewport => _isShrinkWrap;

  late final _physics = _StickToBottomScrollPhysics(
    shouldStick: () => !_isShrinkWrap && _following.value,
    userScrollingEnabled: () => !_isShrinkWrap,
    snapToBottomNow: () => _flipSnapPending,
  );

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
    _isShrinkWrap = _newestFirst.length <= _kShrinkWrapProbe;
    _centerId = _pickCenter();
    _lastTailRevision = widget.controller.tailRevision;
    widget.controller.addListener(_onItemsChanged);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_following.value) _pinToBottom();
      },
    );
    if (!_isShrinkWrap) _pinToBottom();
  }

  @override
  void didUpdateWidget(covariant AssistantChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onItemsChanged);
      widget.controller.addListener(_onItemsChanged);
      _lastTailRevision = widget.controller.tailRevision;
      _rebuildIndex();
      _isShrinkWrap = _newestFirst.length <= _kShrinkWrapProbe;
      _centerId = _pickCenter();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onItemsChanged);
    _lifecycle.dispose();
    _following.dispose();
    super.dispose();
  }

  void _rebuildIndex() {
    _newestFirst = widget.controller.items.reversed.toList(growable: false);
    _indexById = {
      for (var i = 0; i < _newestFirst.length; i++) _newestFirst[i].id: i,
    };
  }

  ScrollPosition? get _position => widget.scrollController.hasClients
      ? widget.scrollController.position
      : null;

  double? get _distanceToBottom {
    final position = _position;
    if (position == null) return null;
    return position.maxScrollExtent - position.pixels;
  }

  String? _pickCenter() {
    for (final item in _newestFirst) {
      if (item is AssistantTurn && item.streaming) continue;
      return item.id;
    }
    return _newestFirst.isEmpty ? null : _newestFirst.first.id;
  }

  void _enterBidirectional() {
    _isShrinkWrap = false;
    _centerId = _pickCenter();
    _flipSnapPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flipSnapPending = false;
      if (!mounted || _isShrinkWrap) return;
      final position = _position;
      if (position == null || !position.hasContentDimensions) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    });
  }

  void _enterShrinkWrap() {
    _isShrinkWrap = true;
    _pinGeneration++;
    _pinning = false;
    _following.value = true;
  }

  void _onItemsChanged() {
    final previous = _newestFirst;
    _rebuildIndex();
    final wholesale =
        previous.isNotEmpty &&
        !previous.any((e) => _indexById.containsKey(e.id));
    if (wholesale) {
      if (_newestFirst.length <= _kShrinkWrapProbe) {
        _enterShrinkWrap();
      } else {
        _enterBidirectional();
        _following.value = true;
      }
    } else if (_isShrinkWrap) {
      if (_newestFirst.length > _kShrinkWrapProbe) _enterBidirectional();
    } else {
      _syncCenter(previous);
      _advanceCenter();
    }

    final tail = widget.controller.tailRevision;
    final tailChanged = tail != _lastTailRevision;
    _lastTailRevision = tail;
    if (mounted) setState(() {});
    if (tailChanged && _following.value && !_userDragging) _pinToBottom();
  }

  void _syncCenter(List<AssistantChatItem> previous) {
    if (_newestFirst.isEmpty) {
      _centerId = null;
      return;
    }
    final id = _centerId;
    if (id != null && _indexById.containsKey(id)) return;
    if (id != null) {
      final was = previous.indexWhere((e) => e.id == id);
      if (was >= 0) {
        for (var i = was + 1; i < previous.length; i++) {
          final candidate = previous[i].id;
          if (_indexById.containsKey(candidate)) {
            _centerId = candidate;
            return;
          }
        }
      }
    }
    _centerId = _pickCenter();
  }

  void _advanceCenter() {
    if (!_following.value || _userDragging) return;
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    if (position.maxScrollExtent - position.pixels > _kStickEpsilon) return;
    final target = _pickCenter();
    if (target != null && target != _centerId) _centerId = target;
  }

  void releaseFollow() {
    _pinGeneration++;
    _pinning = false;
    _following.value = false;
  }

  bool isInForwardGroup(BuildContext itemContext) {
    final center = _centerKey.currentContext?.findRenderObject();
    if (center == null) return false;
    RenderObject? node = itemContext.findRenderObject();
    while (node != null) {
      if (identical(node, center)) return true;
      node = node.parent;
    }
    return false;
  }

  void syncFollowFromPosition() {
    _scheduleBranchCheck();
    if (_isShrinkWrap) {
      _following.value = true;
      return;
    }
    final distance = _distanceToBottom;
    if (distance != null) _following.value = distance <= _kBottomSlack;
  }

  void pinToBottom() {
    _following.value = true;
    _pinToBottom();
  }

  Future<void> _pinToBottom() async {
    if (_isShrinkWrap) return;
    final generation = ++_pinGeneration;
    _pinning = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _pinGeneration) return;
      if (_isShrinkWrap || _userDragging) return;
      final position = _position;
      if (position == null) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    } finally {
      if (generation == _pinGeneration) _pinning = false;
    }
  }

  void _scheduleBranchCheck() {
    if (_branchCheckScheduled) return;
    _branchCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _branchCheckScheduled = false;
      if (!mounted) return;
      if (_userDragging) return;
      final exceeds = _contentExceedsViewport();
      if (exceeds == null || exceeds != _isShrinkWrap) return;
      setState(() {
        if (exceeds) {
          _enterBidirectional();
        } else {
          _enterShrinkWrap();
        }
      });
    });
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool? _contentExceedsViewport() {
    if (_viewportMainExtent <= 0) return null;
    if (_isShrinkWrap) {
      final box = _listKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return null;
      return box.size.height >= _viewportMainExtent + 0.0005;
    }
    final total = _totalSliverExtent();
    if (total == null) return null;
    return total > _viewportMainExtent;
  }

  double? _totalSliverExtent() {
    RenderObject? node = _centerKey.currentContext?.findRenderObject();
    while (node != null && node is! RenderViewport) {
      node = node.parent;
    }
    if (node is! RenderViewport) return null;
    var total = 0.0;
    for (
      var sliver = node.firstChild;
      sliver != null;
      sliver = node.childAfter(sliver)
    ) {
      final geometry = sliver.geometry;
      if (geometry == null) return null;
      total += geometry.scrollExtent;
    }
    return total;
  }

  bool _onScrollNotification(Notification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _userDragging = true;
        _pinGeneration++;
        _pinning = false;
        if (!_isShrinkWrap) {
          _following.value = (_distanceToBottom ?? 0) <= _kBottomSlack;
        }
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final wasUserScroll = _userDragging;
      _userDragging = false;
      if (!_isShrinkWrap && wasUserScroll) {
        final distance = _distanceToBottom;
        if (distance != null) _following.value = distance <= _kBottomSlack;
      }
      _scheduleBranchCheck();
      return false;
    }

    if (_isShrinkWrap) return false;

    if (notification is ScrollMetricsNotification) {
      if (_userDragging) return false;
      if (_following.value && !_pinning) _pinToBottom();
      _scheduleBranchCheck();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (_pinning || !_userDragging) return false;
      final distance = _distanceToBottom;
      if (distance != null) _following.value = distance <= _kBottomSlack;
    }
    return false;
  }

  Widget _buildItem(BuildContext context, int index) {
    final item = _newestFirst[index];
    final chronological = _newestFirst.length - 1 - index;
    return KeyedSubtree(
      key: _ItemKey(this, item.id),
      child: Padding(
        padding: const .fromLTRB(16, 0, 16, _kItemGap),
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
    );
  }

  Widget _align(BuildContext context, AssistantChatItem item, int index) {
    final fromUser = item is AssistantTurn && item.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: widget.itemBuilder(context, item, index),
    );
  }

  int? _findShrink(Key key) => _indexById[(key as _ItemKey).id];

  int? _findBeforeCenter(Key key) {
    final index = _indexById[(key as _ItemKey).id];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= center ? index - center : null;
  }

  int? _findCenter(Key key) {
    final index = _indexById[(key as _ItemKey).id];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= 0 && index < center ? center - index - 1 : null;
  }

  Widget _buildList(BoxConstraints constraints) {
    final center = _centerIndex;
    final total = _newestFirst.length;
    return SingleChildScrollView(
      primary: false,
      child: Container(
        alignment: .topCenter,
        height: constraints.maxHeight + 0.001,
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _scheduleBranchCheck();
            return true;
          },
          child: SizeChangedLayoutNotifier(
            child: CustomScrollView(
              key: _listKey,
              controller: widget.scrollController,
              physics: _physics,
              reverse: _isShrinkWrap,
              shrinkWrap: _isShrinkWrap,
              center: _isShrinkWrap ? null : _centerKey,
              anchor: _isShrinkWrap ? 0 : 1,
              slivers: _isShrinkWrap
                  ? [
                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.bottomPadding),
                      ),
                      SliverList.builder(
                        itemCount: total,
                        findChildIndexCallback: _findShrink,
                        itemBuilder: _buildItem,
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kTopPadding),
                      ),
                    ]
                  : [
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kTopPadding),
                      ),
                      SliverList.builder(
                        key: _beforeCenterKey,
                        itemCount: (total - center).clamp(0, total),
                        findChildIndexCallback: _findBeforeCenter,
                        itemBuilder: (context, i) =>
                            _buildItem(context, center + i),
                      ),
                      SliverList.builder(
                        key: _centerKey,
                        itemCount: center,
                        findChildIndexCallback: _findCenter,
                        itemBuilder: (context, i) =>
                            _buildItem(context, center - i - 1),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.bottomPadding),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportMainExtent = constraints.maxHeight;
                    _scheduleBranchCheck();
                    return _buildList(constraints);
                  },
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _following,
            builder: (context, following, _) => widget.scrollToBottomBuilder(
              context,
              !following && !_isShrinkWrap,
              pinToBottom,
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
  bool updateShouldNotify(_ChatListScope oldWidget) =>
      !identical(state, oldWidget.state);
}
