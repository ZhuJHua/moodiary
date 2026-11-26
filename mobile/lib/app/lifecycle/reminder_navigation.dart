import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:mui/mui.dart';

class ReminderNavigation extends ConsumerStatefulWidget {
  const ReminderNavigation({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ReminderNavigation> createState() => _ReminderNavigationState();
}

class _ReminderNavigationState extends ConsumerState<ReminderNavigation> {
  late final _service = ref.read(reminderServiceProvider);
  late final _router = ref.read(appRouterProvider);
  StreamSubscription<void>? _subscription;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service.taps.listen((_) => _drain());
    _router.routerDelegate.addListener(_drain);
    _drain();
  }

  void _drain() {
    if (!_service.launchedFromNotification || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_service.launchedFromNotification) return;
      final newDiary = _service.tapAction == ReminderTapAction.newDiary;
      final routes = _router.routerDelegate.currentConfiguration;
      if (routes.isEmpty) return;
      final path = routes.lastOrNull?.matchedLocation ?? routes.uri.path;
      if (isGateRoute(path)) {
        return;
      }
      var openEditor = newDiary && !_hasNewDiary(routes.matches);
      while (_service.consumeTap()) {
        if (openEditor) {
          _router.pushRoute(const NewDiaryRoute());
          openEditor = false;
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _hasNewDiary(Iterable<RouteMatchBase> matches) => matches.any(
    (match) =>
        match.matchedLocation == NewDiaryRoute.path ||
        (match is ImperativeRouteMatch &&
            _hasNewDiary(match.matches.matches)) ||
        (match is ShellRouteMatch && _hasNewDiary(match.matches)),
  );

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_drain);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
