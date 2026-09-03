# fast_http

HTTP 传输：reqwest 客户端（含上传 / 下载流）、hyper 应用内服务端、骑在同一个客户端上的
WebDAV / S3 对象读写。自带 FRB（入口类 `FastHttpLib`）与原生库 **libfasthttp**（`rust/`，单 crate：
`api/` 是 FRB 门面，`http/` 与 `sync/` 是引擎，只收纯闭包）。2026-09-03 从 moodiary_rust 的
`http` + `sync` 两个 crate 与 `foundation.dart` / `sync.dart` 门面拆出来。

- **foundation 叶子包，只有 `moodiary_http`（core 的端口实现）与 `moodiary_sync` 能依赖它**
  （`tool/check_layers.dart` 的 `_nativePkgOwners`）。别的包要取消令牌走 `moodiary_http` 转出的
  `CancelToken`。
- **延迟装载**：没有启动 init。任何调用前 `await FastHttp.ensureInitialized()`——包括 `CancelToken()`
  这类同步构造，库没装载就构造会直接抛。`RustHttpClient` 把它折进 `_client` 那个 Future，
  `RustHttpServer.start` 与两个同步后端的 `_client()` 各自先 await。
- 客户端两个坑（`http/client.rs` 文件头）：reqwest 开的是 `rustls-no-provider`，建 client 前要装
  ring provider；**Android 换内置 webpki 根**（rustls-platform-verifier 未初始化时首个 TLS 连接
  panic），其余平台走系统信任库（能认自签 / 企业 CA）。s3 / webdav 共用 `client::shared()` 的连接池。
  rig 那份客户端在 fast_llm 里是同一段逻辑的副本，改了要两边同步。
- **reqwest 必须保留 gzip / brotli / deflate**：和风天气无条件 gzip。
- 服务端（`http/server.rs`）：请求体超阈值落盘到 `spool_dir`，进度回调，handler 异常折叠为 500；
  moodiary_sync 的 LAN 测试用 dart:io 替身模拟这套语义，不装原生库。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**；改了 `rust/Cargo.toml` 依赖必跑
  `dart tool/task.dart licenses`。
