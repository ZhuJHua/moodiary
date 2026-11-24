import 'package:mui/mui.dart';

class MTimeWheel extends StatefulWidget {
  const MTimeWheel({
    super.key,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  State<MTimeWheel> createState() => _MTimeWheelState();
}

class _MTimeWheelState extends State<MTimeWheel> {
  late final _hours = FixedExtentScrollController(
    initialItem: 2400 + widget.hour,
  );
  late final _minutes = FixedExtentScrollController(
    initialItem: 6000 + widget.minute,
  );
  int? _pendingHour;
  int? _pendingMinute;
  bool _syncScheduled = false;

  @override
  void didUpdateWidget(covariant MTimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pendingHour = _hours.hasClients && _hours.selectedItem % 24 == widget.hour
        ? null
        : widget.hour;
    _pendingMinute =
        _minutes.hasClients && _minutes.selectedItem % 60 == widget.minute
        ? null
        : widget.minute;
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled || (_pendingHour == null && _pendingMinute == null)) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      _pendingHour = _sync(_hours, 24, _pendingHour);
      _pendingMinute = _sync(_minutes, 60, _pendingMinute);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  int? _sync(FixedExtentScrollController controller, int count, int? value) {
    if (value == null) return null;
    if (!controller.hasClients ||
        controller.position.isScrollingNotifier.value) {
      return value;
    }
    final current = controller.selectedItem;
    controller.jumpToItem(current - current % count + value);
    return null;
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    Widget column(
      int count,
      FixedExtentScrollController controller,
      ValueChanged<int> onChanged, {
      required Alignment alignment,
    }) => Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.6,
        overAndUnderCenterOpacity: 0.28,
        onSelectedItemChanged: (index) => onChanged(index % count),
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var value = 0; value < count; value++)
              Padding(
                padding: const .symmetric(horizontal: 22),
                child: Align(
                  alignment: alignment,
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: theme.typography.headlineMedium.onSurface.tabular,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _scheduleSync();
        return false;
      },
      child: SizedBox(
        height: 176,
        child: Stack(
          alignment: .center,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: theme.colors.surfaceContainerHighest,
                borderRadius: .circular(theme.radii.md),
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                stops: const [0, 0.25, 0.75, 1],
                colors: [
                  theme.colors.onSurface.withValues(alpha: 0),
                  theme.colors.onSurface,
                  theme.colors.onSurface,
                  theme.colors.onSurface.withValues(alpha: 0),
                ],
              ).createShader(bounds),
              child: Row(
                children: [
                  column(24, _hours, (hour) {
                    if (_pendingHour == null && hour != widget.hour) {
                      widget.onChanged(hour, widget.minute);
                    }
                  }, alignment: .centerRight),
                  column(60, _minutes, (minute) {
                    if (_pendingMinute == null && minute != widget.minute) {
                      widget.onChanged(widget.hour, minute);
                    }
                  }, alignment: .centerLeft),
                ],
              ),
            ),
            IgnorePointer(
              child: Text(
                ':',
                style: theme.typography.headlineMedium.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
