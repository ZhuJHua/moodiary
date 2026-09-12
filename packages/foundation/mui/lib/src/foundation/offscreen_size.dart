import 'package:flutter/rendering.dart';
import 'package:mui/mui.dart';

class OffscreenMeasurer {
  OffscreenMeasurer(this._context, {required Size viewSize})
    : _root = _MeasureRoot(
        BoxConstraints(maxWidth: viewSize.width, maxHeight: viewSize.height),
      ) {
    _pipelineOwner.rootNode = _root;
    _root.scheduleInitialLayout();
  }

  final BuildContext _context;
  final _MeasureRoot _root;
  final PipelineOwner _pipelineOwner = PipelineOwner();
  final BuildOwner _buildOwner = BuildOwner(focusManager: FocusManager());
  RenderObjectToWidgetElement<RenderBox>? _element;

  Size measure(Widget widget) {
    _attach(_wrap(KeyedSubtree(key: UniqueKey(), child: widget)));
    _pipelineOwner.flushLayout();
    return _root.size;
  }

  void _attach(Widget? child) {
    final adapter = RenderObjectToWidgetAdapter<RenderBox>(
      container: _root,
      child: child,
    );
    final element = _element;
    if (element == null) {
      _element = adapter.attachToRenderTree(_buildOwner);
      return;
    }
    adapter.attachToRenderTree(_buildOwner, element);
    _buildOwner.buildScope(element);
  }

  Widget _wrap(Widget child) {
    Widget subtree = Directionality(
      textDirection: Directionality.of(_context),
      child: MediaQuery(
        data: MediaQuery.of(_context),
        child: Overlay.wrap(alwaysSizeToContent: true, child: child),
      ),
    );
    if (Localizations.maybeLocaleOf(_context) != null) {
      subtree = Localizations.override(context: _context, child: subtree);
    }
    return InheritedTheme.captureAll(_context, subtree);
  }

  void dispose() {
    if (_element != null) {
      _attach(null);
      _buildOwner.finalizeTree();
      _element = null;
    }
    _pipelineOwner.rootNode = null;
    _pipelineOwner.dispose();
    _buildOwner.focusManager.dispose();
  }
}

Size getWidgetSizeOffScreen({
  required BuildContext context,
  required Widget widget,
  required Size viewSize,
}) {
  final measurer = OffscreenMeasurer(context, viewSize: viewSize);
  try {
    return measurer.measure(widget);
  } finally {
    measurer.dispose();
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
