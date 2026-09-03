### Rust Workspace

`packages/foundation/moodiary_rust/rust/` is both the cargo workspace root **and** the bridge package `moodiary_rust` — that shape is load-bearing: the Native Assets hook runs `cargo build --manifest-path rust/Cargo.toml --package moodiary_rust` and requires `Cargo.toml` + `rust-toolchain.toml` at `hook/build.dart`'s `cratePath`, so keeping `rust/` as the root means the hook and `flutter_rust_bridge.yaml` need no changes.

```
rust/
  src/api/            # bridge = app layer: the ONLY place that knows about FRB
  crates/
    foundation/       # crypto / archive / font
    feature_base/     # （空）——唯一的住户 doc 随导出 2026-09-03 搬去了 fast_press
    feature/          # graph
```

Same direction rule as Dart, enforced by the same script: `foundation → feature_base → feature → bridge`, features never import each other, zero violations.

**层名与 Dart 侧同名同义**：`feature_base` 装跨 feature 共享的领域类型。刻意不叫 `core` ——
Dart 的 core 现在特指「一个领域词都不认识的基建」，而这一层的住户（曾经的 `doc`：导出 IR 带
weather / position / tags / category_name）恰恰带领域，两边同名不同义比不同名更难查。它现在
是空的（`doc` 与 `export` 一起去了 fast_press），层位与闸门保留。内部依赖边已经归零。

### moodiary_rust —— 一个 .so，两扇门

**原生库只有一个，而且必须只有一个。** 2026-08-20 实测（Android arm64、仓库真实
profile 与 feature 集）：拆成两个 cdylib、共享 crate 走普通 cargo 依赖是 **+95.6%**
（rustls/reqwest/tokio 在两个库里各一份，`strings | grep rustls` 各 65 次）；给共享
crate 手写 `extern "C"` 再动态链接能收回 82%，但仍 **+17.1%**，而那点余量的 99% 是
**每库固定地板**——一个什么都不干的 Android cdylib 就要 294 KB（std + libunwind +
compiler-builtins 每库静态各带一份）。Rust ABI 的 `dylib` + `-C prefer-dynamic` 是死路：
rustc 在 `lto="thin"` 下直接拒绝，强行关掉 LTO 是 +170%。**拆库是投递策略，不是省体积
手段。** 已经拆出去的两个库（fast_image / fast_press）都是按这个口径拆的：各自的大头
（turbojpeg / typst）只有一个消费者，去重一个字节都省不到，付的是每库固定地板。

所以「业务 Rust 归对应的包」这件事**不能用包边界表达**，用门面表达：

| 门面 | 内容 | 谁能推 |
|---|---|---|
| `foundation.dart` | cancel / crypto / font / zip | 全仓 |
| `graph.dart` | 力导向布局 | 只有 `moodiary_diary` |
| `rust.dart` | `RustLib.init()` | 只有 app 组合根 |

零基线闸门在 `tool/check_layers.dart` 的 `_rustFacadeOwners`，另带一条「不许绕过门面
深入 `package:moodiary_rust/src/`」。曾经的 `export.dart` 门面整个成了 fast_press 包，
归属改由同脚本的 `_nativePkgOwners` 按 pubspec 依赖守。**没有 `moodiary_rust.dart` 这个总 barrel 了** ——
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
- **`ttf-parser` 收窄只值 16 字节**：fork 与 registry 版确实是两个独立编译单元、feature
  不并集（这部分推理是对的），但没被调用的那几张表本来就被 thin LTO + `--gc-sections`
  剥干净了。写在 Cargo.toml 里只为说清依赖面，别拿它当体积手段。

**分词也不在这里**：jieba 与 HF tokenizer 拆去了 `fast_text`（`libfasttext`，含测试替身）。**网络与助手都不在这里**：reqwest 客户端 / hyper 服务端 / WebDAV / S3 2026-09-03 拆去了
`packages/foundation/fast_http`（原生库 `libfasthttp`），rig 对话流拆去了 `fast_llm`（`libfastllm`）。**图片编解码与导出都不在这里**：turbojpeg / libwebp / png 与整条图片管线 2026-09-03 拆去了
`packages/foundation/fast_image`（原生库 `libfastimage`）；typst / docx-rs / syntect 与导出 IR
同日拆去了 `packages/foundation/fast_press`（原生库 `libfastpress`）。`image` / `syntect` /
`two-face` 的收窄结论随它们走了，坑见各自的 CLAUDE.md。

**两侧 formatter 现在都是干净的**（2026-08-20 统一跑过一次并单独提交）：
`cargo fmt --all -- --check` 与 `dart format --set-exit-if-changed` 都是零差异，
提交前保持这个状态。

**依赖树 2026-08-20 核过一遍，基本已是最新**，别再花时间找可升的：精确钉版本里
升不动的几条各有硬理由 —— `generic-array` 0.14.9 要比钉的 Rust 1.95.0 更新的编译器；
`zip` 9.0 与 `argon2` 0.6 都只有预发布版（typst 那侧的 `two-face` 见 fast_press）。

**`argon2` 的 `parallel` feature 对我们无效，别开。** 我们用 `Argon2::default()`，
参数是 `m=19456,t=2,p=1` —— 只有一条 lane，rayon 没有并行度可铺。实测两轮结果互相
矛盾（−12% / +4%）即噪声。网上/工具报的 3.2x 是在 `p>1` 下测的，不适用。
注：`argon2` 钉在预发布版 `=0.6.0-rc.8`，正式版尚未发布。

All third-party versions are exact-pinned (`=x.y.z`) in `[workspace.dependencies]`; sub-crates use `{ workspace = true }` and add only the features they need.

