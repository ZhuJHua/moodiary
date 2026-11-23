import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/tool_approval.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/tool_approval_preview.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_tools/moodiary_tools.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  late MoodiaryDatabase db;
  final originalTime = DateTime(2026, 11, 12, 23, 45, 15);

  setUp(() async {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    final diaries = DiaryRepository(db);
    final categories = CategoryRepository(db);
    getIt.registerSingleton<DiaryRepository>(diaries);
    getIt.registerSingleton<CategoryRepository>(categories);
    await DiaryWrites(
      tags: TagRepository(db),
      diaries: diaries,
      categories: categories,
    ).create(title: 'Original', content: 'Original body', time: originalTime);
  });
  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<ToolApprovalPreview> preview(List<Map<String, dynamic>> items) =>
      buildToolApprovalPreview(
        ToolApprovalRequest(
          callId: 'update',
          tool: AssistantTool.updateDiary,
          args: {'items': items},
          tier: assistantToolTier(AssistantTool.updateDiary, {'items': items}),
        ),
        l10n,
      );

  test('create preview resolves each chosen local date and time with a fixed clock', () async {
    final now = DateTime(2026, 11, 17, 14, 5);
    final result = await buildToolApprovalPreview(
      const ToolApprovalRequest(
        callId: 'create',
        tool: AssistantTool.createDiary,
        args: {
          'items': [
            {'content': 'Past diary', 'time': '2026-11-10'},
            {'content': 'Now'},
            {'content': 'Offset', 'time': '2026-11-10T21:30Z'},
          ],
        },
        tier: .write,
      ),
      l10n,
      now: () => now,
    );
    expect(
      result.lines
          .where((line) => line.label == l10n.assistant.approvalFieldTime)
          .map((line) => line.value),
      [
        TimeFormat.listDateTime(DateTime(2026, 11, 10, 14, 5)),
        TimeFormat.listDateTime(now),
        TimeFormat.listDateTime(DateTime.utc(2026, 11, 10, 21, 30)),
      ],
    );
  });

  test('single and batch previews show old to new time preserving the hour', () async {
    final diary = (await getIt<DiaryRepository>().getAllDiaries()).single;
    final change = {'id': diary.id, 'time': '2026-11-10'};
    final expected =
        '${TimeFormat.listDateTime(originalTime)} → ${TimeFormat.listDateTime(DateTime(2026, 11, 10, 23, 45, 15))}';
    for (final items in [
      [change],
      [
        change,
        {'id': 'other', 'append': 'Addition'},
      ],
    ]) {
      final result = await preview(items);
      expect(
        result.lines,
        contains((label: l10n.assistant.approvalFieldTime, value: expected)),
      );
    }
  });

  test('null time is unchanged and has no time change preview', () async {
    final diary = (await getIt<DiaryRepository>().getAllDiaries()).single;
    final result = await preview([
      {'id': diary.id, 'time': null, 'title': 'New'},
    ]);
    expect(
      result.lines.any(
        (line) => line.label == l10n.assistant.approvalFieldTime,
      ),
      false,
    );
  });

  test(
    'single diary preview shows additions without an overwrite warning',
    () async {
      final diary = (await getIt<DiaryRepository>().getAllDiaries()).single;
      final result = await preview([
        {
          'id': diary.id,
          'prepend': '# Introduction',
          'append': 'English translation',
        },
      ]);
      expect(result.subtitle, contains('Original'));
      expect(result.lines, [
        (label: l10n.assistant.approvalFieldPrepend, value: '# Introduction'),
        (
          label: l10n.assistant.approvalFieldAppend,
          value: 'English translation',
        ),
      ]);
      expect(result.warning, isNull);
      expect(result.confirmLabel, l10n.assistant.approvalConfirmUpdate);
    },
  );

  test(
    'batch preview shows additions and warns when any item rewrites',
    () async {
      final diary = (await getIt<DiaryRepository>().getAllDiaries()).single;
      final additions = [
        {'id': diary.id, 'append': 'Translation'},
        {'id': 'other', 'prepend': 'Introduction'},
      ];
      final result = await preview(additions);
      expect(
        result.lines.map((line) => line.value),
        containsAll(['Translation', 'Introduction']),
      );
      expect(result.warning, isNull);
      expect(
        result.confirmLabel,
        l10n.assistant.approvalConfirmUpdateCount(count: 2),
      );
      final rewritten = await preview([
        ...additions,
        {'id': 'rewrite', 'content': 'Replacement'},
      ]);
      expect(rewritten.warning, l10n.assistant.approvalOverwriteWarning);
      expect(rewritten.confirmLabel, l10n.assistant.approvalOverwrite);
    },
  );
}
