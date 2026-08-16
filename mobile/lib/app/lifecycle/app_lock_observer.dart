import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:mui/mui.dart';

/// 「立即锁定」生命周期观察器：lock + lockNow 均开启时，退后台即压锁屏页（lockType='pause'）。
///
/// 规避误锁：仅 paused/hidden 触发（inactive 不算）；编辑/分享页选图拍照会切后台故跳过；
/// 已在锁屏页时 [_locking] 为真不重复压栈。
///
/// 归属 app 生命周期层（非 feature）：直接读命令式的 `router` 全局。`moodiary_lock`
/// 已下沉为包，本观察器仍留 app 侧（策略属 app 组合面），跳过位置由路由契约构造。
class AppLockObserver extends StatefulWidget {
  final Widget child;

  const AppLockObserver({super.key, required this.child});

  @override
  State<AppLockObserver> createState() => _AppLockObserverState();
}

class _AppLockObserverState extends State<AppLockObserver>
    with WidgetsBindingObserver {
  bool _locking = false;

  /// 切后台不触发立即锁定的页面（选图 / 拍照 / 系统分享会引起切后台）。
  /// 从路由契约构造，避免与包内实际路径脱钩（旧的 '/edit' 字面量早已无对应路由）。
  static final Set<String> _skipExact = {
    LockRoute.path, // '/lock'
    ShareRoute.path, // '/share'
    NewDiaryRoute.path, // '/diary-new'（新建 = 编辑器，可选图/拍照）
  };

  /// DiaryRoute 是 '/diary/:diaryId' 模板；详情/编辑页内嵌编辑器可选图，按前缀匹配。
  static final String _diaryPrefix = DiaryRoute.path
      .split(':')
      .first; // '/diary/'

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
    // push 的 Future 在解锁后才完成，期间 _locking 为真，避免抖动重复压栈。
    router
        .push(const LockRoute(lockType: 'pause').location)
        .whenComplete(() => _locking = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
