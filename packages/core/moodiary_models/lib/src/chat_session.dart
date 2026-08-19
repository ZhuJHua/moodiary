import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'chat_session.freezed.dart';
part 'chat_session.g.dart';

/// 一次 AI 助手会话（持久化），消息体存于 [ChatMessage]。API Key 不存这里。
@freezed
@Collection(ignore: {'copyWith'})
abstract class ChatSession with _$ChatSession {
  const factory ChatSession({
    @Id() required String id,

    /// 空串 = 还没生成过标题，界面显示「新对话」。**不存本地化后的文案**：那会把
    /// 生成当时的语种烤进库里，换语言后老会话仍是旧语种。
    ///
    /// 也正是这一位在做幂等：空才生成，生成成功就永远非空。标题在列表里是定位锚点，
    /// 自己变了会让人以为点错了会话；失败也不重来——没有手动刷新入口，重来只是白烧。
    @Default('') String title,

    /// 本会话当前的 [LlmProvider.id]（uuid，不是 [LlmProvider.presetId]）。
    ///
    /// 与 [model] / [reasoningEffort] 一样：首条消息时钉入，发请求优先读它们；
    /// 会话中可随时改（标题的模型 chip），供应商被删则回落全局默认。
    required String providerId,

    required String model,

    required DateTime createdAt,

    /// 最后一条消息的时间，列表按此倒序。
    required DateTime updatedAt,

    /// 本会话的思考强度。空串 = 关；否则是 models.dev `reasoning_options` 里的档位值
    /// （`minimal` / `low` / `medium` / `high` / `xhigh` / `max` …）。
    /// 新建时取自全局默认 assistantReasoningEffort。
    @Default('') String reasoningEffort,

    /// 上下文压缩：滚动摘要（覆盖至 [compactedUpToMessageId] 为止）；null 表示未压缩，整段历史逐字发送。
    String? compactedSummary,

    /// 压缩水位：摘要覆盖到的最后一条消息 id；发送历史时此消息及之前内容改用摘要，Isar 消息永不删除，故可逆。
    String? compactedUpToMessageId,

    /// 最近一次压缩的时刻。
    DateTime? compactedAt,

    /// 触发压缩时该轮上报的输入 token 数（用于提示 / 调试）。
    int? compactedInputTokensAtTrigger,

    /// 会话创建时选定的助手预设 id；null = 内置「Moodiary助手」。只作显示标签解析，
    /// 人格从不按 id 回读——用 [personaSnapshot]。
    String? agentPresetId,

    /// 创建时快照的人格文本（dsh "mounted once"）：会话的 system prompt 从此字节稳定，
    /// 预设事后编辑/删除不影响已有会话。null（旧行）回落内置人格。
    String? personaSnapshot,

    /// 创建时快照的工具 id 子集（同 [personaSnapshot] 的定格语义）。
    /// null = 不限（全部）；空列表 = 本会话不挂工具。
    List<String>? toolsSnapshot,
  }) = _ChatSession;

  factory ChatSession.create({
    required String providerId,
    required String model,
    String reasoningEffort = '',
    String? agentPresetId,
    String? personaSnapshot,
    List<String>? toolsSnapshot,
  }) {
    final now = DateTime.timestamp();
    return ChatSession(
      id: uuidV7(),
      providerId: providerId,
      model: model,
      createdAt: now,
      updatedAt: now,
      reasoningEffort: reasoningEffort,
      agentPresetId: agentPresetId,
      personaSnapshot: personaSnapshot,
      toolsSnapshot: toolsSnapshot,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}
