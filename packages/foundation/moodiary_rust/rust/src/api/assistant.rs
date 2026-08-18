use anyhow::Result;
use flutter_rust_bridge::{DartFnFuture, frb};
use std::sync::Arc;

use crate::frb_generated::StreamSink;

pub use moodiary_assistant::{RigChatMessage, RigProviderConfig, RigStreamEvent, RigToolDef};

#[frb(mirror(RigProviderConfig))]
pub struct _RigProviderConfig {
    /// `"openai-completions"` / `"openai-responses"` / `"anthropic-messages"`。
    pub protocol: String,
    pub api_key: String,
    /// 留空表示该协议官方端点。
    pub base_url: String,
    pub model: String,
    pub max_tokens: u32,
    /// `"off"` / `"effort"` / `"budget"`。rig 不会自动开启思考，一律由 Rust 按协议注入。
    pub reasoning_mode: String,
    /// effort 模式的档位，取值来自 models.dev 的 `reasoning_options`。
    pub reasoning_effort: String,
    /// budget 模式的思考 token 预算（Anthropic 老模型专用）。
    pub reasoning_budget: u32,
}

#[frb(mirror(RigChatMessage))]
pub struct _RigChatMessage {
    /// `"user"` 或 `"assistant"`。
    pub role: String,
    pub content: String,
    /// base64，不含 data URL 前缀。空表示无图；仅 user 消息使用。
    pub image_base64: String,
    pub image_mime: String,
}

#[frb(mirror(RigToolDef))]
pub struct _RigToolDef {
    /// 须与 Dart 工具路由表里的 key 一致。
    pub name: String,
    pub description: String,
    /// 入参 JSON Schema（字符串，须是 `type: object`）。FRB 的 serde_json::Value 只支持
    /// 函数参数/返回值，放进 mirror 结构体字段会缺 IntoIntoDart，所以这里仍走字符串。
    pub parameters_json: String,
}

#[frb(mirror(RigStreamEvent))]
pub enum _RigStreamEvent {
    TextDelta(String),
    ReasoningDelta(String),
    ToolCall(String),
    Usage {
        input_tokens: u32,
        output_tokens: u32,
        cached_input_tokens: u32,
        cache_write_tokens: u32,
    },
}

/// Dart 取消订阅会令 `sink.add` 失败，循环随即中断并取消在途请求。
///
/// 失败必须经 `sink.add_error` 下发：流函数的 `Err` 返回值走另一条 port，Dart 生成码
/// 把它 `unawaited` 掉，`await for` 只会正常结束。
pub async fn rig_chat_stream(
    sink: StreamSink<RigStreamEvent>,
    config: RigProviderConfig,
    system_prompt: String,
    history: Vec<RigChatMessage>,
    tools: Vec<RigToolDef>,
    max_turns: u32,
    tool_dispatch: impl Fn(String, String) -> DartFnFuture<Result<String>> + Send + Sync + 'static,
) -> Result<()> {
    // 包 Arc 而非 sink.clone()：StreamSink 的 derive(Clone) 带了多余的 `T: Clone` 约束。
    let sink = Arc::new(sink);
    let emit_sink = sink.clone();
    let emit: moodiary_assistant::EmitFn = Arc::new(move |event| emit_sink.add(event).is_ok());
    // 回调必须声明成可失败：不可失败版本的生成代码会对 Dart 抛出的异常 `.expect`，
    // 变成一次 Rust panic。这里只兜意料外的抛出，同样回灌模型而不中断对话。
    let dispatch: moodiary_assistant::ToolDispatch = Arc::new(move |name, args| {
        let call = tool_dispatch(name, args);
        Box::pin(async move { call.await.unwrap_or_else(|e| format!("tool error: {e}")) })
    });
    if let Err(e) = moodiary_assistant::rig_chat_stream(
        emit,
        config,
        system_prompt,
        history,
        tools,
        max_turns,
        dispatch,
    )
    .await
    {
        let _ = sink.add_error(e);
    }
    Ok(())
}
