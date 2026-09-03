# fast_graph

力导向图布局：ForceAtlas2（Jacomy 2014）+ Barnes-Hut（`layout.rs`），逐帧流式吐坐标。两处刻意
偏离原版：保留线性向心力（把不连通分量收进视野）与 forceCollide 碰撞（硬保不重叠）。
**裸 FFI，不走 FRB**（形状同 fast_crypto）：原生库 **libfastgraph** 由 `native_toolchain_rust` 在
`hook/build.dart` 构建并登记为 code asset，Dart 侧 `@Native` 直接解析符号，没有 init。
2026-09-03 从 moodiary_rust 的 `graph` crate 拆出来。

- **只有 `moodiary_diary` 能依赖它**（`_nativePkgOwners`）。
- **流的形状**（`rust/src/ffi.rs` 文件头）：`fastgraph_layout_start` 起一条原生线程跑布局，每帧经
  `cb(kind, ptr, len)` 回到 Dart（`NativeCallable.listener`，走本 isolate 的事件循环）；
  **终态事件（done / error）恰好来一次，取消也不例外**，Dart 侧等到它才 `close()` 回调与 free
  句柄——回调关早了、原生线程再调它就是 UB。`frame_delay_ms` 的节流仍在原生线程里 sleep。
- 载荷是 boxed slice（`f32` 原生字节序 / UTF-8 错误文本），Dart 拷成自己的内存后立刻
  `fastgraph_buf_free`。布局线程整体 `catch_unwind`，panic 变成 error 事件。
- Dart API 与原来的 FRB 生成物同形（`layoutGraphStream(...)` 返回 `Stream<Float32List>`、
  `GraphLayoutParams` 同名字段），消费方只换 import。
- 单测（`test/layout_test.dart`）真跑原生库，含取消后不再推帧的用例。
