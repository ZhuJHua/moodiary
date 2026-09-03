# fast_crypto

AES-256-GCM 对称加密（`aes.rs`，含整文件加解密与 Argon2id 密钥派生）与 Argon2id 密码哈希
（`password.rs`）。**裸 FFI，不走 FRB**：原生库 **libfastcrypto** 由 `native_toolchain_rust` 的
`RustBuilder` 在 `hook/build.dart` 里构建并登记为 code asset，Dart 侧 `lib/src/ffi.dart` 用
`@Native` 直接解析符号——没有 init、没有 dlopen、没有 codegen，首次调用自动装载。
2026-09-03 从 moodiary_rust 的 `crypto` crate 拆出来，是后续裸 FFI 包（fast_graph）的模板。

- 多个消费方（moodiary_storage 的应用锁 PIN、moodiary_sync 的信封加密 / LAN 协议），不进
  `_nativePkgOwners`。
- **C ABI 约定**（`rust/src/ffi.rs` 文件头）：入参「指针 + 长度」、出参 `FfiBuf`（0 = 载荷 /
  1 = 业务错误 / 2 = panic，都是 Rust 堆、都由 `fastcrypto_buf_free` 归还）、**每个入口
  `catch_unwind`**——panic 越过 FFI 边界是 UB，FRB 那套兜底在这里不存在。Dart 侧 `_call` 把
  出参拷成 Dart 内存再归还，非 0 码抛 `FastCryptoException`。
- 全部跑在 `Isolate.run`：Argon2 派生（默认 64 MiB / 3 轮）与整文件加解密都是几十毫秒起的活，
  `@Native` 在任何 isolate 都能直接调。
- `hook/build.dart` 的 `assetName: 'src/ffi.dart'` 必须与 `@Native` 声明所在文件一致（asset id
  就是那个 `package:` URI）。Apple 部署目标映射与 FRB 包同一段。
- 单测（`test/crypto_test.dart`）真跑原生库：`flutter test` 会为宿主构建 hook。
- `argon2` 钉预发布版 `=0.6.0-rc.8`，`parallel` feature 对 p=1 无效别开；改了 `rust/Cargo.toml`
  依赖必跑 `dart tool/task.dart licenses`。
