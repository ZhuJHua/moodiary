# moodiary_rust

Moodiary 的原生（Rust）FFI 包——**自包含单包**，对外暴露 `RustLib` + `api/*` 的 Dart 接口。
原生库经 **Native Assets 构建钩子**（`hook/build.dart`）编译打包，本包不是 Flutter plugin，
没有 `android/` `ios/` `macos/` `windows/` 平台脚手架，也没有 cargokit。

## 结构

- `rust/` — cargo crate（lib 名 `moodiary_rust`，与 pub 包名一致）。
- `rust/rust-toolchain.toml` — 钉住的工具链版本与目标三元组；构建只覆盖这里列出的 target。
- `hook/build.dart` — 构建钩子：Flutter 在 build/run 时调用它，用 cargo 编译 crate 并把产物登记为 code asset。
- `lib/src/rust/` — `flutter_rust_bridge_codegen generate` 生成的绑定。
- `lib/moodiary_rust.dart` — 统一导出 barrel（手写，对外入口）。
- `flutter_rust_bridge.yaml` — FRB 配置（`rust_input`/`rust_root: rust/`/`dart_output: lib/src/rust`）。

## 用法

```dart
import 'package:moodiary_rust/moodiary_rust.dart';          // 或 as rust
// 启动时一次：await RustLib.init();
```

## 改动 Rust 后

FRB 版本 `2.13.0-beta.5`，codegen CLI 必须同版本：

```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0-beta.5
dart tool/task.dart gen-rust
```

新增/删除 api 模块时，同步更新 `lib/moodiary_rust.dart` 的 export。

## 构建须知

- 本机需装 `rustup`：钩子通过 `rustup run <channel> cargo build` 调用，按 `rust-toolchain.toml` 自动装工具链与 target。
- 钩子始终以 release 编译 Rust（钩子拿不到 Flutter 的 debug/release 模式，而 debug 版 Rust 的图片编解码慢到不可用）。
- 新增目标平台前，先往 `rust/rust-toolchain.toml` 的 `targets` 补三元组。
