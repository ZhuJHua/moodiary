use anyhow::Result;
use flutter_rust_bridge::{DartFnFuture, frb};
use std::sync::Arc;

use crate::frb_generated::StreamSink;

pub use crate::llm::chat::{
    RigChatInput, RigChatMessage, RigProviderConfig, RigStreamEvent, RigToolDef,
};

#[frb(mirror(RigProviderConfig))]
pub struct _RigProviderConfig {
    pub protocol: String,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    pub max_tokens: u32,
    pub reasoning_mode: String,
    pub reasoning_effort: String,
    pub reasoning_budget: u32,
}

#[frb(mirror(RigChatMessage))]
pub struct _RigChatMessage {
    pub role: String,
    pub content: String,
    pub image_base64: String,
    pub image_mime: String,
}

#[frb(mirror(RigToolDef))]
pub struct _RigToolDef {
    pub name: String,
    pub description: String,
    pub parameters_json: String,
}

#[frb(mirror(RigChatInput))]
pub struct _RigChatInput {
    pub config: RigProviderConfig,
    pub system_prompt: String,
    pub history: Vec<RigChatMessage>,
    pub tools: Vec<RigToolDef>,
    pub max_turns: u32,
}

#[frb(mirror(RigStreamEvent))]
pub enum _RigStreamEvent {
    TextDelta(String),
    ReasoningDelta(String),
    ToolCall(String),
    ToolStarted {
        call_id: String,
        name: String,
        args_json: String,
    },
    ToolFinished {
        call_id: String,
        result: String,
    },
    Usage {
        input_tokens: u32,
        output_tokens: u32,
        cached_input_tokens: u32,
        cache_write_tokens: u32,
    },
    Turn {
        turn: u32,
        finish_reason: String,
        response_id: String,
        provider_request_id: String,
        input_tokens: u32,
        output_tokens: u32,
        cached_input_tokens: u32,
    },
    TurnDiscarded {
        turn: u32,
    },
}

pub async fn rig_chat_stream(
    sink: StreamSink<RigStreamEvent>,
    input: RigChatInput,
    tool_dispatch: impl Fn(String, String) -> DartFnFuture<Result<String>> + Send + Sync + 'static,
    tool_gate: impl Fn(String, String, String) -> DartFnFuture<Result<String>> + Send + Sync + 'static,
) -> Result<()> {
    let sink = Arc::new(sink);
    let emit_sink = sink.clone();
    let emit: crate::llm::chat::EmitFn = Arc::new(move |event| emit_sink.add(event).is_ok());
    let dispatch: crate::llm::chat::ToolDispatch = Arc::new(move |name, args| {
        let call = tool_dispatch(name, args);
        Box::pin(async move { call.await.unwrap_or_else(|e| format!("tool error: {e}")) })
    });
    let gate: crate::llm::chat::ToolGate = Arc::new(move |call_id, name, args| {
        let call = tool_gate(call_id, name, args);
        Box::pin(async move {
            call.await.unwrap_or_else(|e| {
                format!(
                    "{}Skipped: approval failed ({e}).",
                    crate::llm::chat::GATE_SKIP_PREFIX
                )
            })
        })
    });
    if let Err(e) = crate::llm::chat::rig_chat_stream(emit, input, dispatch, gate).await {
        let _ = sink.add_error(e);
    }
    Ok(())
}
