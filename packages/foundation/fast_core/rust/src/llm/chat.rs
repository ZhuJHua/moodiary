use std::sync::Arc;

use anyhow::Result;
use futures::StreamExt;
use rig::client::completion::CompletionClient;
use rig::completion::message::{ImageMediaType, MimeType, UserContent};
use rig::completion::{FinishReason, Message};
use rig::providers::{anthropic, openai};
use rig::streaming::StreamedAssistantContent;
use rig::wasm_compat::WasmCompatSend;
use rig_agent::agent::hook::{
    AgentHook, HookContext, InvalidToolCallAction, InvalidToolCallContext,
    ToolCall as HookToolCall, ToolCallAction, ToolResultAction, ToolResultEvent,
};
use rig_agent::agent::{Agent, AgentBuilder, MultiTurnStreamItem, StreamingError};
use rig_agent::client::AgentClientExt;
use rig_agent::completion::PromptError;
use rig_agent::streaming::StreamingChat;
use rig_agent::tool::{DynamicTool, ToolExecutionError, ToolOutput};
use std::future::Future;

pub const PROTOCOL_OPENAI_COMPLETIONS: &str = "openai-completions";
pub const PROTOCOL_OPENAI_RESPONSES: &str = "openai-responses";
pub const PROTOCOL_ANTHROPIC_MESSAGES: &str = "anthropic-messages";

pub const REASONING_OFF: &str = "off";
pub const REASONING_EFFORT: &str = "effort";
pub const REASONING_BUDGET: &str = "budget";

pub const GATE_RUN: &str = "run";
pub const GATE_SKIP_PREFIX: &str = "skip:";

pub const ERR_MAX_TURNS: &str = "max_turns";
pub const ERR_CANCELLED: &str = "cancelled";
pub const ERR_UNKNOWN_TOOL: &str = "unknown_tool";
pub const ERR_COMPLETION: &str = "completion";

pub struct RigProviderConfig {
    pub protocol: String,
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    pub max_tokens: u32,
    pub reasoning_mode: String,
    pub reasoning_effort: String,
    pub reasoning_budget: u32,
}

pub struct RigChatMessage {
    pub role: String,
    pub content: String,
    pub image_base64: String,
    pub image_mime: String,
}

pub struct RigToolDef {
    pub name: String,
    pub description: String,
    pub parameters_json: String,
}

pub struct RigChatInput {
    pub config: RigProviderConfig,
    pub system_prompt: String,
    pub history: Vec<RigChatMessage>,
    pub tools: Vec<RigToolDef>,
    pub max_turns: u32,
}

pub enum RigStreamEvent {
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

pub type ToolDispatch =
    Arc<dyn Fn(String, String) -> futures::future::BoxFuture<'static, String> + Send + Sync>;
pub type ToolGate = Arc<
    dyn Fn(String, String, String) -> futures::future::BoxFuture<'static, String> + Send + Sync,
>;
pub type EmitFn = Arc<dyn Fn(RigStreamEvent) -> bool + Send + Sync>;

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
                        let text = dispatch(name, arguments.to_string()).await;
                        Ok::<ToolOutput, ToolExecutionError>(ToolOutput::from(text))
                    })
                },
            ))
        })
        .collect()
}

struct ToolObserver {
    emit: EmitFn,
    gate: ToolGate,
}

fn repair_tool_name(emitted: &str, available: &[String]) -> Option<String> {
    let bare = emitted.rsplit(['.', ':', '/']).next().unwrap_or(emitted);
    let mut hits = available
        .iter()
        .filter(|name| name.eq_ignore_ascii_case(bare));
    let hit = hits.next()?;
    if hits.next().is_some() || hit == emitted {
        return None;
    }
    Some(hit.clone())
}

fn finish_reason_str(reason: Option<&FinishReason>) -> String {
    match reason {
        Some(FinishReason::Stop) => "stop".into(),
        Some(FinishReason::Length) => "length".into(),
        Some(FinishReason::ToolCalls) => "tool_calls".into(),
        Some(FinishReason::ContentFilter) => "content_filter".into(),
        Some(FinishReason::Other(other)) => other.clone(),
        None => String::new(),
    }
}

fn classify(error: StreamingError) -> anyhow::Error {
    let code = match &error {
        StreamingError::Prompt(prompt) => match prompt.as_ref() {
            PromptError::MaxTurnsError { .. } => ERR_MAX_TURNS,
            PromptError::PromptCancelled { .. } => ERR_CANCELLED,
            PromptError::UnknownToolCall { .. } => ERR_UNKNOWN_TOOL,
            PromptError::CompletionError(_) | PromptError::MemoryError(_) => ERR_COMPLETION,
        },
        StreamingError::Completion(_) => ERR_COMPLETION,
    };
    anyhow::anyhow!("{code}: {error}")
}

impl AgentHook for ToolObserver {
    fn on_tool_call(
        &self,
        _ctx: &HookContext,
        event: HookToolCall<'_>,
    ) -> impl Future<Output = ToolCallAction> + WasmCompatSend {
        let call_id = event.internal_call_id.to_string();
        let name = event.tool_name.to_string();
        let args = event.args.to_string();
        let alive = (self.emit)(RigStreamEvent::ToolStarted {
            call_id: call_id.clone(),
            name: name.clone(),
            args_json: args.clone(),
        });
        let gate = self.gate.clone();
        async move {
            if !alive {
                return ToolCallAction::Stop("client unsubscribed".into());
            }
            let verdict = gate(call_id, name, args).await;
            if verdict == GATE_RUN {
                return ToolCallAction::Run;
            }
            let reason = verdict.strip_prefix(GATE_SKIP_PREFIX).unwrap_or(&verdict);
            ToolCallAction::Skip(reason.to_string())
        }
    }

    fn on_invalid_tool_call(
        &self,
        ctx: &HookContext,
        event: &InvalidToolCallContext,
    ) -> impl Future<Output = Option<InvalidToolCallAction>> + WasmCompatSend {
        let repaired = repair_tool_name(&event.tool_name, &event.allowed_tools);
        let feedback = format!(
            "Unknown tool `{}`. Available tools: {}.",
            event.tool_name,
            event.allowed_tools.join(", ")
        );
        if repaired.is_none() {
            (self.emit)(RigStreamEvent::TurnDiscarded {
                turn: ctx.turn() as u32,
            });
        }
        async move {
            match repaired {
                Some(name) => Some(InvalidToolCallAction::repair(name)),
                None => Some(InvalidToolCallAction::retry(feedback)),
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

fn finish(builder: AgentBuilder, tools: Vec<DynamicTool>, emit: &EmitFn, gate: &ToolGate) -> Agent {
    builder
        .add_hook(ToolObserver {
            emit: emit.clone(),
            gate: gate.clone(),
        })
        .dynamic_tools(tools)
        .build()
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
    if m.role == "system" {
        return Message::System { content: m.content };
    }
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

fn openai_completions_reasoning_params(config: &RigProviderConfig) -> Option<serde_json::Value> {
    match config.reasoning_mode.as_str() {
        REASONING_EFFORT if !config.reasoning_effort.is_empty() => {
            Some(serde_json::json!({ "reasoning_effort": config.reasoning_effort }))
        }
        _ => None,
    }
}

fn openai_responses_reasoning_params(config: &RigProviderConfig) -> Option<serde_json::Value> {
    match config.reasoning_mode.as_str() {
        REASONING_EFFORT if !config.reasoning_effort.is_empty() => Some(serde_json::json!({
            "reasoning": { "effort": config.reasoning_effort, "summary": "auto" },
        })),
        _ => None,
    }
}

fn clamp_thinking_budget(requested: u32, max_tokens: u32) -> u32 {
    let ceiling = max_tokens.saturating_sub(1).max(1024);
    requested.clamp(1024, ceiling)
}

pub async fn rig_chat_stream(
    emit: EmitFn,
    input: RigChatInput,
    dispatch: ToolDispatch,
    gate: ToolGate,
) -> Result<()> {
    let RigChatInput {
        config,
        system_prompt,
        history,
        tools,
        max_turns,
    } = input;
    let boxed_tools = build_tools(tools, &dispatch);
    let (prompt, prior) = split_history(history)?;
    let http_client = crate::http::client::shared()?;

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
                finish(ab, boxed_tools, &emit, &gate),
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
                finish(ab, boxed_tools, &emit, &gate),
                prompt,
                prior,
                &emit,
                max_turns,
            )
            .await
        }
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
                finish(ab, boxed_tools, &emit, &gate),
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
    let mut stream = agent
        .stream_chat(prompt, history)
        .max_turns(max_turns as usize)
        .max_invalid_tool_call_retries(1)
        .await;

    while let Some(item) = stream.next().await {
        match item {
            Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::Text(text))) => {
                if !emit(RigStreamEvent::TextDelta(text.text)) {
                    break;
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
            Ok(MultiTurnStreamItem::CompletionCall(call)) => {
                let usage = &call.usage;
                let alive = emit(RigStreamEvent::Turn {
                    turn: call.call_index as u32 + 1,
                    finish_reason: finish_reason_str(call.finish_reason.as_ref()),
                    response_id: call.response_id.clone().unwrap_or_default(),
                    provider_request_id: call.provider_request_id.clone().unwrap_or_default(),
                    input_tokens: usage.input_tokens as u32,
                    output_tokens: usage.output_tokens as u32,
                    cached_input_tokens: usage.cached_input_tokens as u32,
                });
                if !alive {
                    break;
                }
            }
            Ok(MultiTurnStreamItem::ModelTurnRetried { turn }) => {
                if !emit(RigStreamEvent::TurnDiscarded { turn: turn as u32 }) {
                    break;
                }
            }
            Ok(MultiTurnStreamItem::FinalResponse(final_resp)) => {
                let usage = final_resp.usage();
                let _ = emit(RigStreamEvent::Usage {
                    input_tokens: usage.input_tokens as u32,
                    output_tokens: usage.output_tokens as u32,
                    cached_input_tokens: usage.cached_input_tokens as u32,
                    cache_write_tokens: usage.cache_creation_input_tokens as u32,
                });
                break;
            }
            Ok(_) => {}
            Err(e) => return Err(classify(e)),
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
    fn repair_strips_namespace_and_case_but_needs_one_match() {
        let tools = vec!["searchDiaries".to_string(), "getDiary".to_string()];
        assert_eq!(
            repair_tool_name("default_api.searchdiaries", &tools).as_deref(),
            Some("searchDiaries")
        );
        assert_eq!(
            repair_tool_name("functions:getDiary", &tools).as_deref(),
            Some("getDiary")
        );
        assert_eq!(repair_tool_name("searchDiaries", &tools), None);
        assert_eq!(repair_tool_name("deleteEverything", &tools), None);
    }

    #[test]
    fn openai_completions_uses_flat_reasoning_effort() {
        let params =
            openai_completions_reasoning_params(&config(REASONING_EFFORT, "low", 0)).unwrap();
        assert_eq!(params["reasoning_effort"], "low");
    }
}
