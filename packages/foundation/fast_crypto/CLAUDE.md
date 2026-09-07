# fast_crypto

AES-256-GCM 对称加密（`aes.rs`，含整文件加解密与 Argon2id 密钥派生）与 Argon2id 密码哈希
（`password.rs`）。自带 FRB（入口类 `FastCryptoLib`）与原生库 **libfastcrypto**。
走 FRB 不走裸 `dart:ffi`：裸 FFI 只省 0.3 MB 地板，换来的是手写 C ABI 与 catch_unwind 纪律。

- 多个消费方（moodiary_storage 的应用锁 PIN、moodiary_sync 的信封加密 / LAN 协议），不进
  `_nativePkgOwners`。
- **调用方不用 init**：`Aes` / `Argon2` 是手写门面（`lib/src/crypto.dart`），每个方法先
  `FastCrypto.ensureInitialized()` 再调生成的 `api.*`，Rust 的 `Err` 统一转成 `FastCryptoException`。
  这也是为什么 api 是自由函数（`aes_derive_key` …）而不是 opaque 类。
- 全部跑在 FRB 线程池上：Argon2 派生（默认 64 MiB / 3 轮）与整文件加解密都是几十毫秒起的活。
  实测（本机）：应用锁 Argon2id 13 ms、同步 KDF 79 ms、AES-GCM 20 MiB 11 ms；纯 Dart 分别慢
  6× / 5× / 100×，这是它留在 Rust 的理由。
- `aes_decrypt_file` 的 `skip_prefix` 故意用 u32：FRB 把 u64 映射成 BigInt，Dart 侧拿 int 更顺手。
- `argon2` 钉预发布版 `=0.6.0-rc.8`，`parallel` feature 对 p=1 无效别开；Argon2 盐至少 8 字节。
- 单测（`test/crypto_test.dart`）真跑原生库：`flutter test` 会为宿主构建 hook，测试用
  `build/native_assets/<os>/` 里的产物初始化。
