import 'dart:math' as math;

import 'package:mui/mui.dart';

class MSnackbarAction {
  const MSnackbarAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

abstract final class MSnackbar {
  static _Handle? _current;

  /// Shows [message] over the page, replacing any snackbar already up, and
  /// returns a callback that dismisses this one.
  ///
  /// A null [duration] keeps it until it is closed. [bottom] is the distance
  /// from the bottom of the screen and defaults to clearing the safe area and
  /// the keyboard.
  static VoidCallback show(
    BuildContext context, {
    required String message,
    MSnackbarAction? action,
    IconData? icon,
    Duration? duration = const Duration(seconds: 5),
    double? bottom,
  }) {
    _current?.remove();
    final handle = _Handle();
    handle.entry = OverlayEntry(
      builder: (_) => _Snackbar(
        key: handle.key,
        message: message,
        action: action,
        icon: icon,
        duration: duration,
        bottom: bottom,
        onClosed: handle.remove,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(handle.entry);
    _current = handle;
    return handle.call;
  }
}

class _Handle {
  final key = GlobalKey<_SnackbarState>();
  late final OverlayEntry entry;

  void call() => key.currentState?.close();

  void remove() {
    if (entry.mounted) entry.remove();
    if (identical(MSnackbar._current, this)) MSnackbar._current = null;
  }
}

class _Snackbar extends StatefulWidget {
  const _Snackbar({
    super.key,
    required this.message,
    required this.action,
    required this.icon,
    required this.duration,
    required this.bottom,
    required this.onClosed,
  });

  final String message;
  final MSnackbarAction? action;
  final IconData? icon;
  final Duration? duration;
  final double? bottom;
  final VoidCallback onClosed;

  @override
  State<_Snackbar> createState() => _SnackbarState();
}

class _SnackbarState extends State<_Snackbar> with TickerProviderStateMixin {
  late final _appearance = AnimationController(vsync: this);
  late final _countdown =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == .completed) close();
        });
  bool _closing = false, _started = false;
  int _holds = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    final motion = context.theme.motion;
    _appearance
      ..duration = still ? Duration.zero : motion.enter
      ..reverseDuration = still ? Duration.zero : motion.exit;
    if (_started) return;
    _started = true;
    _appearance.forward();
    _resume();
  }

  void _resume() {
    if (widget.duration != null && !_closing) _countdown.forward();
  }

  void _hold() {
    if (_holds++ > 0 || _closing) return;
    _countdown.stop();
    setState(() {});
  }

  void _release() {
    if (--_holds > 0 || _closing) return;
    _resume();
    setState(() {});
  }

  void close() {
    if (_closing || !mounted) return;
    _closing = true;
    _countdown.stop();
    _appearance.reverse().whenComplete(widget.onClosed);
  }

  void _act() {
    close();
    widget.action!.onPressed();
  }

  @override
  void dispose() {
    _appearance.dispose();
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final media = MediaQuery.of(context);
    final action = widget.action;
    final bottom =
        widget.bottom ??
        math.max(media.viewInsets.bottom, media.viewPadding.bottom) + 12;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, minHeight: 48),
          child: AnimatedBuilder(
            animation: _appearance,
            builder: (context, child) {
              final t = theme.motion.enterCurve.transform(_appearance.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 16),
                  child: child,
                ),
              );
            },
            child: ExcludeFocus(
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Listener(
                  onPointerDown: (_) => _hold(),
                  onPointerUp: (_) => _release(),
                  onPointerCancel: (_) => _release(),
                  child: MouseRegion(
                    onEnter: (_) => _hold(),
                    onExit: (_) => _release(),
                    child: Material(
                      type: .transparency,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: colors.surfaceBright,
                          shape: const RoundedRectangleBorder(
                            borderRadius: MuiRadius.lg,
                          ),
                          shadows: MGlassSurface.defaultShadows(colors),
                        ),
                        child: Padding(
                          padding: const .fromLTRB(16, 4, 4, 4),
                          child: Row(
                            spacing: 4,
                            children: [
                              if (widget.icon case final icon?)
                                Padding(
                                  padding: const .only(right: 8),
                                  child: Icon(
                                    icon,
                                    size: 20,
                                    color: colors.onSurface,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  maxLines: 2,
                                  overflow: .ellipsis,
                                  style: theme
                                      .typography
                                      .bodyMedium
                                      .onSurfaceVariant,
                                ),
                              ),
                              if (action != null)
                                MInkWell(
                                  onTap: _act,
                                  borderRadius: MuiRadius.inside(
                                    MuiRadius.lg,
                                    4,
                                  ),
                                  child: Container(
                                    height: 40,
                                    alignment: .center,
                                    padding: const .symmetric(horizontal: 12),
                                    child: Text(
                                      action.label,
                                      style: theme
                                          .typography
                                          .labelLarge
                                          .emphasized
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              _closeButton(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) {
    final colors = context.theme.colors;
    return Semantics(
      button: true,
      label: context.muiL10n.close,
      excludeSemantics: true,
      child: MInkWell(
        onTap: close,
        shape: const CircleBorder(),
        child: SizedBox.square(
          dimension: 40,
          child: Stack(
            alignment: .center,
            children: [
              // A running timer only matters while an action can still be used.
              if (widget.action != null && widget.duration != null)
                CustomPaint(
                  size: const Size.square(32),
                  painter: _CountdownRing(
                    progress: _countdown,
                    track: colors.outlineVariant,
                    color: _holds > 0 ? colors.outline : colors.primary,
                  ),
                ),
              Icon(LucideIcons.x, size: 16, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends CustomPainter {
  _CountdownRing({
    required this.progress,
    required this.track,
    required this.color,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = .stroke
      ..strokeWidth = stroke
      ..strokeCap = .round;
    canvas.drawOval(rect, paint..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (1 - progress.value),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_CountdownRing old) =>
      old.track != track || old.color != color;
}
