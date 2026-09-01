import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show uuidV7;

/// 磁盘上区分两种角色的**只有这两个字面量**（[ChatMessage.role]）。
///
/// 别换成枚举的 `.name`、别改大小写：历史行会全部读回成 assistant，
/// 整段对话左对齐，而「重新回答」找不到最后一条用户消息、静默什么都不做。
const String kRoleUser = 'user';
const String kRoleAssistant = 'assistant';

/// 聊天列表里的一项。只有 [AssistantTurn] 落库，另外两种是由会话状态合成的卡片。
sealed class AssistantChatItem {
  const AssistantChatItem();

  String get id;
}

/// 一轮文本消息。取代了旧的 `TextMessage` + 那张 8 键的 `metadata` map。
final class AssistantTurn extends AssistantChatItem {
  @override
  final String id;

  final bool fromUser;
  final String text;
  final DateTime createdAt;

  /// image 目录内的文件名，空串表示无图。
  final String imageName;

  /// 思考正文（Markdown），空串表示没有思考过程。
  final String reasoning;
  final int thinkingMillis;

  final int inputTokens;
  final int outputTokens;

  /// 本轮的工具调用，按发生顺序。空表示这一轮没调工具。
  final List<AssistantToolCall> toolCalls;

  /// 生成本条回复的模型 id；空串 = 旧数据或 user 消息。创建时定死，不随 copyWith 变。
  final String model;

  /// 瞬态：正在流式接收。不落库。
  final bool streaming;

  /// 瞬态：仍在思考阶段（首个正文 token 之前）。不落库。
  final bool thinkingActive;

  const AssistantTurn({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.createdAt,
    this.imageName = '',
    this.reasoning = '',
    this.thinkingMillis = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.toolCalls = const [],
    this.model = '',
    this.streaming = false,
    this.thinkingActive = false,
  });

  factory AssistantTurn.user(
    String text, {
    String imageName = '',
    DateTime? createdAt,
  }) => AssistantTurn(
    id: uuidV7(),
    fromUser: true,
    text: text,
    imageName: imageName,
    createdAt: createdAt ?? DateTime.timestamp(),
  );

  factory AssistantTurn.assistant(
    String text, {
    bool streaming = false,
    DateTime? createdAt,
    String model = '',
  }) => AssistantTurn(
    id: uuidV7(),
    fromUser: false,
    text: text,
    streaming: streaming,
    createdAt: createdAt ?? DateTime.timestamp(),
    model: model,
  );

  factory AssistantTurn.fromRecord(ChatMessage m) => AssistantTurn(
    id: m.id,
    fromUser: m.role == kRoleUser,
    text: m.content,
    createdAt: m.createdAt,
    imageName: m.imageName ?? '',
    reasoning: m.reasoning ?? '',
    thinkingMillis: m.thinkingMillis ?? 0,
    inputTokens: m.inputTokens ?? 0,
    outputTokens: m.outputTokens ?? 0,
    toolCalls: m.toolCalls,
    model: m.model ?? '',
  );

  ChatMessage toRecord(String sessionId) => ChatMessage(
    id: id,
    sessionId: sessionId,
    role: fromUser ? kRoleUser : kRoleAssistant,
    content: text,
    createdAt: createdAt,
    // 空值一律写回 null，与旧的 metadata 剥离规则逐字段等价。
    reasoning: reasoning.isEmpty ? null : reasoning,
    thinkingMillis: thinkingMillis == 0 ? null : thinkingMillis,
    imageName: imageName.isEmpty ? null : imageName,
    inputTokens: inputTokens == 0 ? null : inputTokens,
    outputTokens: outputTokens == 0 ? null : outputTokens,
    toolCalls: toolCalls,
    model: model.isEmpty ? null : model,
  );

  /// 正文、图片、工具调用都没有 —— 这样的气泡不落库，也不进发给模型的历史。
  ///
  /// **工具调用要算进来**：一轮「查了日记但没说话」也是发生过的事，丢掉的话
  /// 历史里就只剩用户那句问话，看着像助手没反应。
  bool get isEmpty => text.isEmpty && imageName.isEmpty && toolCalls.isEmpty;

  /// 定稿：只清两个瞬态标记，思考正文 / 耗时 / 用量全部留下。
  ///
  /// 旧的 `settled()` 是重建整张 metadata，顺手把 `imageName` 丢了 —— 当时无害
  /// （只对 assistant 回复调用，那边从不带图），换成 copyWith 之后这个坑就没了。
  AssistantTurn get settled =>
      copyWith(streaming: false, thinkingActive: false);

  AssistantTurn copyWith({
    String? text,
    String? reasoning,
    int? thinkingMillis,
    int? inputTokens,
    int? outputTokens,
    List<AssistantToolCall>? toolCalls,
    bool? streaming,
    bool? thinkingActive,
  }) => AssistantTurn(
    id: id,
    fromUser: fromUser,
    text: text ?? this.text,
    createdAt: createdAt,
    imageName: imageName,
    model: model,
    reasoning: reasoning ?? this.reasoning,
    thinkingMillis: thinkingMillis ?? this.thinkingMillis,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    toolCalls: toolCalls ?? this.toolCalls,
    streaming: streaming ?? this.streaming,
    thinkingActive: thinkingActive ?? this.thinkingActive,
  );
}

/// 上下文压缩提示 chip，不落库 —— 每次载入会话时按水位重新合成。
final class AssistantCompactionNotice extends AssistantChatItem {
  final String watermarkId;

  const AssistantCompactionNotice(this.watermarkId);

  /// **id 由水位派生**，保证重复合成幂等。改了这个前缀，chip 会在每次载入时
  /// 认不出自己而重复堆积，「恢复完整历史」的入口也跟着丢。
  @override
  String get id => 'compaction-$watermarkId';
}

/// 「已切换模型」提示，不落库 —— 由消息的 [AssistantTurn.model] 变化点合成。
/// 只作展示，**不进发给模型的历史**（切换动作不向对话注入任何内容）。
final class AssistantModelSwitchNotice extends AssistantChatItem {
  /// 切换后首条 assistant 消息的 id：提示插在它**之前**，因此永远不会落在列表
  /// 末尾（`_buildTurn` 靠 `items.last` 判定重试按钮的归属，尾随合成项会吃掉它）。
  final String beforeId;

  /// 切换后的模型 id。
  final String model;

  const AssistantModelSwitchNotice({
    required this.beforeId,
    required this.model,
  });

  /// id 由目标消息派生，保证重复合成幂等。
  @override
  String get id => 'model-switch-$beforeId';
}

/// 计算一份消息列表里应存在的全部「已切换模型」提示：相邻两条 assistant 消息的
/// [AssistantTurn.model] 不同（且都非空）时，在后者之前放一条。旧数据（model 为空）
/// 不参与，也不会把它前后的两段误判成切换。
List<AssistantModelSwitchNotice> modelSwitchNoticesFor(
  Iterable<AssistantChatItem> items,
) {
  final notices = <AssistantModelSwitchNotice>[];
  var lastModel = '';
  for (final item in items) {
    if (item is! AssistantTurn || item.fromUser) continue;
    if (item.model.isEmpty) continue;
    if (lastModel.isNotEmpty && item.model != lastModel) {
      notices.add(
        AssistantModelSwitchNotice(beforeId: item.id, model: item.model),
      );
    }
    lastModel = item.model;
  }
  return notices;
}
