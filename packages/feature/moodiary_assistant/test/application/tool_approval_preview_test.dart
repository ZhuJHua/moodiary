import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/tool_approval.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/presentation/tool_approval_preview.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

void main() {
  late MoodiaryDatabase db;

  setUp(() async {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    final diaries = DiaryRepository(db);
    final categories = CategoryRepository(db);
    getIt.registerSingleton<DiaryRepository>(diaries);
    getIt.registerSingleton<CategoryRepository>(categories);
    await DiaryWrites(
      diaries: diaries,
      categories: categories,
    ).create(title: 'Original', content: 'Original body');
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
