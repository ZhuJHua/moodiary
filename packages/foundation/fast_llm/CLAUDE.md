# fast_llm

LLM 对话：rig 的流式多轮 + 工具调用（`chat.rs`），工具定义从 Dart 传入、执行由 Dart 回调。
自带 FRB（入口类 `FastLlmLib`）与原生库 **libfastllm**（`rust/`，单 crate：`api/` 是 FRB 门面）。
2026-09-03 从 moodiary_rust 的 `assistant` crate 与 `assistant.dart` 门面拆出来。

- **只有 `moodiary_assistant` 能依赖它**（`tool/check_layers.dart` 的 `_nativePkgOwners`）。
- **延迟装载**：没有启动 init，`RigAssistantService.chat` 开头 `await FastLlm.ensureInitialized()`。
- **网络是自己的**：rig 依赖 reqwest，客户端由 `http_client.rs` 自建——ring provider 先装、
  **Android 换内置 webpki 根**（reqwest 默认的 rustls-platform-verifier 未初始化时首个 TLS 连接
  就 panic），与 fast_http 的 `client.rs` 是同一段逻辑的两份副本，改了要两边同步；reqwest 的
  feature 集也保持一致。代价是第二份 reqwest/rustls/tokio 底座与第二个 tokio 运行时，已拍板接受。
- 协议按**模型**解析（openai-completions / openai-responses / anthropic-messages）；Anthropic 的
  思考走 `reasoning_mode` / `reasoning_effort`，旧的 budget_tokens 写法在新 Claude 上 400。
- **改了 `rust/src/api` 必跑 `dart tool/task.dart gen-rust`**（`RigStreamEvent` 的 freezed 产物
  codegen 自己跑）；改了 `rust/Cargo.toml` 依赖必跑 `dart tool/task.dart licenses`。
