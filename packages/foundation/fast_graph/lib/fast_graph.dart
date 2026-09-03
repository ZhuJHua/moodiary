/// 快速力导向布局：ForceAtlas2 + Barnes-Hut，逐帧流式回传，原生侧是自带的 `libfastgraph`，
/// 经裸 `dart:ffi`（native assets 的 `@Native` + `NativeCallable.listener`）调用——没有 init。
library;

export 'src/layout.dart';
