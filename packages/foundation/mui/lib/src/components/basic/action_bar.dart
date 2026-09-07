import 'package:mui/mui.dart';

class MAction<T> {
  final T? value;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final bool enabled;

  final bool busy;

  final VoidCallback? onPressed;

  final bool Function()? onIntercept;

  final Future<bool> Function()? onSubmit;

  const MAction({
    required this.label,
    this.value,
    this.isPrimary = false,
    this.isDestructive = false,
    this.enabled = true,
    this.busy = false,
    this.onPressed,
    this.onIntercept,
    this.onSubmit,
  });
}

enum MActionsLayout {
  auto,
  horizontal,
  vertical,
}

class MActionBar<T> extends StatefulWidget {
  final List<MAction<T>> actions;
  final MActionsLayout layout;
  final double height;
  final double gap;

  const MActionBar({
    super.key,
    required this.actions,
    required this.layout,
    required this.height,
    required this.gap,
  });

  @override
  State<MActionBar<T>> createState() => _MActionBarState<T>();
}

class _MActionBarState<T> extends State<MActionBar<T>> {
  int? _busyIndex;

  bool _fitsInRow(BuildContext context, double maxWidth, TextStyle? style) {
    final actions = widget.actions;
    final gap = widget.gap;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var total = gap * (actions.length - 1);
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      total += painter.width + 32;
    }
    return total <= maxWidth;
  }

  Future<void> _tap(int index) async {
    final action = widget.actions[index];
    final onPressed = action.onPressed;
    if (onPressed != null) {
      onPressed();
      return;
    }
    if (action.onIntercept?.call() == false) return;
    final submit = action.onSubmit;
    if (submit != null) {
      setState(() => _busyIndex = index);
      var ok = false;
      try {
        ok = await submit();
      } finally {
        if (mounted) setState(() => _busyIndex = null);
      }
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(action.value);
  }

  Widget _button(int index, TextStyle style) {
    final action = widget.actions[index];
    final busyIndex = _busyIndex;
    return MActionButton<T>(
      action: action,
      textStyle: style,
      height: widget.height,
      busy: action.busy || busyIndex == index,
      enabled: action.enabled && busyIndex == null,
      onTap: () => _tap(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelLarge.emphasized.onSurface;
    final actions = widget.actions;
    final gap = widget.gap;

    return PopScope(
      canPop: _busyIndex == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = switch (widget.layout) {
            .horizontal => true,
            .vertical => false,
            .auto =>
              actions.length == 1 ||
                  (actions.length == 2 &&
                      _fitsInRow(context, constraints.maxWidth, style)),
          };

          if (horizontal) {
            return Row(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(child: _button(index, style)),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              for (var index = actions.length - 1; index >= 0; index--) ...[
                if (index < actions.length - 1) SizedBox(height: gap),
                _button(index, style),
              ],
            ],
          );
        },
      ),
    );
  }
}

class MActionButton<T> extends StatelessWidget {
  final MAction<T> action;
  final TextStyle? textStyle;
  final double height;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const MActionButton({
    super.key,
    required this.action,
    required this.textStyle,
    required this.height,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final Color background;
    final Color foreground;
    if (action.isDestructive) {
      background = scheme.error;
      foreground = scheme.onError;
    } else if (action.isPrimary) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    return FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: scheme.onSurface.withValues(
          alpha: context.theme.states.disabledContainerOpacity,
        ),
        disabledForegroundColor: scheme.onSurface.withValues(
          alpha: context.theme.states.disabledOpacity,
        ),
        minimumSize: .fromHeight(height),
        padding: const .symmetric(horizontal: 12),
        textStyle: textStyle,
        shape: const RoundedRectangleBorder(borderRadius: MuiRadius.md),
      ),
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Text(action.label, maxLines: 1, overflow: .ellipsis),
    );
  }
}
