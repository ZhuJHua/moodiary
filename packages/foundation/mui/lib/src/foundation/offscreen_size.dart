import 'package:flutter/rendering.dart';
import 'package:mui/mui.dart';

Size getWidgetSizeOffScreen({
  required BuildContext context,
  required Widget widget,
  required Size viewSize,
}) {
  final root = _MeasureRoot(
    BoxConstraints(maxWidth: viewSize.width, maxHeight: viewSize.height),
  );

  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  pipelineOwner.rootNode = root;
  root.scheduleInitialLayout();

  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: root,
    child: InheritedTheme.captureAll(
      context,
      Directionality(
        textDirection: Directionality.of(context),
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Builder(builder: (_) => widget),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  try {
    pipelineOwner.flushLayout();
    return root.size;
  } finally {
    element.update(RenderObjectToWidgetAdapter<RenderBox>(container: root));
    buildOwner.finalizeTree();
  }
}

class _MeasureRoot extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _MeasureRoot(this.childConstraints);

  final BoxConstraints childConstraints;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    child.layout(childConstraints, parentUsesSize: true);
    size = child.size;
  }

  @override
  void debugAssertDoesMeetConstraints() {}
}
