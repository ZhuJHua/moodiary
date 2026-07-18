import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'memory_entry.freezed.dart';
part 'memory_entry.g.dart';

/// 助手对用户的一条长期记忆（结构化，非向量）。
///
/// 仅设备本地：不进备份、不进同步。[createdAt] / [updatedAt] 为 UTC 绝对时刻。
@freezed
@Collection(ignore: {'copyWith'}, accessor: 'memories')
abstract class MemoryEntry with _$MemoryEntry {
  const factory MemoryEntry({
    @Id() required String id,

    /// 记忆类别：`preference`（偏好）| `theme`（反复出现的主题）| `goal`（目标）| `fact`（事实）。
    required String category,

    required String text,

    required DateTime createdAt,

    required DateTime updatedAt,
  }) = _MemoryEntry;

  factory MemoryEntry.create({
    required String category,
    required String text,
  }) {
    final now = DateTime.timestamp();
    return MemoryEntry(
      id: uuidV7(),
      category: category,
      text: text,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MemoryEntry.fromJson(Map<String, dynamic> json) =>
      _$MemoryEntryFromJson(json);
}
