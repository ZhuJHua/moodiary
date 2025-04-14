import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Color debugPaintExpandAreaColor = const Color(
  0xFFFF0000,
).withValues(alpha: 0.03);

Color debugPaintClipAreaColor = const Color(0xFF0000FF).withValues(alpha: 0.02);

class ExpandTapWidget extends SingleChildRenderObjectWidget {
  const ExpandTapWidget({
    super.key,
    super.child,
    required this.onTap,
    required this.tapPadding,
  });

  final VoidCallback onTap;
  final EdgeInsets tapPadding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ExpandTapRenderBox(onTap: onTap, tapPadding: tapPadding);

  @override
  void updateRenderObject(BuildContext context, RenderBox renderObject) {
    renderObject as _ExpandTapRenderBox;
    if (renderObject.tapPadding != tapPadding) {
      renderObject.tapPadding = tapPadding;
    }
    if (renderObject.onTap != onTap) {
      renderObject.onTap = onTap;
    }
  }
}

class _TmpGestureArenaMember extends GestureArenaMember {
  _TmpGestureArenaMember({required this.onTap});

  final VoidCallback onTap;

  @override
  void acceptGesture(int key) {
    onTap();
  }

  @override
  void rejectGesture(int key) {}
}

class _ExpandTapRenderBox extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _ExpandTapRenderBox({
    required VoidCallback onTap,
    required EdgeInsets tapPadding,
  }) : _onTap = onTap,
       _tapPadding = tapPadding;

  VoidCallback _onTap;
  EdgeInsets _tapPadding;

  set onTap(VoidCallback value) {
    if (_onTap != value) {
      _onTap = value;
    }
  }

  set tapPadding(EdgeInsets value) {
    if (_tapPadding == value) return;
    _tapPadding = value;
    markNeedsPaint();
  }

  EdgeInsets get tapPadding => _tapPadding;

  VoidCallback get onTap => _onTap;

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = child!.size;
    if (size.isEmpty) {
      _tapPadding = EdgeInsets.zero;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      context.paintChild(child!, childParentData.offset + offset);
    }
    assert(() {
      debugPaintExpandArea(context, offset);
      return true;
    }());
  }

  void debugPaintExpandArea(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;

    final RenderBox parentBox = parent as RenderBox;

    Offset parentPosition = Offset.zero;
    parentPosition = offset - localToGlobal(Offset.zero, ancestor: parentBox);

    final Size parentSize = parentBox.size;
    final Rect parentRect = Rect.fromLTWH(
      parentPosition.dx,
      parentPosition.dy,
      parentSize.width,
      parentSize.height,
    );
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    final Offset paintOffset =
        childParentData.offset + offset - tapPadding.topLeft;
    final Rect paintRect = Rect.fromLTWH(
      paintOffset.dx,
      paintOffset.dy,
      size.width + tapPadding.horizontal,
      size.height + tapPadding.vertical,
    );
    final Paint paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 1.0
          ..color = debugPaintExpandAreaColor;

    final Paint paint2 =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 1.0
          ..color = debugPaintClipAreaColor;
    context.canvas.drawRect(paintRect, paint);
    context.canvas.drawRect(paintRect.intersect(parentRect), paint2);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final _TmpGestureArenaMember member = _TmpGestureArenaMember(
        onTap: onTap,
      );
      GestureBinding.instance.gestureArena.add(event.pointer, member);
    } else if (event is PointerUpEvent) {
      GestureBinding.instance.gestureArena.sweep(event.pointer);
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset? position}) {
    visitChildren((child) {
      if (child is RenderBox) {
        final BoxParentData parentData = child.parentData! as BoxParentData;
        if (child.hitTest(result, position: position! - parentData.offset)) {
          return;
        }
      }
    });
    return false;
  }

  @override
  bool hitTest(BoxHitTestResult result, {Offset? position}) {
    final Rect expandRect = Rect.fromLTWH(
      0 - tapPadding.left,
      0 - tapPadding.top,
      size.width + tapPadding.right + tapPadding.left,
      size.height + tapPadding.top + tapPadding.bottom,
    );
    if (expandRect.contains(position!)) {
      final bool hitTarget =
          hitTestChildren(result, position: position) || hitTestSelf(position);
      if (hitTarget) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return false;
  }
}
