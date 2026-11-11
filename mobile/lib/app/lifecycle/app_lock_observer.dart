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

  /// Whether the router is on the lock screen; `null` until it has resolved a
  /// location at all.
  ///
  /// The endpoint follows this instead of the lifecycle alone, so a cold start
  /// that stops on the lock screen never opens the port, and unlocking brings
  /// the server back without a lifecycle event.
  bool? _locked;

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
    // This widget wraps the router (it is mounted through `MaterialApp.builder`),
    // so the router resolves its initial location during this same frame, after
    // this method: the listener below is what sees it, the post frame callback is
    // the fallback.
    _locked = _routerResolved ? _onLockScreen : null;
    router.routerDelegate.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreMcp();
    });
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_onRouteChanged);
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

  /// `false` until the router has parsed a location; an empty configuration is
  /// the delegate's state before its first parse.
  bool get _routerResolved =>
      router.routerDelegate.currentConfiguration.isNotEmpty;

  /// Whether the lock screen is the page on top.
  ///
  /// The configuration's `uri` deliberately ignores imperatively pushed matches
  /// and the `pause` lock screen is pushed rather than gone to, so the leaf match
  /// is what names the page that is actually shown. Plain `go` transitions (the
  /// startup location, the unlock of that screen) work through either.
  bool get _onLockScreen {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return false;
    return configuration.last.matchedLocation == LockRoute.path;
  }

  /// Follows the page on top, so a lock screen appearing or going away stops or
  /// restores the endpoint, whichever code pushed or popped it: the lifecycle
  /// handler, the startup location or the unlock tap.
  void _onRouteChanged() {
    if (!_routerResolved) return;
    final locked = _onLockScreen;
    if (locked == _locked) return;
    _locked = locked;
    if (locked) {
      _stopMcp();
      return;
    }
    _restoreMcp();
  }

  /// A locked app must not keep serving diaries to the network.
  void _stopMcp() {
    if (!getIt.isRegistered<McpService>()) return;
    unawaited(getIt<McpService>().stop());
  }

  /// [McpService.restore] and [McpKeepAlive.restore] are no-ops unless the user
  /// left the matching switch on, and [McpService.start] returns early while it
  /// already runs.
  ///
  /// The keep-alive is resolved first on purpose: attaching its server state
  /// listener before the server starts is what re-applies the persisted switch.
  ///
  /// Coming back to a still locked app keeps the endpoint down: `.resumed` also
  /// fires while a lock screen is up, and that screen is exactly what must not
  /// be served through. [_locking] additionally covers the moment the `pause`
  /// screen is popped, when the location has already moved back but the unlock
  /// has not completed; and an unresolved router location is not a licence to
  /// start either, so the router listener restores as soon as it knows the page.
  void _restoreMcp() {
    if (_locking || !_routerResolved || _onLockScreen) return;
    if (!getIt.isRegistered<McpService>()) return;
    if (getIt.isRegistered<McpKeepAlive>()) {
      unawaited(getIt<McpKeepAlive>().restore());
    }
    unawaited(getIt<McpService>().restore());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
