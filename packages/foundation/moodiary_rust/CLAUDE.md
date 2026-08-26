### Rust Workspace

`packages/foundation/moodiary_rust/rust/` is both the cargo workspace root **and** the bridge package `moodiary_rust` — that shape is load-bearing: the Native Assets hook runs `cargo build --manifest-path rust/Cargo.toml --package moodiary_rust` and requires `Cargo.toml` + `rust-toolchain.toml` at `hook/build.dart`'s `cratePath`, so keeping `rust/` as the root means the hook and `flutter_rust_bridge.yaml` need no changes.

```
rust/
  src/api/            # bridge = app layer: the ONLY place that knows about FRB
  crates/
    foundation/       # http (reqwest 客户端 + hyper 服务端) / crypto / archive / image / text / font
                      #   js —— QuickJS 沙箱（rquickjs）。三道闸门在 JsSandbox::new 一次装齐；
                      #   **别开 rust-alloc**：那会让 set_memory_limit 静默变成 no-op
                      #   image 叫 image 不叫 media：本仓库的 media 指图/音/视三类，这里只做图片
    feature_base/     # doc (导出 IR，Dart export_doc.dart 的镜像)
    feature/          # sync (s3+webdav) / export (pdf+docx) / assistant (rig) / graph
```

Same direction rule as Dart, enforced by the same script: `foundation → feature_base → feature → bridge`, features never import each other, zero violations.

**层名与 Dart 侧同名同义**：`feature_base` 装跨 feature 共享的领域类型。刻意不叫 `core` ——
Dart 的 core 现在特指「一个领域词都不认识的基建」，而 `doc` 恰恰是全 workspace 唯一带领域
的 crate（导出 IR 带 weather / position / tags / category_name），两边同名不同义比不同名更
难查。内部依赖边只有三条，全部跨层：`assistant → http`、`sync → http`、`export → doc`；
foundation 七个 crate 之间零边。

### moodiary_rust —— 一个 .so，六扇门

**原生库只有一个，而且必须只有一个。** 2026-08-20 实测（Android arm64、仓库真实
profile 与 feature 集）：拆成两个 cdylib、共享 crate 走普通 cargo 依赖是 **+95.6%**
（rustls/reqwest/tokio 在两个库里各一份，`strings | grep rustls` 各 65 次）；给共享
crate 手写 `extern "C"` 再动态链接能收回 82%，但仍 **+17.1%**，而那点余量的 99% 是
**每库固定地板**——一个什么都不干的 Android cdylib 就要 294 KB（std + libunwind +
compiler-builtins 每库静态各带一份）。Rust ABI 的 `dylib` + `-C prefer-dynamic` 是死路：
rustc 在 `lto="thin"` 下直接拒绝，强行关掉 LTO 是 +170%。**拆库是投递策略，不是省体积
手段。** 而且真正的大头 typst 只有一个消费者，去重一个字节都省不到。

所以「业务 Rust 归对应的包」这件事**不能用包边界表达**，用门面表达：

| 门面 | 内容 | 谁能推 |
|---|---|---|
| `foundation.dart` | cancel / crypto / font / http / http_server / image / text / zip | 全仓 |
| `assistant.dart` | rig 对话流 + QuickJS 沙箱 | 只有 `moodiary_assistant` |
| `export.dart` | pdf(typst) / docx / 导出 IR | 只有 `moodiary_export` |
| `sync.dart` | s3 / webdav | 只有 `moodiary_sync` |
| `graph.dart` | 力导向布局 | 只有 `moodiary_diary` |
| `rust.dart` | `RustLib.init()` | 只有 app 组合根 |
| `testing.dart` | 分词替身 | 只有 `moodiary_data` 的测试 |

零基线闸门在 `tool/check_layers.dart` 的 `_rustFacadeOwners`，另带一条「不许绕过门面
深入 `package:moodiary_rust/src/`」。**没有 `moodiary_rust.dart` 这个总 barrel 了** ——
它以前让 `moodiary_storage` 够得着 `PdfBuilder` 和 `rigChatStream`。

> **content hash 只覆盖 api 函数名**（codegen 对排序后的函数名做 SHA1 取前四字节），
> 参数类型、返回类型、结构体定义都不在里面。所以「改了签名但没改名、且只提交了一半
> 生成物」不会被它抓到。`tool/check_generated.dart` 现在比对两侧 hash 相等来堵住
> 「只提交一半」；要堵死签名漂移得在 CI 装 codegen 重跑 + `git diff --exit-code`，
> 那要付一次没有缓存的 cargo install，暂时没做。

Two invariants worth keeping:
- **Sub-crates never mention `StreamSink` / `DartFnFuture`.** They take plain closures (`impl FnMut(T) -> bool`, `Arc<dyn Fn(..) -> BoxFuture<..>>`); `src/api/` adapts those to FRB.
- **FFI-visible types are declared in the sub-crate and re-exposed via `#[frb(mirror(T))]` in `src/api/`.** Mirror emits identical Dart to a local declaration, so no DTO is duplicated and no `From` conversion is needed. Opaque handles (`S3Client`, `Zip`, …) are thin newtypes in `src/api/` that delegate.

**依赖收窄的四条实测结论**（2026-08-20，别再重新推导）：

- **`zip` 不开 `zstd`**：值 396,784 字节，是这类收窄里唯一有分量的一条。代价是第三方
  工具重压成 Zstd 的备份导不进来（zip 8.6.0 的 `compression.rs:123` 会给出
  `Unsupported(93)`，报错不好懂）。我们自己写的档只有 Deflated / Stored。
- **`image` 的七个 feature 里只有 `ico` 是「只有我们开」的**，其余六个 docx-rs 与
  typst-library 已经各自开着，收窄零差异 —— 别浪费时间去收它们。
- **`ttf-parser` 收窄只值 16 字节**：fork 与 registry 版确实是两个独立编译单元、feature
  不并集（这部分推理是对的），但没被调用的那几张表本来就被 thin LTO + `--gc-sections`
  剥干净了。写在 Cargo.toml 里只为说清依赖面，别拿它当体积手段。
- **`syntect` 的四个 feature 全与 typst-library 重合**，收窄一个字节都省不到。

**两侧 formatter 现在都是干净的**（2026-08-20 统一跑过一次并单独提交）：
`cargo fmt --all -- --check` 与 `dart format --set-exit-if-changed` 都是零差异，
提交前保持这个状态。

**依赖树 2026-08-20 核过一遍，基本已是最新**，别再花时间找可升的：32 条精确钉版本里
升不动的四条各有硬理由 —— `two-face` 0.5 被 `typst-library 0.15.1` 的
`two-face = "0.4.3"` 挡住（升上去依赖图里会有两份，是体积倒退）；`generic-array`
0.14.9 要比钉的 Rust 1.95.0 更新的编译器；`zip` 9.0 与 `argon2` 0.6 都只有预发布版。

**`argon2` 的 `parallel` feature 对我们无效，别开。** 我们用 `Argon2::default()`，
参数是 `m=19456,t=2,p=1` —— 只有一条 lane，rayon 没有并行度可铺。实测两轮结果互相
矛盾（−12% / +4%）即噪声。网上/工具报的 3.2x 是在 `p>1` 下测的，不适用。
注：`argon2` 钉在预发布版 `=0.6.0-rc.8`，正式版尚未发布。

All third-party versions are exact-pinned (`=x.y.z`) in `[workspace.dependencies]`; sub-crates use `{ workspace = true }` and add only the features they need.

