//! AI 助手底层 agent（基于 rig）。Rust 侧完全通用、不认识「日记」：工具定义作为数据
//! （[RigToolDef]）从 Dart 传入，工具执行（含权限闸门）由 Dart 回调 [tool_dispatch] 完成。
//! 本模块只构造 provider 客户端、挂载代理工具、跑 rig 多轮流式工具循环，文本增量经
//! [StreamSink] 回传 Flutter。新增 / 修改工具无需动 Rust。

use std::sync::Arc;

use anyhow::Result;
use flutter_rust_bridge::DartFnFuture;
use futures::StreamExt;
use rig::agent::{Agent, MultiTurnStreamItem, PromptHook};
use rig::client::completion::CompletionClient;
use rig::completion::{CompletionModel, GetTokenUsage, Message, ToolDefinition};
use rig::providers::{anthropic, openai};
use rig::streaming::{StreamedAssistantContent, StreamingChat};
use rig::tool::{ToolDyn, ToolError};
use rig::wasm_compat::{WasmBoxedFuture, WasmCompatSend};

use crate::frb_generated::StreamSink;

/// 一次对话的 provider 连接配置。每次调用由 Dart 组装传入，Rust 不持有任何状态。
pub struct RigProviderConfig {
    /// `"openai"`（OpenAI 兼容，走 Chat Completions API）或 `"anthropic"`。
    pub protocol: String,
    pub api_key: String,
    /// 自定义 baseUrl，留空表示该协议官方端点。
    pub base_url: String,
    pub model: String,
    /// 单次回复最大 token 数（Anthropic 协议必传）。
    pub max_tokens: u32,
}

pub struct RigChatMessage {
    /// `"user"` 或 `"assistant"`。
    pub role: String,
    pub content: String,
}

/// 工具定义（数据驱动，对应 Dart 的 `AssistantTool`）。
pub struct RigToolDef {
    /// 模型侧 function name，须与 Dart 工具路由表里的 key 一致。
    pub name: String,
    pub description: String,
    /// 入参 JSON Schema（字符串，须是 `type: object`）。
    pub parameters_json: String,
}

/// 用「plain enum + 载荷字段」而非带数据的枚举变体，是为了让 FRB 生成普通 Dart
/// 类 / 枚举，避开它对 `freezed`（项目当前钉在 pre-release 版）的版本门槛。
pub enum RigEventKind {
    TextDelta,
    ToolCall,
}

pub struct RigStreamEvent {
    pub kind: RigEventKind,
    pub text: String,
}

/// Dart 工具分发回调：入参 `(tool_name, args_json)`，返回工具结果字符串。
/// 权限闸门在 Dart 侧此回调内部完成（被拒时返回一句说明、不执行副作用）。
type ToolDispatch = Arc<dyn Fn(String, String) -> DartFnFuture<String> + Send + Sync>;

/// 把 `call()` 转发给 Dart 的代理工具。直接实现 rig 对象安全的 [ToolDyn]，
/// 使工具名 / 描述 / schema 都可在运行时由数据决定。
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

    fn definition(&self, _prompt: String) -> WasmBoxedFuture<'_, ToolDefinition> {
        let def = ToolDefinition {
            name: self.name.clone(),
            description: self.description.clone(),
            parameters: self.parameters.clone(),
        };
        Box::pin(async move { def })
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

/// 拆出本轮 prompt（历史最后一条，应为用户消息）与之前的对话历史。
fn split_history(history: Vec<RigChatMessage>) -> Result<(Message, Vec<Message>)> {
    if history.is_empty() {
        anyhow::bail!("chat history is empty");
    }
    let mut msgs: Vec<Message> = history
        .into_iter()
        .map(|m| {
            if m.role == "user" {
                Message::user(m.content)
            } else {
                Message::assistant(m.content)
            }
        })
        .collect();
    let prompt = msgs.pop().expect("history checked non-empty");
    Ok((prompt, msgs))
}

/// 流式对话 + 多轮工具调用。Dart 取消订阅会令 `sink.add` 失败，循环随即中断（取消在途
/// 请求）。硬性失败（构造客户端 / 流错误）以 `Err` 形式让 Dart 流报错。
pub async fn rig_chat_stream(
    sink: StreamSink<RigStreamEvent>,
    config: RigProviderConfig,
    system_prompt: String,
    history: Vec<RigChatMessage>,
    tools: Vec<RigToolDef>,
    max_turns: u32,
    tool_dispatch: impl Fn(String, String) -> DartFnFuture<String> + Send + Sync + 'static,
) -> Result<()> {
    let dispatch: ToolDispatch = Arc::new(tool_dispatch);
    let boxed_tools = build_tools(tools, &dispatch);
    let (prompt, prior) = split_history(history)?;
    let http_client = crate::http_client::platform_http_client()?;

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
            let agent = client
                .agent(&config.model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64)
                .tools(boxed_tools)
                .build();
            drive(agent, prompt, prior, &sink, max_turns).await
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
            let agent = client
                .agent(&config.model)
                .preamble(&system_prompt)
                .max_tokens(config.max_tokens as u64)
                .tools(boxed_tools)
                .build();
            drive(agent, prompt, prior, &sink, max_turns).await
        }
    }
}

/// 消费 rig 的多轮流式结果，openai / anthropic 两种 agent 复用同一套逻辑。
async fn drive<M, P>(
    agent: Agent<M, P>,
    prompt: Message,
    history: Vec<Message>,
    sink: &StreamSink<RigStreamEvent>,
    max_turns: u32,
) -> Result<()>
where
    M: CompletionModel + 'static,
    M::StreamingResponse: GetTokenUsage + WasmCompatSend + Clone + Unpin,
    P: PromptHook<M> + 'static,
{
    let mut stream = agent
        .stream_chat(prompt, history)
        .multi_turn(max_turns as usize)
        .await;

    while let Some(item) = stream.next().await {
        match item {
            Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::Text(text))) => {
                let event = RigStreamEvent {
                    kind: RigEventKind::TextDelta,
                    text: text.text,
                };
                if sink.add(event).is_err() {
                    break; // Dart 已取消订阅 → 中断在途请求
                }
            }
            Ok(MultiTurnStreamItem::StreamAssistantItem(StreamedAssistantContent::ToolCall {
                tool_call,
                ..
            })) => {
                if sink
                    .add(RigStreamEvent {
                        kind: RigEventKind::ToolCall,
                        text: tool_call.function.name,
                    })
                    .is_err()
                {
                    break;
                }
            }
            Ok(MultiTurnStreamItem::FinalResponse(_)) => break,
            Ok(_) => {} // reasoning 增量 / 工具结果 / usage 等当前不透传
            Err(e) => return Err(anyhow::anyhow!("rig stream error: {e}")),
        }
    }
    Ok(())
}
