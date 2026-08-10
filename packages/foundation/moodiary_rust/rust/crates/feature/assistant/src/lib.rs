//! Rust 侧完全通用、不认识「日记」：工具定义作为数据从 Dart 传入，工具执行（含权限
//! 闸门）由 Dart 回调完成。新增 / 修改工具无需动 Rust。

use std::sync::Arc;

use anyhow::Result;
use futures::StreamExt;
use rig::OneOrMany;
use rig::agent::{Agent, AgentBuilder, MultiTurnStreamItem};
use rig::client::completion::CompletionClient;
use rig::completion::message::{ImageMediaType, MimeType, UserContent};
use rig::completion::{CompletionModel, GetTokenUsage, Message};
use rig::providers::{anthropic, openai};
use rig::streaming::{StreamedAssistantContent, StreamingChat};
use rig::tool::{ToolDyn, ToolError};
use rig::wasm_compat::{WasmBoxedFuture, WasmCompatSend};

pub struct RigProviderConfig {
    /// `"openai"`（OpenAI 兼容，走 Chat Completions API）或 `"anthropic"`。
    pub protocol: String,
    pub api_key: String,
    /// 自定义 baseUrl，留空表示该协议官方端点。
    pub base_url: String,
    pub model: String,
    /// 单次回复最大 token 数（Anthropic 协议必传）。
    pub max_tokens: u32,
    /// 是否开启思考（reasoning）模式。开启后由 Rust 按协议注入思考参数（用默认强度）：
    /// Anthropic 走 extended thinking（预算按 max_tokens 取默认值），
    /// OpenAI 兼容走 `reasoning_effort: "medium"`。rig 不会自动开启，必须显式注入。
    pub thinking: bool,
}

pub struct RigChatMessage {
    /// `"user"` 或 `"assistant"`。
    pub role: String,
    pub content: String,
    /// 可选图片（base64 编码，不含 data URL 前缀）。空表示无图；仅 user 消息使用。
    pub image_base64: String,
    pub image_mime: String,
}

pub struct RigToolDef {
    /// 模型侧 function name，须与 Dart 工具路由表里的 key 一致。
    pub name: String,
    pub description: String,
    /// 入参 JSON Schema（字符串，须是 `type: object`）。
    pub parameters_json: String,
}

pub enum RigStreamEvent {
    TextDelta(String),
    /// 思考 / 推理增量（Anthropic thinking、OpenAI 兼容 `reasoning_content`）。
    ReasoningDelta(String),
    /// 载荷是工具名。
    ToolCall(String),
    /// 本轮聚合用量（含内部工具轮次）。
    Usage { input_tokens: u32, output_tokens: u32 },
}

/// 工具分发回调：入参 `(tool_name, args_json)`，返回工具结果字符串。
/// 权限闸门在上层（Dart）此回调内部完成（被拒时返回一句说明、不执行副作用）。
pub type ToolDispatch =
    Arc<dyn Fn(String, String) -> futures::future::BoxFuture<'static, String> + Send + Sync>;
/// 流式事件出口：返回 false 表示下游已取消订阅，循环随即中断。
pub type EmitFn = Arc<dyn Fn(RigStreamEvent) -> bool + Send + Sync>;

struct ProxyTool {
    name: String,
    description: String,
    parameters: serde_json::Value,
    dispatch: ToolDispatch,
}

impl ToolDyn for ProxyTool {
    fn name(&self) -> String {
        self.name.clone()
    }

    fn description(&self) -> String {
        self.description.clone()
    }

    fn parameters(&self) -> serde_json::Value {
        self.parameters.clone()
    }

    fn call(&self, args: String) -> WasmBoxedFuture<'_, Result<String, ToolError>> {
        let dispatch = self.dispatch.clone();
        let name = self.name.clone();
        Box::pin(async move {
            // 任何失败都以文本形式回灌模型（不抛错），让对话能优雅继续。
            Ok(dispatch(name, args).await)
        })
    }
}

/// schema 解析失败的工具会被跳过。
fn build_tools(tools: Vec<RigToolDef>, dispatch: &ToolDispatch) -> Vec<Box<dyn ToolDyn>> {
    tools
        .into_iter()
        .filter_map(|t| {
            let parameters = serde_json::from_str(&t.parameters_json).ok()?;
            Some(Box::new(ProxyTool {
                name: t.name,
                description: t.description,
                parameters,
                dispatch: dispatch.clone(),
            }) as Box<dyn ToolDyn>)
        })
        .collect()
}

fn split_history(history: Vec<RigChatMessage>) -> Result<(Message, Vec<Message>)> {
    if history.is_empty() {
        anyhow::bail!("chat history is empty");
    }
    let mut msgs: Vec<Message> = history.into_iter().map(to_message).collect();
    let prompt = msgs.pop().expect("history checked non-empty");
    Ok((prompt, msgs))
}

fn to_message(m: RigChatMessage) -> Message {
    if m.role != "user" {
        return Message::assistant(m.content);
    }
    if m.image_base64.is_empty() {
        return Message::user(m.content);
    }
    let media_type = if m.image_mime.is_empty() {
        None
    } else {
        ImageMediaType::from_mime_type(&m.image_mime)
    };
    let mut parts: Vec<UserContent> = Vec::new();
    if !m.content.is_empty() {
        parts.push(UserContent::text(m.content));
    }
    parts.push(UserContent::image_base64(m.image_base64, media_type, None));
    match OneOrMany::many(parts) {
        Ok(content) => Message::User { content },
        // parts 至少含图片一项，理论不可达；兜底回退纯文本。
        Err(_) => Message::user(String::new()),
    }
}

/// 流式对话 + 多轮工具调用。`emit` 返回 false（下游取消订阅）时循环中断（取消在途
/// 请求）。硬性失败（构造客户端 / 流错误）以 `Err` 形式上抛。
pub async fn rig_chat_stream(
    emit: EmitFn,
    config: RigProviderConfig,
    system_prompt: String,
    history: Vec<RigChatMessage>,
    tools: Vec<RigToolDef>,
    max_turns: u32,
    dispatch: ToolDispatch,
) -> Result<()> {
    let boxed_tools = build_tools(tools, &dispatch);
    let (prompt, prior) = split_history(history)?;
    let http_client = moodiary_http::client::shared()?;

    match config.protocol.as_str() {
        "anthropic" => {
            let mut builder = anthropic::Client::builder().api_key(config.api_key);
            if !config.base_url.is_empty() {
                builder = builder.base_url(config.base_url);
            }
            let client = builder
                .http_client(http_client)
                .build()
                .map_err(|e| anyhow::anyhow!("failed to build anthropic client: {e}"))?;
            // 缓存命中要求 system prompt 逐轮字节一致：易变文本一律走消息、勿进 system。
            let model = client
                .completion_model(&config.model)
                .with_prompt_caching()
                .with_automatic_caching();
            let mut ab = AgentBuilder::new(model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64)
                .tools(boxed_tools);
            if config.thinking {
                // Anthropic extended thinking：必须显式给出 budget_tokens。
                ab = ab.additional_params(serde_json::json!({
                    "thinking": {
                        "type": "enabled",
                        "budget_tokens": anthropic_thinking_budget(config.max_tokens),
                    }
                }));
            }
            drive(ab.build(), prompt, prior, &emit, max_turns).await
        }
        // 其余一律按 OpenAI 兼容处理（自定义端点通用性最好）。
        _ => {
            let mut builder = openai::CompletionsClient::builder().api_key(config.api_key);
            if !config.base_url.is_empty() {
                builder = builder.base_url(config.base_url);
            }
            let client = builder
                .http_client(http_client)
                .build()
                .map_err(|e| anyhow::anyhow!("failed to build openai client: {e}"))?;
            let mut ab = client
                .agent(&config.model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64)
                .tools(boxed_tools);
            if config.thinking {
                // OpenAI o 系列 / gpt-5 的标准参数；DeepSeek-reasoner 等无视它也照常回传推理。
                ab = ab.additional_params(serde_json::json!({ "reasoning_effort": "medium" }));
            }
            drive(ab.build(), prompt, prior, &emit, max_turns).await
        }
    }
}

/// Anthropic 扩展思考要求 `budget_tokens ∈ [1024, max_tokens)`。取 max_tokens 的一半并夹到该区间，
/// 再保证严格小于 max_tokens（否则 API 报错）。
fn anthropic_thinking_budget(max_tokens: u32) -> u32 {
    let budget = (max_tokens / 2).clamp(1024, 2048);
    if budget >= max_tokens {
        max_tokens.saturating_sub(1)
    } else {
        budget
    }
}

async fn drive<M>(
    agent: Agent<M>,
    prompt: Message,
    history: Vec<Message>,
    emit: &EmitFn,
    max_turns: u32,
) -> Result<()>
where
    M: CompletionModel + 'static,
    M::StreamingResponse: GetTokenUsage + WasmCompatSend + Clone + Unpin,
{
    // max_turns 是「含首个调用在内的模型调用总数」（rig 0.40 语义）。
    let mut stream = agent
        .stream_chat(prompt, history)
        .max_turns(max_turns as usize)
        .await;

    while let Some(item) = stream.next().await {
        match item {
            Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::Text(text))) => {
                if !emit(RigStreamEvent::TextDelta(text.text)) {
                    break; // Dart 已取消订阅 → 中断在途请求
                }
            }
            Ok(MultiTurnStreamItem::StreamAssistantItem(
                StreamedAssistantContent::ReasoningDelta { reasoning, .. },
            )) => {
                if !emit(RigStreamEvent::ReasoningDelta(reasoning)) {
                    break;
                }
            }
            Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::ToolCall {
                tool_call,
                ..
            })) => {
                if !emit(RigStreamEvent::ToolCall(tool_call.function.name)) {
                    break;
                }
            }
            Ok(MultiTurnStreamItem::FinalResponse(final_resp)) => {
                // 供应商未上报时为全 0。
                let usage = final_resp.usage();
                let _ = emit(RigStreamEvent::Usage {
                    input_tokens: usage.input_tokens as u32,
                    output_tokens: usage.output_tokens as u32,
                });
                break;
            }
            Ok(_) => {} // 完整 reasoning 块 / 工具结果等当前不透传
            Err(e) => return Err(anyhow::anyhow!("rig stream error: {e}")),
        }
    }
    Ok(())
}
