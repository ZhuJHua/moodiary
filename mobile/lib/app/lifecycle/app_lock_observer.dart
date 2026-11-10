import 'dart:async';

import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
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

  static const Set<String> _skip = {
    LockRoute.path,
    ShareRoute.path,
    NewDiaryRoute.path,
    DiaryRoute.path,
  };

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
    if (state == .resumed) {
      _restoreMcp();
      return;
    }
    if (state != .paused && state != .hidden) {
      return;
    }
    if (_locking) return;
    if (!AppLockPin.enabled.value || MoodiaryKVs.lockNow.get() != true) {
      return;
    }
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (_skip.contains(location)) return;

    _locking = true;
    _stopMcp();
    router.pushRoute(const LockRoute(lockType: 'pause')).whenComplete(() {
      _locking = false;
      // Only after the lock screen is gone may the endpoint serve again.
      _restoreMcp();
    });
  }

  bool get _onLockScreen =>
      router.routerDelegate.currentConfiguration.uri.path == LockRoute.path;

  /// A locked app must not keep serving diaries to the network.
  void _stopMcp() {
    if (!getIt.isRegistered<McpService>()) return;
    unawaited(getIt<McpService>().stop());
  }

  /// [McpService.restore] is a no-op unless the user left the server enabled,
  /// and [McpService.start] returns early while it runs.
  ///
  /// Coming back to a still locked app keeps the endpoint down: `.resumed` also
  /// fires while the lock screen is up, and that screen is exactly what must not
  /// be served through.
  void _restoreMcp() {
    if (_onLockScreen) return;
    if (!getIt.isRegistered<McpService>()) return;
    unawaited(getIt<McpService>().restore());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
