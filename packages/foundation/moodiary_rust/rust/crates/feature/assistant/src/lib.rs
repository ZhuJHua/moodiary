//! Rust 侧完全通用、不认识「日记」：工具定义作为数据从 Dart 传入，工具执行（含权限
//! 闸门）由 Dart 回调完成。新增 / 修改工具无需动 Rust。

use std::sync::Arc;

use anyhow::Result;
use futures::StreamExt;
use rig::client::completion::CompletionClient;
use rig::completion::Message;
use rig::completion::message::{ImageMediaType, MimeType, UserContent};
use rig::providers::{anthropic, openai};
use rig::streaming::StreamedAssistantContent;
use rig::wasm_compat::WasmCompatSend;
use rig_agent::agent::hook::{
    AgentHook, HookContext, ToolCall as HookToolCall, ToolCallAction, ToolResultAction,
    ToolResultEvent,
};
use rig_agent::agent::{Agent, AgentBuilder, MultiTurnStreamItem};
use rig_agent::client::AgentClientExt;
use rig_agent::streaming::StreamingChat;
use rig_agent::tool::{DynamicTool, ToolExecutionError, ToolOutput};
use std::future::Future;

/// 协议标识，与 Dart 的 `AssistantProviderType.id` 一一对应。
pub const PROTOCOL_OPENAI_COMPLETIONS: &str = "openai-completions";
pub const PROTOCOL_OPENAI_RESPONSES: &str = "openai-responses";
pub const PROTOCOL_ANTHROPIC_MESSAGES: &str = "anthropic-messages";

/// 思考控制模式，与 Dart 的 `ReasoningControlType` 对应。
pub const REASONING_OFF: &str = "off";
pub const REASONING_EFFORT: &str = "effort";
pub const REASONING_BUDGET: &str = "budget";

pub struct RigProviderConfig {
    /// `"openai-completions"` / `"openai-responses"` / `"anthropic-messages"`。
    /// 认不出来时按 openai-completions 处理（兼容面最广）。
    pub protocol: String,
    pub api_key: String,
    /// 自定义 baseUrl，留空表示该协议官方端点。
    pub base_url: String,
    pub model: String,
    /// 单次回复最大 token 数（Anthropic 协议必传）。
    pub max_tokens: u32,
    /// `"off"` / `"effort"` / `"budget"`。rig 不会自动开思考，一律由这里显式注入。
    pub reasoning_mode: String,
    /// `reasoning_mode == "effort"` 时的档位，取值来自 models.dev 的
    /// `reasoning_options`（`minimal` / `low` / `medium` / `high` / `xhigh` / `max` …）。
    pub reasoning_effort: String,
    /// `reasoning_mode == "budget"` 时的思考 token 预算。
    pub reasoning_budget: u32,
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
    /// 思考 / 推理增量。
    ReasoningDelta(String),
    /// 载荷是工具名。只用作「思考阶段结束」的信号（模型开始调工具了）。
    ToolCall(String),
    /// 一次工具调用**开始执行**。`call_id` 与 [`RigStreamEvent::ToolFinished`]
    /// 对应，用来把参数和结果配成一对。
    ///
    /// rig 0.40 拿不到这个 —— 那时只有个工具名。0.42 起
    /// `ToolExecutionCommitted` 给出了实际执行的那次调用（含参数），
    /// 「把工具调用显示在对话里」才成为可能。
    ToolStarted {
        call_id: String,
        name: String,
        args_json: String,
    },
    /// 一次工具调用的结果。
    ToolFinished {
        call_id: String,
        result: String,
    },
    /// 本轮聚合用量（含内部工具轮次）。
    Usage {
        input_tokens: u32,
        output_tokens: u32,
        cached_input_tokens: u32,
        cache_write_tokens: u32,
    },
}

/// 工具分发回调：入参 `(tool_name, args_json)`，返回工具结果字符串。
/// 权限闸门在上层（Dart）此回调内部完成（被拒时返回一句说明、不执行副作用）。
pub type ToolDispatch =
    Arc<dyn Fn(String, String) -> futures::future::BoxFuture<'static, String> + Send + Sync>;
/// 流式事件出口：返回 false 表示下游已取消订阅，循环随即中断。
pub type EmitFn = Arc<dyn Fn(RigStreamEvent) -> bool + Send + Sync>;

/// 把 Dart 传来的工具定义包成 rig 的运行时工具。
///
/// 0.42 起 rig 的对象安全分发是私有的，运行时才知道名字与回调的工具一律走
/// [`DynamicTool`]（0.40 时代那个自实现 `ToolDyn` 的 `ProxyTool` 没有了）。
///
/// schema 解析失败的工具会被跳过。
fn build_tools(tools: Vec<RigToolDef>, dispatch: &ToolDispatch) -> Vec<DynamicTool> {
    tools
        .into_iter()
        .filter_map(|t| {
            let parameters: serde_json::Value = serde_json::from_str(&t.parameters_json).ok()?;
            let dispatch = dispatch.clone();
            let name = t.name.clone();
            Some(DynamicTool::new(
                t.name,
                t.description,
                parameters,
                move |_context, arguments| {
                    let dispatch = dispatch.clone();
                    let name = name.clone();
                    Box::pin(async move {
                        // 任何失败都以文本形式回灌模型（不抛错），让对话能优雅继续。
                        let text = dispatch(name, arguments.to_string()).await;
                        Ok::<ToolOutput, ToolExecutionError>(ToolOutput::from(text))
                    })
                },
            ))
        })
        .collect()
}

/// 工具生命周期的观测钩子 —— **rig 官方推荐的实时观测口子**。
///
/// 不走流式那条路是有原因的：`MultiTurnStreamItem::ToolExecutionCommitted` 的文档
/// 明写「this is not a real-time start notification」，它和 `ToolResult` 是整批
/// 结算之后一起下发的。照那条路做，「正在执行」那一态永远看不到 —— 工具跑三秒，
/// 界面也是从空白直接跳到已完成。
///
/// 下游取消订阅时返回 `Stop`：工具可能带副作用，没人接收结果就不该再跑下去。
struct ToolObserver {
    emit: EmitFn,
}

impl AgentHook for ToolObserver {
    fn on_tool_call(
        &self,
        _ctx: &HookContext,
        event: HookToolCall<'_>,
    ) -> impl Future<Output = ToolCallAction> + WasmCompatSend {
        let alive = (self.emit)(RigStreamEvent::ToolStarted {
            call_id: event.internal_call_id.to_string(),
            name: event.tool_name.to_string(),
            args_json: event.args.to_string(),
        });
        async move {
            if alive {
                ToolCallAction::Run
            } else {
                ToolCallAction::Stop("client unsubscribed".into())
            }
        }
    }

    fn on_tool_result(
        &self,
        _ctx: &HookContext,
        event: ToolResultEvent<'_>,
    ) -> impl Future<Output = ToolResultAction> + WasmCompatSend {
        let alive = (self.emit)(RigStreamEvent::ToolFinished {
            call_id: event.internal_call_id.to_string(),
            result: event.raw_result.output().render(),
        });
        async move {
            if alive {
                ToolResultAction::Keep
            } else {
                ToolResultAction::Stop("client unsubscribed".into())
            }
        }
    }
}

/// 把工具挂上去并收尾。
///
/// 0.42 的 `AgentBuilder` 是**类型状态**的：挂过工具之后类型会变成
/// `AgentBuilder<WithBuilderTools>`，所以没法先 fold 再统一 build，只能分两支走。
/// 也没有 `tools(Vec)` 了，一次一个。
fn finish(builder: AgentBuilder, tools: Vec<DynamicTool>, emit: &EmitFn) -> Agent {
    let builder = builder.add_hook(ToolObserver { emit: emit.clone() });
    let mut iter = tools.into_iter();
    let Some(first) = iter.next() else {
        return builder.build();
    };
    let mut builder = builder.dynamic_tool(first);
    for tool in iter {
        builder = builder.dynamic_tool(tool);
    }
    builder.build()
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
    Message::User { content: parts }
}

/// Anthropic Messages 的思考参数。**这里有一处很容易踩错**：
/// `thinking: {type: "enabled", budget_tokens: N}` 在 Opus 4.6 / Sonnet 4.6 已废弃，
/// 在 Opus 4.7 / 4.8 / 5、Sonnet 5、Fable 5 上**直接 400**。新模型走
/// `thinking: {type:"adaptive"}` + `output_config: {effort}`。
///
/// 走哪一条不由我们猜：models.dev 的 `reasoning_options` 已经把新老分开了
/// （新模型标 effort，老模型标 budget_tokens），Dart 侧据此选 mode。
///
/// `display: "summarized"` 不能省 —— 那几个模型的默认是 `"omitted"`，
/// thinking 块会以空字符串流回来，思考区看着就是一片空白。
fn anthropic_reasoning_params(config: &RigProviderConfig) -> Option<serde_json::Value> {
    match config.reasoning_mode.as_str() {
        REASONING_EFFORT if !config.reasoning_effort.is_empty() => Some(serde_json::json!({
            "thinking": { "type": "adaptive", "display": "summarized" },
            "output_config": { "effort": config.reasoning_effort },
        })),
        REASONING_BUDGET => {
            let budget = clamp_thinking_budget(config.reasoning_budget, config.max_tokens);
            Some(serde_json::json!({
                "thinking": { "type": "enabled", "budget_tokens": budget },
            }))
        }
        _ => None,
    }
}

/// OpenAI Chat Completions 的思考参数。budget 型在这条路上没有对应字段，省略即可
/// （Dart 只会给 anthropic 模型选 budget 模式）。
fn openai_completions_reasoning_params(config: &RigProviderConfig) -> Option<serde_json::Value> {
    match config.reasoning_mode.as_str() {
        REASONING_EFFORT if !config.reasoning_effort.is_empty() => {
            Some(serde_json::json!({ "reasoning_effort": config.reasoning_effort }))
        }
        _ => None,
    }
}

/// OpenAI Responses 的思考参数。`summary: "auto"` 是拿到推理增量的前提 ——
/// 不给的话 `response.reasoning_summary_text.delta` 根本不会下发，思考区是空的。
fn openai_responses_reasoning_params(config: &RigProviderConfig) -> Option<serde_json::Value> {
    match config.reasoning_mode.as_str() {
        REASONING_EFFORT if !config.reasoning_effort.is_empty() => Some(serde_json::json!({
            "reasoning": { "effort": config.reasoning_effort, "summary": "auto" },
        })),
        _ => None,
    }
}

/// Anthropic 老模型要求 `budget_tokens ∈ [1024, max_tokens)`。
fn clamp_thinking_budget(requested: u32, max_tokens: u32) -> u32 {
    let ceiling = max_tokens.saturating_sub(1).max(1024);
    requested.clamp(1024, ceiling)
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
        PROTOCOL_ANTHROPIC_MESSAGES => {
            let mut builder = anthropic::Client::builder().api_key(&config.api_key);
            if !config.base_url.is_empty() {
                builder = builder.base_url(&config.base_url);
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
                .max_tokens(config.max_tokens as u64);
            if let Some(params) = anthropic_reasoning_params(&config) {
                ab = ab.additional_params(params);
            }
            drive(
                finish(ab, boxed_tools, &emit),
                prompt,
                prior,
                &emit,
                max_turns,
            )
            .await
        }
        PROTOCOL_OPENAI_RESPONSES => {
            let mut builder = openai::Client::builder().api_key(&config.api_key);
            if !config.base_url.is_empty() {
                builder = builder.base_url(&config.base_url);
            }
            let client = builder
                .http_client(http_client)
                .build()
                .map_err(|e| anyhow::anyhow!("failed to build openai responses client: {e}"))?;
            let mut ab = client
                .agent(&config.model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64);
            if let Some(params) = openai_responses_reasoning_params(&config) {
                ab = ab.additional_params(params);
            }
            drive(
                finish(ab, boxed_tools, &emit),
                prompt,
                prior,
                &emit,
                max_turns,
            )
            .await
        }
        // 其余一律按 Chat Completions 处理（自定义端点通用性最好）。
        _ => {
            let mut builder = openai::CompletionsClient::builder().api_key(&config.api_key);
            if !config.base_url.is_empty() {
                builder = builder.base_url(&config.base_url);
            }
            let client = builder
                .http_client(http_client)
                .build()
                .map_err(|e| anyhow::anyhow!("failed to build openai client: {e}"))?;
            let mut ab = client
                .agent(&config.model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64);
            if let Some(params) = openai_completions_reasoning_params(&config) {
                ab = ab.additional_params(params);
            }
            drive(
                finish(ab, boxed_tools, &emit),
                prompt,
                prior,
                &emit,
                max_turns,
            )
            .await
        }
    }
}

async fn drive(
    agent: Agent,
    prompt: Message,
    history: Vec<Message>,
    emit: &EmitFn,
    max_turns: u32,
) -> Result<()> {
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
                    cached_input_tokens: usage.cached_input_tokens as u32,
                    cache_write_tokens: usage.cache_creation_input_tokens as u32,
                });
                break;
            }
            Ok(_) => {} // 完整 reasoning 块 / 工具结果等当前不透传
            Err(e) => return Err(anyhow::anyhow!("rig stream error: {e}")),
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config(mode: &str, effort: &str, budget: u32) -> RigProviderConfig {
        RigProviderConfig {
            protocol: PROTOCOL_ANTHROPIC_MESSAGES.into(),
            api_key: String::new(),
            base_url: String::new(),
            model: String::new(),
            max_tokens: 8192,
            reasoning_mode: mode.into(),
            reasoning_effort: effort.into(),
            reasoning_budget: budget,
        }
    }

    #[test]
    fn anthropic_effort_uses_adaptive_thinking_not_budget_tokens() {
        let params = anthropic_reasoning_params(&config(REASONING_EFFORT, "high", 0)).unwrap();
        assert_eq!(params["thinking"]["type"], "adaptive");
        assert_eq!(params["thinking"]["display"], "summarized");
        assert_eq!(params["output_config"]["effort"], "high");
        assert!(params["thinking"].get("budget_tokens").is_none());
    }

    #[test]
    fn anthropic_budget_mode_clamps_into_range() {
        let params = anthropic_reasoning_params(&config(REASONING_BUDGET, "", 100)).unwrap();
        assert_eq!(params["thinking"]["budget_tokens"], 1024);
        let mut cfg = config(REASONING_BUDGET, "", 999_999);
        cfg.max_tokens = 4096;
        let params = anthropic_reasoning_params(&cfg).unwrap();
        assert_eq!(params["thinking"]["budget_tokens"], 4095);
    }

    #[test]
    fn reasoning_off_injects_nothing_on_every_protocol() {
        let cfg = config(REASONING_OFF, "", 0);
        assert!(anthropic_reasoning_params(&cfg).is_none());
        assert!(openai_completions_reasoning_params(&cfg).is_none());
        assert!(openai_responses_reasoning_params(&cfg).is_none());
    }

    #[test]
    fn openai_responses_requests_a_summary() {
        let params =
            openai_responses_reasoning_params(&config(REASONING_EFFORT, "medium", 0)).unwrap();
        assert_eq!(params["reasoning"]["effort"], "medium");
        assert_eq!(params["reasoning"]["summary"], "auto");
    }

    #[test]
    fn openai_completions_uses_flat_reasoning_effort() {
        let params =
            openai_completions_reasoning_params(&config(REASONING_EFFORT, "low", 0)).unwrap();
        assert_eq!(params["reasoning_effort"], "low");
    }
}
