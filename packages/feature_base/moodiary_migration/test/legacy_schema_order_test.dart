import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_migration/src/legacy/legacy_models.dart' as legacy;

void main() {
  group('legacy schemas 的位置是数据契约（2.8.0 前的旧库）', () {
    test('顺序与长度永久冻结（legacy 不再演进）', () {
      final expected = [
        legacy.DiarySchema,
        legacy.CategorySchema,
        legacy.FontSchema,
        legacy.SearchPostingSchema,
        legacy.SearchStatsSchema,
        legacy.LinkPostingSchema,
        legacy.DiaryIndexSnapshotSchema,
        legacy.ReindexQueueSchema,
        legacy.SyncTombstoneSchema,
        legacy.LlmProviderSchema,
        legacy.ChatSessionSchema,
        legacy.ChatMessageSchema,
        legacy.MemoryEntrySchema,
        legacy.MediaInfoSchema,
        legacy.AgentPresetSchema,
      ];

      expect(
        legacy.moodiarySchemas.length,
        expected.length,
        reason: 'legacy schema 列表已冻结：旧库不会再长出新表，任何增删都是错误。',
      );
      for (var i = 0; i < expected.length; i++) {
        expect(
          identical(legacy.moodiarySchemas[i], expected[i]),
          isTrue,
          reason: '第 $i 位的 schema 变了。位置就是 collection 地址，旧库会被静默错位解读。',
        );
      }
    });

    test('重挂载用的子集必须是严格前缀', () {
      final slices = {
        'diaryAndCategorySchemas': legacy.diaryAndCategorySchemas,
        'legacyMigrationSchemas': legacy.legacyMigrationSchemas,
      };
      for (final MapEntry(key: name, value: slice) in slices.entries) {
        expect(
          slice.length,
          lessThanOrEqualTo(legacy.moodiarySchemas.length),
          reason: '$name 比真源还长。',
        );
        for (var i = 0; i < slice.length; i++) {
          expect(
            identical(slice[i], legacy.moodiarySchemas[i]),
            isTrue,
            reason: '$name 第 $i 位不再等于 moodiarySchemas，重挂载会对错下标。',
          );
        }
      }
    });
  });
}
