import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('moodiarySchemas 的位置是数据契约', () {
    test('顺序与长度都被钉死（只许在末尾追加）', () {
      final expected = [
        DiarySchema,
        CategorySchema,
        FontSchema,
        SearchPostingSchema,
        SearchStatsSchema,
        LinkPostingSchema,
        DiaryIndexSnapshotSchema,
        ReindexQueueSchema,
        SyncTombstoneSchema,
        LlmProviderSchema,
        ChatSessionSchema,
        ChatMessageSchema,
        MemoryEntrySchema,
        MediaInfoSchema,
        AgentPresetSchema,
      ];

      expect(
        moodiarySchemas.length,
        expected.length,
        reason:
            '加了 schema 就把它追加到 moodiarySchemas 末尾，并同步追加到本用例的 expected 末尾；'
            '如果你是在中间插入或重排——停手，那会静默错位已有数据。',
      );
      for (var i = 0; i < expected.length; i++) {
        expect(
          identical(moodiarySchemas[i], expected[i]),
          isTrue,
          reason: '第 $i 位的 schema 变了。位置就是 collection 地址，不能动。',
        );
      }
    });

    test('重挂载用的子集必须是严格前缀', () {
      final slices = {
        'diaryAndCategorySchemas': diaryAndCategorySchemas,
        'legacyMigrationSchemas': legacyMigrationSchemas,
      };
      for (final MapEntry(key: name, value: slice) in slices.entries) {
        expect(
          slice.length,
          lessThanOrEqualTo(moodiarySchemas.length),
          reason: '$name 比真源还长。',
        );
        for (var i = 0; i < slice.length; i++) {
          expect(
            identical(slice[i], moodiarySchemas[i]),
            isTrue,
            reason: '$name 第 $i 位不再等于 moodiarySchemas，重挂载会对错下标。',
          );
        }
      }
    });
  });
}
