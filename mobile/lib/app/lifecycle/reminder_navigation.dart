import 'dart:async';

import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:mui/mui.dart';

class ReminderNavigation extends StatefulWidget {
  const ReminderNavigation({super.key, required this.child});
  final Widget child;

  @override
  State<ReminderNavigation> createState() => _ReminderNavigationState();
}

class _ReminderNavigationState extends State<ReminderNavigation> {
  late final _service = getIt<ReminderService>();
  StreamSubscription<void>? _subscription;
  bool _pending = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _pending = _service.launchedFromNotification;
    _subscription = _service.taps.listen((_) {
      _pending = true;
      _drain();
    });
    router.routerDelegate.addListener(_drain);
    _drain();
  }

  void _drain() {
    if (!_pending || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_pending) return;
      final newDiary = _service.tapAction == ReminderTapAction.newDiary;
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (newDiary && isGateRoute(path)) {
        return;
      }
      _pending = false;
      _service.launchedFromNotification = false;
      if (newDiary) router.pushRoute(const NewDiaryRoute());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_drain);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
