# moodiary_rust

Moodiary 的业务 Rust 库：网络三层——`http`（客户端 + hyper 应用内服务端）→ `sync`（WebDAV / S3）
/ `llm`（rig 流式对话）——共享一套 reqwest / rustls / tokio 底座与一个连接池，外加 `graph`
（ForceAtlas2 + Barnes-Hut 布局流，与网络零共享，只是不值得单独一个库）。自带 FRB（入口类
`RustLib`）与原生库 **libmoodiary_rust**。2026-09-03 由 fast_http + fast_llm + fast_graph 合并而来：
http 与 llm 之间实测重复 2 MiB `.text`（整套网络底座）是 8 个库里唯一一处真实重复，合并后 rig 也
用回 `http::client::shared()` 的连接池。分词（fast_tokenizer）**不**并进来：它启动就要装载，会让
整个网络库跟着在启动时 dlopen，用户明确不要。

- **四个 Dart 门面各有主**（`tool/check_layers.dart` 的 `_rustFacadeOwners`，另有「不许深入
  `package:moodiary_rust/src/`」）：`http.dart` → moodiary_http；`sync.dart` → moodiary_sync；
  `llm.dart` → moodiary_assistant；`graph.dart` → moodiary_diary。别的包要取消令牌走
  moodiary_http 转出的 `CancelToken`。
- **延迟装载**：没有启动 init。任何调用前 `await MoodiaryRust.ensureInitialized()`——包括
  `CancelToken()` 这类同步构造，库没装载就构造会直接抛。`RustHttpClient` 把它折进 `_client`
  那个 Future，`RustHttpServer.start`、两个同步后端的 `_client()`、`RigAssistantService.chat`
  各自先 await；`graph.dart` 的 `layoutGraphStream` 是手写 `async*`，开流前自己 await。
- 客户端两个坑（`http/client.rs` 文件头）：reqwest 开的是 `rustls-no-provider`，建 client 前要装
  ring provider；**Android 换内置 webpki 根**（rustls-platform-verifier 未初始化时首个 TLS 连接
  panic），其余平台走系统信任库。**reqwest 必须保留 gzip / brotli / deflate**：和风天气无条件 gzip。
- 服务端（`http/server.rs`）：请求体超阈值落盘到 `spool_dir`，进度回调，handler 异常折叠为 500，
  文件响应单段 Range（webview 视频 206）；moodiary_sync 的 LAN 测试用 dart:io 替身模拟这套语义。
- llm：协议按**模型**解析（openai-completions / openai-responses / anthropic-messages）；Anthropic
  的思考走 `reasoning_mode` / `reasoning_effort`，旧的 budget_tokens 写法在新 Claude 上 400。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**（`RigStreamEvent` 的 freezed 产物
  codegen 自己跑）；改了 `rust/Cargo.toml` 依赖必跑 `dart tool/task.dart licenses`。
- graph（`graph/layout.rs`）：ForceAtlas2（Jacomy 2014）+ Barnes-Hut，两处刻意偏离原版——保留
  线性向心力（把不连通分量收进视野）与 forceCollide 碰撞（硬保不重叠）；`normalizeScale` 把发出的
  坐标按相连中位距归一化；帧率由 `emit_every` / `frame_delay_ms` 定，跑在 FRB 线程池上。
