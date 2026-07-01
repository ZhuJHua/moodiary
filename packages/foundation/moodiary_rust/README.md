# moodiary_rust

Moodiary 的原生（Rust）FFI 插件包——**自包含单包**（用 `flutter_rust_bridge_codegen create --template plugin` 官方脚手架生成），对外暴露 `RustLib` + `api/*` 的 Dart 接口。

## 结构

- `rust/` — cargo crate（lib 名 `moodiary_rust`，与 pub 包名一致）。
- `cargokit/` — 原生构建胶水（gradle/podspec/cmake 经 `../rust` 找到 crate）。
- `lib/src/rust/` — `flutter_rust_bridge_codegen generate` 生成的绑定。
- `lib/moodiary_rust.dart` — 统一导出 barrel（手写，对外入口）。
- `flutter_rust_bridge.yaml` — 本包自带 FRB 配置（`rust_input`/`rust_root: rust/`/`dart_output: lib/src/rust`）。

## 用法

```dart
import 'package:moodiary_rust/moodiary_rust.dart';          // 或 as rust
// 启动时一次：await RustLib.init();
```

## 改动 Rust 后

FRB 版本 `2.13.0-beta.2`，codegen CLI 必须同版本：
```bash
cargo install flutter_rust_bridge_codegen --version 2.13.0-beta.2
cd packages/moodiary_rust && flutter_rust_bridge_codegen generate
```
新增/删除 api 模块时，同步更新 `lib/moodiary_rust.dart` 的 export。
