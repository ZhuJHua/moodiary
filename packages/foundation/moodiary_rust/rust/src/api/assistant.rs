use anyhow::Result;
use flutter_rust_bridge::{DartFnFuture, frb};
use std::sync::Arc;

use crate::frb_generated::StreamSink;

pub use moodiary_assistant::{
    RigChatMessage, RigEventKind, RigProviderConfig, RigStreamEvent, RigToolDef,
};

#[frb(mirror(RigProviderConfig))]
pub struct _RigProviderConfig {
    /// `"openai"`（OpenAI 兼容，走 Chat Completions）或 `"anthropic"`。
    pub protocol: String,
    pub api_key: String,
    /// 留空表示该协议官方端点。
    pub base_url: String,
    pub model: String,
    pub max_tokens: u32,
    /// rig 不会自动开启思考，开启后由 Rust 按协议注入参数：Anthropic 走 extended
    /// thinking，OpenAI 兼容走 `reasoning_effort: "medium"`。
    pub thinking: bool,
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

/// 用「plain enum + 载荷字段」而非带数据的枚举变体，是为了让 FRB 生成普通 Dart
/// 类，避开它对 freezed（项目当前钉在 pre-release 版）的版本门槛。
#[frb(mirror(RigEventKind))]
pub enum _RigEventKind {
    TextDelta,
    ReasoningDelta,
    ToolCall,
    Usage,
}

#[frb(mirror(RigStreamEvent))]
pub struct _RigStreamEvent {
    pub kind: RigEventKind,
    pub text: String,
    /// 仅 [RigEventKind::Usage] 事件有意义，其余为 0。
    pub input_tokens: u32,
    pub output_tokens: u32,
}

/// Dart 取消订阅会令 `sink.add` 失败，循环随即中断并取消在途请求。
pub async fn rig_chat_stream(
    sink: StreamSink<RigStreamEvent>,
    config: RigProviderConfig,
    system_prompt: String,
    history: Vec<RigChatMessage>,
    tools: Vec<RigToolDef>,
    max_turns: u32,
    tool_dispatch: impl Fn(String, String) -> DartFnFuture<String> + Send + Sync + 'static,
) -> Result<()> {
    let emit: moodiary_assistant::EmitFn = Arc::new(move |event| sink.add(event).is_ok());
    let dispatch: moodiary_assistant::ToolDispatch =
        Arc::new(move |name, args| Box::pin(tool_dispatch(name, args)));
    moodiary_assistant::rig_chat_stream(
        emit,
        config,
        system_prompt,
        history,
        tools,
        max_turns,
        dispatch,
    )
    .await
}
