import 'dart:async';
import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/services.dart';
import 'package:mui/mui.dart';

const _kHeaderHeight = 52.0;

enum MRefreshStatus { neutral, success, warning, error }

@immutable
class MRefreshOutcome {
  final MRefreshStatus status;
  final String? message;

  const MRefreshOutcome({this.status = .neutral, this.message});
}

@immutable
class MRefreshLabels {
  final String pull;
  final String armed;
  final String loading;
  final String complete;

  const MRefreshLabels({
    required this.pull,
    required this.armed,
    required this.loading,
    required this.complete,
  });
}

typedef MRefreshCallback = Future<MRefreshOutcome?> Function();

class MRefresh extends StatefulWidget {
  final MRefreshCallback? onRefresh;
  final bool refreshEnabled;
  final MRefreshLabels? refreshLabels;
  final Future<bool> Function()? onLoadMore;
  final Object? paginationKey;
  final double preloadFactor;
  final Widget child;

  const MRefresh({
    super.key,
    this.onRefresh,
    this.refreshEnabled = true,
    this.refreshLabels,
    this.onLoadMore,
    this.paginationKey,
    this.preloadFactor = 1.0,
    required this.child,
  });

  @override
  State<MRefresh> createState() => _MRefreshState();
}

class _MRefreshState extends State<MRefresh> {
  final _controller = IndicatorController();
  final _overscroll = _LeadingOverscroll();
  late final _physics = AlwaysScrollableScrollPhysics(
    parent: _LeadingClampingPhysics(_controller, _overscroll),
  );
  MRefreshOutcome? _completeOutcome;
  bool _loading = false;
  int _loadEpoch = 0;
  bool _topOverscroll = false;
  (double, double)? _lastPreload;
  (double, double)? _rejectedLoad;

  @override
  void initState() {
    super.initState();
    _syncEnabled();
  }

  @override
  void didUpdateWidget(MRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEnabled();
    if (oldWidget.paginationKey != widget.paginationKey ||
        (oldWidget.onLoadMore == null && widget.onLoadMore != null)) {
      _loadEpoch++;
      _loading = false;
      _lastPreload = _rejectedLoad = null;
    }
  }

  void _syncEnabled() {
    final enabled = widget.onRefresh != null && widget.refreshEnabled;
    if (enabled == _controller.isRefreshEnabled) return;
    if (enabled) {
      _controller.enableRefresh();
    } else {
      _controller.disableRefresh();
      _overscroll.debt = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _completeOutcome = null;
    MRefreshOutcome? outcome;
    try {
      outcome = await widget.onRefresh?.call();
    } catch (_) {
      outcome = const MRefreshOutcome(status: .error);
    }
    if (!mounted || outcome == null) return;
    setState(() => _completeOutcome = outcome);
    if (outcome.status == .error) unawaited(HapticFeedback.mediumImpact());
    if (outcome.status == .success) unawaited(HapticFeedback.selectionClick());
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 850),
    );
  }

  bool _eligible(ScrollMetrics metrics) =>
      widget.onLoadMore != null &&
      !_loading &&
      _controller.isIdle &&
      !_topOverscroll &&
      metrics.hasContentDimensions &&
      metrics.hasViewportDimension &&
      metrics.axis == .vertical &&
      metrics.pixels >= metrics.minScrollExtent;

  void _preload(ScrollMetrics metrics, {bool fallback = false}) {
    if (!_eligible(metrics)) return;
    final threshold = fallback
        ? 0
        : metrics.viewportDimension * widget.preloadFactor;
    if (metrics.extentAfter > threshold) return;
    final position = (metrics.pixels, metrics.maxScrollExtent);
    if (position == _rejectedLoad || (!fallback && position == _lastPreload)) {
      return;
    }
    _lastPreload = position;
    unawaited(_loadMore(position, _loadEpoch));
  }

  Future<void> _loadMore((double, double) position, int epoch) async {
    _loading = true;
    try {
      final hasMore = await widget.onLoadMore!();
      if (epoch == _loadEpoch && !hasMore) _rejectedLoad = position;
    } finally {
      if (epoch == _loadEpoch) _loading = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (notification is OverscrollNotification) {
      _topOverscroll = notification.overscroll < 0 && metrics.extentBefore == 0;
      _preload(metrics);
    } else if (notification is ScrollUpdateNotification) {
      if (metrics.extentBefore > 0) _topOverscroll = false;
      _preload(metrics);
    } else if (notification is ScrollEndNotification) {
      _overscroll.debt = 0;
      _preload(metrics, fallback: true);
      _topOverscroll = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final still = MediaQuery.disableAnimationsOf(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _preload(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(physics: _physics),
          child: CustomRefreshIndicator(
            controller: _controller,
            offsetToArmed: 72,
            leadingScrollIndicatorVisible: false,
            trailingScrollIndicatorVisible: false,
            durations: RefreshIndicatorDurations(
              cancelDuration: still ? Duration.zero : motion.normal,
              settleDuration: still ? Duration.zero : motion.enter,
              finalizeDuration: still ? Duration.zero : motion.normal,
              completeDuration: null,
            ),
            onRefresh: _handleRefresh,
            onStateChanged: (change) {
              if (change.didChange(to: .armed)) {
                unawaited(HapticFeedback.lightImpact());
              }
              if (change.didChange(to: .idle)) {
                _completeOutcome = null;
                _overscroll.debt = 0;
              }
            },
            builder: (context, child, controller) {
              final value = controller.value;
              final shift = value <= 1
                  ? _kHeaderHeight * value
                  : _kHeaderHeight + (value - 1) * 28;
              return ClipRect(
                child: Stack(
                  children: [
                    Transform.translate(offset: Offset(0, shift), child: child),
                    if (shift > 0)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: shift,
                        child: _Header(
                          controller: controller,
                          outcome: _completeOutcome,
                          labels: widget.refreshLabels,
                          shift: shift,
                          still: still,
                        ),
                      ),
                  ],
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _LeadingOverscroll {
  double debt = 0;
}

class _LeadingClampingPhysics extends ClampingScrollPhysics {
  final IndicatorController _controller;
  final _LeadingOverscroll _overscroll;

  const _LeadingClampingPhysics(
    this._controller,
    this._overscroll, {
    super.parent,
  });

  @override
  _LeadingClampingPhysics applyTo(ScrollPhysics? ancestor) =>
      _LeadingClampingPhysics(
        _controller,
        _overscroll,
        parent: buildParent(ancestor),
      );

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final boundary = super.applyBoundaryConditions(position, value);
    if (!_controller.isRefreshEnabled) return boundary;
    if (boundary < 0 && value < position.minScrollExtent) {
      _overscroll.debt -= boundary;
    } else if (value > position.pixels &&
        (_controller.isDragging || _controller.isArmed)) {
      final payment = math.min(value - position.pixels, _overscroll.debt);
      _overscroll.debt -= payment;
      return math.max(payment, boundary);
    }
    return boundary;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.outcome,
    required this.labels,
    required this.shift,
    required this.still,
  });

  final IndicatorController controller;
  final MRefreshOutcome? outcome;
  final MRefreshLabels? labels;
  final double shift;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final status = outcome?.status;
    final loading =
        controller.isSettling ||
        controller.isLoading ||
        controller.isFinalizing;
    final accent = switch (status) {
      .success => theme.success,
      .warning => theme.warning,
      .error => colors.error,
      .neutral => colors.onSurfaceVariant,
      null =>
        controller.isArmed || loading
            ? colors.primary
            : colors.onSurfaceVariant,
    };
    final role = theme.typography.labelMedium;
    final (text, style) = switch (status) {
      .error => (
        outcome!.message ?? context.muiL10n.toastError,
        role.withColor(accent),
      ),
      _? => (
        outcome!.message ?? labels?.complete ?? context.muiL10n.refreshComplete,
        role.withColor(accent),
      ),
      null when loading => (
        labels?.loading ?? context.muiL10n.refreshLoading,
        role.onSurfaceVariant,
      ),
      null when controller.isArmed => (
        labels?.armed ?? context.muiL10n.refreshArmed,
        role.onSurface,
      ),
      _ => (labels?.pull ?? context.muiL10n.refreshPull, role.onSurfaceVariant),
    };
    final duration = still ? Duration.zero : theme.motion.fast;
    final Widget mark = switch (status) {
      .success => Icon(
        LucideIcons.circleCheck,
        key: const ValueKey('success'),
        size: 16,
        color: accent,
      ),
      .neutral => Icon(
        LucideIcons.check,
        key: const ValueKey('neutral'),
        size: 16,
        color: accent,
      ),
      .warning => Icon(
        LucideIcons.triangleAlert,
        key: const ValueKey('warning'),
        size: 16,
        color: accent,
      ),
      .error => Icon(
        LucideIcons.circleAlert,
        key: const ValueKey('error'),
        size: 16,
        color: accent,
      ),
      null when loading => SizedBox.square(
        key: const ValueKey('loading'),
        dimension: 15,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.primary,
          value: still ? 0.7 : null,
        ),
      ),
      null => AnimatedRotation(
        key: const ValueKey('pull'),
        turns: controller.isArmed ? 0.5 : 0,
        duration: duration,
        curve: theme.motion.standard,
        child: Icon(LucideIcons.arrowDown, size: 16, color: accent),
      ),
    };
    final reveal = ((shift - 12) / (_kHeaderHeight - 16)).clamp(0.0, 1.0);
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Opacity(
          opacity: reveal,
          child: ClipRect(
            child: OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 8,
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: duration,
                          switchInCurve: theme.motion.standard,
                          switchOutCurve: theme.motion.standard,
                          transitionBuilder: _iconTransition,
                          child: mark,
                        ),
                      ),
                    ),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: duration,
                        switchInCurve: theme.motion.standard,
                        switchOutCurve: theme.motion.standard,
                        child: Text(
                          text,
                          key: ValueKey(text),
                          style: style,
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _iconTransition(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
          child: child,
        ),
      );
}
