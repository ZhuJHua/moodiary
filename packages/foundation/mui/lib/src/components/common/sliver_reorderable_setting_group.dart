import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show clampDouble, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:mui/mui.dart';

typedef MReorderableItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  Widget handle,
);

class MSliverReorderableSettingGroup<T extends Object> extends StatelessWidget {
  final String? title;

  final List<T> items;

  final MReorderableItemBuilder<T> itemBuilder;

  // to 是移除 from 之后的插入下标
  final void Function(int from, int to) onReorder;

  final Color? color;

  final bool reorderable;

  const MSliverReorderableSettingGroup({
    super.key,
    this.title,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.color,
    this.reorderable = true,
  });

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      if (title != null)
        SliverToBoxAdapter(child: SettingTitleTile(title: title)),
      SliverToBoxAdapter(
        child: _ReorderableGroup<T>(
          items: items,
          itemBuilder: itemBuilder,
          onReorder: onReorder,
          color: color,
          reorderable: reorderable,
        ),
      ),
    ],
  );
}

class _ReorderableGroup<T extends Object> extends StatefulWidget {
  final List<T> items;
  final MReorderableItemBuilder<T> itemBuilder;
  final void Function(int from, int to) onReorder;
  final Color? color;
  final bool reorderable;

  const _ReorderableGroup({
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    required this.reorderable,
    this.color,
  });

  @override
  State<_ReorderableGroup<T>> createState() => _ReorderableGroupState<T>();
}

class _Drag {
  final int from;
  final List<double> heights;
  final double groupHeight;
  final double grabDy;
  Offset pointer;
  int target;
  bool settling = false;
  double settleFrom = 0;

  _Drag({
    required this.from,
    required this.heights,
    required this.groupHeight,
    required this.grabDy,
    required this.pointer,
  }) : target = from;

  double get height => heights[from];

  int slotOf(int i) {
    if (i == from) return target;
    final rank = i < from ? i : i - 1;
    return rank < target ? rank : rank + 1;
  }

  double slotTop(int slot) {
    var y = 0.0;
    for (var i = 0; i < heights.length; i++) {
      if (slotOf(i) < slot) y += heights[i];
    }
    return y;
  }

  // 取离拖动行顶边最近的槽位，行高不等时也对称
  int targetFor(double top) {
    var y = 0.0;
    var slot = 0;
    for (var i = 0; i < heights.length; i++) {
      if (i == from) continue;
      if (top <= y + heights[i] / 2) break;
      y += heights[i];
      slot++;
    }
    return slot;
  }
}

double _restTop(List<double> heights, int i) =>
    heights.take(i).fold(0, (a, b) => a + b);

class _ReorderableGroupState<T extends Object>
    extends State<_ReorderableGroup<T>>
    with TickerProviderStateMixin {
  static const _slide = Duration(milliseconds: 220);
  static const _fade = Duration(milliseconds: 150);
  static const _curve = Curves.easeOutCubic;

  final _stackKey = GlobalKey();
  final _rowKeys = <T, GlobalKey>{};
  final _top = ValueNotifier(0.0);

  late final _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: _slide,
  );
  late final _settle = AnimationController(vsync: this, duration: _slide)
    ..addStatusListener((status) {
      if (status == .completed) _commit();
    });

  ImmediateMultiDragGestureRecognizer? _handleRecognizer;
  DelayedMultiDragGestureRecognizer? _pressRecognizer;
  EdgeDraggingAutoScroller? _autoScroller;

  _Drag? _drag;
  int _generation = 0;

  GlobalKey _keyOf(T item) => _rowKeys.putIfAbsent(item, GlobalKey.new);

  RenderBox get _stackBox =>
      _stackKey.currentContext!.findRenderObject()! as RenderBox;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null && _autoScroller?.scrollable != scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        scrollable,
        onScrollViewScrolled: _follow,
        velocityScalar: 50,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _ReorderableGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rowKeys.removeWhere((item, _) => !widget.items.contains(item));
    if (_drag != null &&
        (!widget.reorderable || !listEquals(widget.items, oldWidget.items))) {
      _autoScroller?.stopAutoScroll();
      _settle.stop();
      _lift.value = 0;
      _drag = null;
      _generation++;
    }
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _handleRecognizer?.dispose();
    _pressRecognizer?.dispose();
    _lift.dispose();
    _settle.dispose();
    _top.dispose();
    super.dispose();
  }

  void _pointerDownOnHandle(PointerDownEvent event, int index) => _track(
    _handleRecognizer ??= ImmediateMultiDragGestureRecognizer(debugOwner: this),
    event,
    index,
  );

  void _pointerDownOnRow(PointerDownEvent event, int index) => _track(
    _pressRecognizer ??= DelayedMultiDragGestureRecognizer(debugOwner: this),
    event,
    index,
  );

  // 滚动视图用设备 touch slop，这里不跟上就永远抢不过它
  void _track(
    MultiDragGestureRecognizer recognizer,
    PointerDownEvent event,
    int index,
  ) {
    if (!widget.reorderable) return;
    recognizer.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    recognizer.onStart = (position) => _start(index, position);
    recognizer.addPointer(event);
  }

  Drag? _start(int index, Offset position) {
    if (_drag != null || !mounted) return null;
    final stack = _stackBox;
    final heights = [
      for (final item in widget.items)
        (_keyOf(item).currentContext!.findRenderObject()! as RenderBox)
            .size
            .height,
    ];
    final top = _restTop(heights, index);
    setState(() {
      _drag = _Drag(
        from: index,
        heights: heights,
        groupHeight: stack.size.height,
        grabDy: stack.globalToLocal(position).dy - top,
        pointer: position,
      );
    });
    _top.value = top;
    _lift.forward(from: 0);
    return _DragSession(onUpdate: _update, onEnd: _end);
  }

  void _update(Offset pointer) {
    final drag = _drag;
    if (drag == null || drag.settling) return;
    drag.pointer = pointer;
    _follow();
  }

  void _follow() {
    final drag = _drag;
    if (drag == null || drag.settling || !mounted) return;
    final stack = _stackBox;
    final top = clampDouble(
      stack.globalToLocal(drag.pointer).dy - drag.grabDy,
      0,
      math.max(0, drag.groupHeight - drag.height),
    );
    _top.value = top;
    final target = drag.targetFor(top);
    if (target != drag.target) setState(() => drag.target = target);
    _autoScroller?.startAutoScrollIfNecessary(
      stack.localToGlobal(Offset(0, top)) & Size(stack.size.width, drag.height),
    );
  }

  void _end() {
    final drag = _drag;
    if (drag == null || drag.settling) return;
    _autoScroller?.stopAutoScroll();
    setState(() {
      drag
        ..settling = true
        ..settleFrom = _top.value;
    });
    _lift.reverse();
    _settle.forward(from: 0);
  }

  void _commit() {
    final drag = _drag;
    if (drag == null) return;
    if (drag.target != drag.from) widget.onReorder(drag.from, drag.target);
    _lift.value = 0;
    setState(() {
      _drag = null;
      _generation++;
    });
  }

  void _moveBy(int index, int delta) {
    final to = index + delta;
    if (_drag != null || to < 0 || to >= widget.items.length) return;
    widget.onReorder(index, to);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = context.theme;
    final l10n = context.muiL10n;
    final radius = Radius.circular(theme.radii.lg);
    final fill = widget.color ?? theme.colors.surfaceContainerLow;
    final drag = _drag;
    final last = items.length - 1;

    Widget handle(int index) => Listener(
      onPointerDown: (e) => _pointerDownOnHandle(e, index),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(
          LucideIcons.gripVertical,
          color: theme.colors.onSurfaceVariant,
        ),
      ),
    );

    Widget row(int i, Widget divider) {
      final item = items[i];
      return Semantics(
        customSemanticsActions: {
          if (widget.reorderable && i > 0)
            CustomSemanticsAction(label: l10n.moveUp): () => _moveBy(i, -1),
          if (widget.reorderable && i < last)
            CustomSemanticsAction(label: l10n.moveDown): () => _moveBy(i, 1),
        },
        child: Listener(
          behavior: .opaque,
          onPointerDown: (e) => _pointerDownOnRow(e, i),
          child: Stack(
            fit: .passthrough,
            children: [
              KeyedSubtree(
                key: _keyOf(item),
                child: widget.itemBuilder(context, item, handle(i)),
              ),
              Positioned(left: 0, right: 0, bottom: 0, child: divider),
            ],
          ),
        ),
      );
    }

    Widget resting(int i) {
      final slot = drag?.slotOf(i) ?? i;
      final aboveHole =
          drag != null && !drag.settling && slot == drag.target - 1;
      return TweenAnimationBuilder<double>(
        key: ValueKey((_generation, items[i])),
        tween: Tween(
          end: drag == null
              ? 0
              : drag.slotTop(slot) - _restTop(drag.heights, i),
        ),
        duration: _slide,
        curve: _curve,
        builder: (_, dy, child) =>
            Transform.translate(offset: Offset(0, dy), child: child),
        child: row(
          i,
          AnimatedOpacity(
            opacity: slot == last || aboveHole ? 0 : 1,
            duration: _fade,
            child: const MSettingDivider(),
          ),
        ),
      );
    }

    Widget floating(_Drag drag) {
      final slot = drag.settling ? drag.target : drag.from;
      final landing = drag.slotTop(drag.target);
      return AnimatedBuilder(
        animation: Listenable.merge([_lift, _settle, _top]),
        builder: (_, child) => Positioned(
          top: drag.settling
              ? lerpDouble(
                  drag.settleFrom,
                  landing,
                  _curve.transform(_settle.value),
                )
              : _top.value,
          left: 0,
          right: 0,
          child: ColoredBox(
            color: Color.lerp(
              fill,
              theme.colors.surfaceContainerHighest,
              _lift.value,
            )!,
            child: child,
          ),
        ),
        child: row(
          drag.from,
          FadeTransition(
            opacity: slot == last
                ? kAlwaysDismissedAnimation
                : ReverseAnimation(_lift),
            child: const MSettingDivider(),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: .all(radius)),
      ),
      child: ClipRRect(
        borderRadius: .all(radius),
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                for (var i = 0; i <= last; i++)
                  if (drag != null && i == drag.from)
                    SizedBox(
                      key: ValueKey((_generation, items[i])),
                      height: drag.height,
                    )
                  else
                    resting(i),
              ],
            ),
            if (drag != null) floating(drag),
          ],
        ),
      ),
    );
  }
}

class _DragSession extends Drag {
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  _DragSession({required this.onUpdate, required this.onEnd});

  @override
  void update(DragUpdateDetails details) => onUpdate(details.globalPosition);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onEnd();
}
