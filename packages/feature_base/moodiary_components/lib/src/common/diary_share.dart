import 'package:flutter/widgets.dart';

/// 日记页「分享」按钮的落点。
///
/// 分享的实现在 `moodiary_export`（分享 = scope 只有一篇的导出），而日记页在
/// `moodiary_diary` —— **两个都是 feature，禁止互相 import**。所以这里只留一个挂钩，
/// 由组合根（`mobile/lib/main.dart`）在启动时接上。
///
/// 不走 get_it：容器管的是生命周期内不变的绑定，而这是一次 UI 跳转的落点，
/// 进程内一个变量就够，不必为它生成一份 injectable。
typedef DiaryShareEntry = Future<void> Function(
  BuildContext context,
  String diaryId,
);

abstract final class DiaryShare {
  static DiaryShareEntry? _handler;

  /// 组合根在启动时调一次。
  static void register(DiaryShareEntry handler) => _handler = handler;

  static bool get isRegistered => _handler != null;

  /// 没挂上就什么都不做 —— 少一个入口好过启动即崩（组合根漏挂在 debug 下会断言）。
  static Future<void> open(BuildContext context, String diaryId) async {
    assert(_handler != null, 'DiaryShare.register() 没被调用：组合根漏挂了分享入口');
    await _handler?.call(context, diaryId);
  }
}
