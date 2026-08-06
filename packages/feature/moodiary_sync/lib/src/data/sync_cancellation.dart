import 'package:flutter/foundation.dart';

/// 同步的**协作式**停止标志（进程级单例）。单 isolate 无可抢占线程，停止语义 =
/// **不再发起新条目**（条目级循环每条开始前检查本标志），在飞的跑完后照常收尾
/// （push 把已完成条目写回 manifest，进度不丢）。故点停止后有短暂「正在停止」期。
/// 全局同时只有一个同步在跑，单标志即可，操作结束由引擎复位。
class SyncCancellation {
  SyncCancellation._();

  static final SyncCancellation instance = ._();

  final ValueNotifier<bool> _requested = ValueNotifier(false);

  /// UI 监听用（如「停止同步」按钮变为「正在停止…」）。
  ValueListenable<bool> get listenable => _requested;

  bool get isRequested => _requested.value;

  void requestStop() => _requested.value = true;

  /// 引擎在一次操作结束（含异常）时复位。
  void reset() => _requested.value = false;
}
