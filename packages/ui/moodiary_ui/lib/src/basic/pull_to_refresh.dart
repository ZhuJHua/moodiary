import 'package:expressive_refresh/expressive_refresh.dart';
import 'package:flutter/material.dart';

/// 下拉刷新（[ExpressiveRefreshIndicator]，M3 Expressive 动画）+ 预加载式上拉加载。
///
/// expressive_refresh 只提供下拉刷新，上拉加载由本组件自行实现：
/// - **预加载**：滚动时距底部剩余不足 [preloadFactor] 倍视口高度即提前触发
///   [onLoadMore]；同时监听内容尺寸变化，不足一屏 / 插入新页后自动补页。
///   按 (pixels, maxScrollExtent) 去重，同一位置只发一次。
/// - **兜底**：滚动停在最底部时再触发一次 [onLoadMore]（不受位置去重限制），
///   覆盖预加载漏触发 / 上一次加载失败未补上数据的情况。
///
/// [onLoadMore] 的返回值（是否还有更多）本组件不消费——是否到底由数据源自行短路。
class MoodiaryRefresh extends StatefulWidget {
  final Future<void> Function()? onRefresh;
  final Future<bool> Function()? onLoadMore;
  final double preloadFactor;
  final Widget child;

  const MoodiaryRefresh({
    super.key,
    this.onRefresh,
    this.onLoadMore,
    this.preloadFactor = 1.0,
    required this.child,
  });

  @override
  State<MoodiaryRefresh> createState() => _MoodiaryRefreshState();
}

class _MoodiaryRefreshState extends State<MoodiaryRefresh> {
  bool _loading = false;
  double? _firedPixels;
  double? _firedMax;

  bool _eligible(ScrollMetrics m) =>
      widget.onLoadMore != null &&
      !_loading &&
      m.hasContentDimensions &&
      m.hasViewportDimension &&
      m.axis == Axis.vertical;

  /// 预加载：进入底部一屏内即触发，按位置去重避免同点重复发。
  void _preload(ScrollMetrics m) {
    if (!_eligible(m)) return;
    if (m.extentAfter > m.viewportDimension * widget.preloadFactor) return;
    if (m.pixels == _firedPixels && m.maxScrollExtent == _firedMax) return;
    _firedPixels = m.pixels;
    _firedMax = m.maxScrollExtent;
    _fire();
  }

  /// 兜底：真正滚到底部时触发，绕过位置去重，重试漏触发 / 失败的预加载。
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
    // 内容尺寸变化（插入新页 / 首帧布局）时补页，覆盖不足一屏不触发滚动的情况。
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
      body = ExpressiveRefreshIndicator(onRefresh: onRefresh, child: body);
    }
    return body;
  }
}
