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

    required String title,

    /// 建会话时生效的 [LlmProvider.id]（uuid，不是 [LlmProvider.presetId]）。
    ///
    /// ⚠️ 这两个字段目前**只写不读**：每一轮请求取的都是 `getActiveProvider()`，
    /// 所以在设置里换了供应商，已存在的会话下一轮就跟着换模型。要做「会话级模型」
    /// 得先让发请求那条路优先读它们。
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

    /// [title] 是否已由模型总结过。false = 还是「第一条消息截断」那个兜底。
    ///
    /// 生成只发生一次：标题在历史列表里是定位锚点，自己变了会让人以为点错了会话。
    /// 自动失败也不重排——没有手动刷新入口，重排只会反复烧 token。
    @Default(false) bool titleFromModel,
  }) = _ChatSession;

  factory ChatSession.create({
    required String title,
    required String providerId,
    required String model,
    String reasoningEffort = '',
  }) {
    final now = DateTime.timestamp();
    return ChatSession(
      id: uuidV7(),
      title: title,
      providerId: providerId,
      model: model,
      createdAt: now,
      updatedAt: now,
      reasoningEffort: reasoningEffort,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}
