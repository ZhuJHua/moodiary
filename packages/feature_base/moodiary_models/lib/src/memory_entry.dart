import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

part 'memory_entry.freezed.dart';
part 'memory_entry.g.dart';

@freezed
abstract class MemoryEntry with _$MemoryEntry {
  const factory MemoryEntry({
    required String id,

    required String category,

    required String text,

    required DateTime createdAt,

    required DateTime updatedAt,
  }) = _MemoryEntry;

  factory MemoryEntry.create({required String category, required String text}) {
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
