import 'package:moodiary_mobile/app/router/router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class AppLockObserver extends StatefulWidget {
  final Widget child;

  const AppLockObserver({super.key, required this.child});

  @override
  State<AppLockObserver> createState() => _AppLockObserverState();
}

class _AppLockObserverState extends State<AppLockObserver>
    with WidgetsBindingObserver {
  bool _locking = false;

  static final Set<String> _skipExact = {
    LockRoute.path,
    ShareRoute.path,
    NewDiaryRoute.path,
  };

  static final String _diaryPrefix = DiaryRoute.path
      .split(':')
      .first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != .paused && state != .hidden) {
      return;
    }
    if (_locking) return;
    if (!AppLockPin.enabled.value || MoodiaryKVs.lockNow.get() != true) {
      return;
    }
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (_skipExact.contains(location) || location.startsWith(_diaryPrefix)) {
      return;
    }

    _locking = true;
    router
        .push(const LockRoute(lockType: 'pause').location)
        .whenComplete(() => _locking = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
