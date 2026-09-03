# moodiary_rust

Moodiary 的网络业务库：一套 reqwest / rustls / tokio 底座上分三层——`http`（客户端 + hyper 应用内
服务端）→ `sync`（WebDAV / S3）/ `llm`（rig 流式对话）。自带 FRB（入口类 `RustLib`）与原生库
**libmoodiary_rust**。2026-09-03 由 fast_http + fast_llm 合并而来：两者之间实测重复 2 MiB `.text`
（整套网络底座）是 8 个库里唯一一处真实重复，合并后 rig 也用回 `http::client::shared()` 的连接池。
与网络无关的能力各自成包（fast_*），别再往这里塞——分词（fast_tokenizer）启动就要装载，并进来会
让整个网络库跟着在启动时 dlopen，用户 2026-09-03 明确不要。

- **三个 Dart 门面各有主**（`tool/check_layers.dart` 的 `_rustFacadeOwners`，另有「不许深入
  `package:moodiary_rust/src/`」）：`http.dart` → moodiary_http；`sync.dart` → moodiary_sync；
  `llm.dart` → moodiary_assistant。别的包要取消令牌走 moodiary_http 转出的 `CancelToken`。
- **延迟装载**：没有启动 init。任何调用前 `await MoodiaryRust.ensureInitialized()`——包括
  `CancelToken()` 这类同步构造，库没装载就构造会直接抛。`RustHttpClient` 把它折进 `_client`
  那个 Future，`RustHttpServer.start`、两个同步后端的 `_client()`、`RigAssistantService.chat`
  各自先 await。
- 客户端两个坑（`http/client.rs` 文件头）：reqwest 开的是 `rustls-no-provider`，建 client 前要装
  ring provider；**Android 换内置 webpki 根**（rustls-platform-verifier 未初始化时首个 TLS 连接
  panic），其余平台走系统信任库。**reqwest 必须保留 gzip / brotli / deflate**：和风天气无条件 gzip。
- 服务端（`http/server.rs`）：请求体超阈值落盘到 `spool_dir`，进度回调，handler 异常折叠为 500，
  文件响应单段 Range（webview 视频 206）；moodiary_sync 的 LAN 测试用 dart:io 替身模拟这套语义。
- llm：协议按**模型**解析（openai-completions / openai-responses / anthropic-messages）；Anthropic
  的思考走 `reasoning_mode` / `reasoning_effort`，旧的 budget_tokens 写法在新 Claude 上 400。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**（`RigStreamEvent` 的 freezed 产物
  codegen 自己跑）；改了 `rust/Cargo.toml` 依赖必跑 `dart tool/task.dart licenses`。
