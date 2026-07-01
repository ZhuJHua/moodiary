import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary/app/router/router.dart';

/// 「立即锁定」生命周期观察器：lock + lockNow 均开启时，退后台即压锁屏页（lockType='pause'）。
///
/// 规避误锁：仅 paused/hidden 触发（inactive 不算）；编辑/分享页选图拍照会切后台故跳过；
/// 已在锁屏页时 [_locking] 为真不重复压栈。
class AppLockObserver extends StatefulWidget {
  const AppLockObserver({super.key});

  @override
  State<AppLockObserver> createState() => _AppLockObserverState();
}

class _AppLockObserverState extends State<AppLockObserver>
    with WidgetsBindingObserver {
  bool _locking = false;

  /// 切后台不触发立即锁定的页面（选图 / 拍照 / 系统分享会引起切后台）。
  static const _skipLocations = {'/lock', '/edit', '/share'};

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
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }
    if (_locking) return;
    if (MoodiaryKVs.lock.get() != true || MoodiaryKVs.lockNow.get() != true) {
      return;
    }
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (_skipLocations.contains(location)) return;

    _locking = true;
    // push 的 Future 在解锁后才完成，期间 _locking 为真，避免抖动重复压栈。
    router
        .push(const LockRoute(lockType: 'pause').location)
        .whenComplete(() => _locking = false);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
