import 'dart:async';

import 'package:mui/mui.dart';

/// Delays loading presentation, restarting the grace period when loadKey changes.
class MDelayedLoading extends StatefulWidget {
  const MDelayedLoading({
    super.key,
    required this.loading,
    required this.builder,
    this.delay = const Duration(milliseconds: 300),
    this.loadKey,
  });

  final bool loading;
  final Duration delay;
  final Object? loadKey;
  final Widget Function(BuildContext context, bool showLoading) builder;

  @override
  State<MDelayedLoading> createState() => _MDelayedLoadingState();
}

class _MDelayedLoadingState extends State<MDelayedLoading> {
  Timer? _timer;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(MDelayedLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading != oldWidget.loading ||
        widget.loadKey != oldWidget.loadKey ||
        widget.delay != oldWidget.delay) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _showLoading = widget.loading && widget.delay <= Duration.zero;
    if (widget.loading && !_showLoading) {
      _timer = Timer(widget.delay, () => setState(() => _showLoading = true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _showLoading);
}
