# fast_image

图片管线：派生物（两档缩略图 + progressive JPEG 的 baseline 副本）、按需区域解码、分片看图页。
自带 FRB（`flutter_rust_bridge.yaml`，入口类 `FastImageLib`）与原生库 **libfastimage**
（`rust/`，单 crate：`api/` 是 FRB 门面，`codec/` 是 turbojpeg / restart / PNG / WebP 后端）。
设计稿与分期在 `docs/image-pipeline.md`。

- **foundation 叶子包，零 `moodiary_*` 依赖**：目录与日志由组合根注入（`FastImageRuntime.configure`），
  UI 只用 `flutter/widgets` 与 photo_view；看图页的壳（翻页 / hero / 保存 / 信息面板 / i18n）
  留在 `moodiary_components` 的 `MImageBrowser`，它消费这里的 `FastTileImageViewer` 与
  `FastTileSource.resolve`。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**（两个 FRB 包都会重生成）。
- **turbojpeg-sys**：只开 `cmake`，不开 `require-simd`（arm64 NEON 是 intrinsics 必然编进去，
  x86_64 CI 缺 NASM 只是没 SIMD）。构建机要有 cmake。`hook/build.dart` 多传三样：Android 从
  Flutter 给的 clang 路径推 NDK 根给 cmake-rs（`CMAKE_TOOLCHAIN_FILE_<triple>`、`ANDROID_NDK_ROOT`），
  iOS 模拟器传 `SDKROOT`。两条 API 坑：**缩放系数只认 N/8 十六档且要约分**（4/8 写 1/2，
  `turbo::set_scale` 统一处理）；`tj3SetCroppingRegion` 坐标是缩放后的，左边界须整除缩放后
  iMCU 宽。baseline 跳行仍要熵解码，随机访问靠 `restart.rs` 的 RST 索引；progressive 不能区域解，
  `tj3Transform` 无损转 baseline 副本再解。
- **libwebp-sys 0.14.4**：`cc` 编译，`default-features = false, features = ["std", "neon"]`；没有
  只编解码器的 feature，编码器靠链接期死代码剔除。裁剪不省熵解析；有损解码会把裁剪起点对齐到
  偶数。**png 0.18.1**：`next_row` 流式，Adam7 不接；16 位自己四舍五入（`STRIP_16` 是截断）。
- 交叉编译自检：`cargo check --target aarch64-linux-android|aarch64-apple-ios|aarch64-apple-ios-sim`
  加 hook 那套环境变量（Android 还要 `CC_aarch64_linux_android` / `AR_...` 给 libwebp 的 cc）。
