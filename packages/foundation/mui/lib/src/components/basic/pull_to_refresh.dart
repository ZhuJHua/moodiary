import 'package:material_ui/material_ui.dart';

class MRefresh extends StatefulWidget {
  final Future<void> Function()? onRefresh;
  final Future<bool> Function()? onLoadMore;
  final double preloadFactor;
  final Widget child;

  const MRefresh({
    super.key,
    this.onRefresh,
    this.onLoadMore,
    this.preloadFactor = 1.0,
    required this.child,
  });

  @override
  State<MRefresh> createState() => _MRefreshState();
}

class _MRefreshState extends State<MRefresh> {
  bool _loading = false;
  double? _firedPixels;
  double? _firedMax;

  bool _eligible(ScrollMetrics m) =>
      widget.onLoadMore != null &&
      !_loading &&
      m.hasContentDimensions &&
      m.hasViewportDimension &&
      m.axis == .vertical;

  void _preload(ScrollMetrics m) {
    if (!_eligible(m)) return;
    if (m.extentAfter > m.viewportDimension * widget.preloadFactor) return;
    if (m.pixels == _firedPixels && m.maxScrollExtent == _firedMax) return;
    _firedPixels = m.pixels;
    _firedMax = m.maxScrollExtent;
    _fire();
  }

  void _fallback(ScrollMetrics m) {
    if (!_eligible(m) || m.extentAfter > 0) return;
    _fire();
  }

  void _fire() {
    final onLoadMore = widget.onLoadMore;
    if (onLoadMore == null) return;
    _loading = true;
    Future<void>(onLoadMore).whenComplete(() => _loading = false);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      _preload(n.metrics);
    } else if (n is ScrollEndNotification) {
      _fallback(n.metrics);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget body = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        if (n.depth == 0) _preload(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    final onRefresh = widget.onRefresh;
    if (onRefresh != null) {
      body = RefreshIndicator(onRefresh: onRefresh, child: body);
    }
    return body;
  }
}
