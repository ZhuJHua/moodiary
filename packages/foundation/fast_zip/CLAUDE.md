# fast_zip

zip 归档（`archive.rs`）：写入器（逐文件 / 逐字节，可选 AES 密码、stored 不压缩）与带取消的解压。
自带 FRB（入口类 `FastZipLib`）与原生库 **libfastzip**。2026-09-03 从 moodiary_rust 的 `archive`
crate 拆出来。

- **只有 `moodiary_export`（导出打包）与 `moodiary_sync`（本地备份 / LAN 归档）能依赖它**
  （`_nativePkgOwners`）。
- **延迟装载**：没有启动 init，`Zip.newInstance` / `Zip.extract` 之前先
  `await FastZip.ensureInitialized()`；`CancelToken()` 是同步构造，库没装载就构造会直接抛，
  所以要写在那句 await 之后。
- **zip 不开 `zstd`**：值 396,784 字节；代价是第三方工具重压成 Zstd 的备份导不进来
  （`Unsupported(93)`，报错不好懂）。我们自己写的档只有 Deflated / Stored。
- 媒体与 docx / pdf 本身都是已压缩格式，打包时传 `stored: true`，再 deflate 一遍只费时间。
- 中途抛错到不了 `finish()`，不 `dispose()` 则 fd 一直攥着，被删的半成品要等 GC 才释放磁盘——
  而失败原因往往正是磁盘满。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**；改了 `rust/Cargo.toml` 依赖必跑
  `dart tool/task.dart licenses`。
