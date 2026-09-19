import 'package:moodiary_assistant/src/application/tool_approval.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

const int _kPreviewRows = 3;

typedef ToolApprovalLine = ({String label, String value});

class ToolApprovalPreview {
  final String subtitle;
  final List<ToolApprovalLine> lines;
  final String? warning;
  final String confirmLabel;

  const ToolApprovalPreview({
    required this.subtitle,
    required this.lines,
    required this.confirmLabel,
    this.warning,
  });
}

Future<ToolApprovalPreview> buildToolApprovalPreview(
  ToolApprovalRequest request,
  Translations l10n,
) {
  final items = assistantToolItems(request.args);
  final ids = assistantToolIds(request.args);
  return switch (request.tool) {
    .createDiary => _createDiary(l10n, items),
    .updateDiary => _updateDiary(l10n, items),
    .deleteDiary => _diaries(
      l10n,
      ids,
      confirmLabel: l10n.assistant.approvalConfirmTrash,
    ),
    .createCategory => Future.value(
      ToolApprovalPreview(
        subtitle: l10n.assistant.approvalItemCount(count: items.length),
        lines: [
          for (final item in items.take(_kPreviewRows))
            (
              label: l10n.assistant.approvalFieldName,
              value: _str(item['name']),
            ),
        ],
        confirmLabel: l10n.assistant.approvalConfirmCreate,
      ),
    ),
    .updateCategory => _updateCategory(l10n, items),
    .deleteCategory => _categories(l10n, ids),
    .rememberFact => Future.value(
      ToolApprovalPreview(
        subtitle: l10n.assistant.approvalItemCount(count: items.length),
        lines: [
          for (final item in items.take(_kPreviewRows))
            (label: '', value: _str(item['text'])),
        ],
        confirmLabel: l10n.assistant.approvalConfirmRemember,
      ),
    ),
    .forgetFact => _facts(l10n, ids),
    _ => Future.value(
      ToolApprovalPreview(
        subtitle: '',
        lines: const [],
        confirmLabel: l10n.common.ok,
      ),
    ),
  };
}

String _str(Object? v) => v?.toString().trim() ?? '';

int _chars(String text) => text.replaceAll(RegExp(r'\s+'), '').length;

String _diaryLabel(Diary diary, Translations l10n) =>
    '${TimeFormat.monthDay(diary.time)} · '
    '${diary.title.trim().isEmpty ? l10n.common.untitled : diary.title.trim()}';

Future<ToolApprovalPreview> _createDiary(
  Translations l10n,
  List<Map<String, dynamic>> items,
) async {
  return ToolApprovalPreview(
    subtitle: l10n.assistant.approvalDiaryCount(count: items.length),
    lines: [
      for (final item in items.take(_kPreviewRows))
        (
          label: '',
          value:
              '${_str(item['title']).isEmpty ? l10n.common.untitled : _str(item['title'])}'
              ' · ${l10n.assistant.approvalContentNew(count: _chars(_str(item['content'])))}',
        ),
    ],
    confirmLabel: l10n.assistant.approvalConfirmCreate,
  );
}

Future<ToolApprovalPreview> _updateDiary(
  Translations l10n,
  List<Map<String, dynamic>> items,
) async {
  final diaries = getIt<DiaryRepository>();
  final categories = getIt<CategoryRepository>();
  final rewrites = items.any((i) => i['content'] != null);
  if (items.isEmpty) {
    return ToolApprovalPreview(
      subtitle: '',
      lines: const [],
      confirmLabel: l10n.assistant.approvalConfirmUpdate,
    );
  }

  Future<String> categoryName(Object? id) async {
    final key = _str(id);
    if (key.isEmpty) return l10n.assistant.approvalNoCategory;
    return (await categories.getCategoryById(key))?.categoryName ?? key;
  }

  if (items.length == 1) {
    final item = items.single;
    final diary = await diaries.getDiaryByBusinessId(_str(item['id']));
    final lines = <ToolApprovalLine>[];
    if (item['title'] != null) {
      lines.add((
        label: l10n.assistant.approvalFieldTitle,
        value:
            '${diary?.title.trim().isEmpty ?? true ? l10n.common.untitled : diary!.title.trim()}'
            ' → ${_str(item['title'])}',
      ));
    }
    if (item['categoryId'] != null) {
      lines.add((
        label: l10n.assistant.approvalFieldCategory,
        value:
            '${await categoryName(diary?.categoryId)} → '
            '${await categoryName(item['categoryId'])}',
      ));
    }
    if (item['content'] != null) {
      lines.add((
        label: l10n.assistant.approvalFieldContent,
        value: l10n.assistant.approvalContentRewrite(
          from: _chars(diary?.contentText ?? ''),
          to: _chars(_str(item['content'])),
        ),
      ));
    }
    return ToolApprovalPreview(
      subtitle: diary == null ? _str(item['id']) : _diaryLabel(diary, l10n),
      lines: lines,
      warning: rewrites ? l10n.assistant.approvalOverwriteWarning : null,
      confirmLabel: rewrites
          ? l10n.assistant.approvalOverwrite
          : l10n.assistant.approvalConfirmUpdate,
    );
  }

  final sameCategory = items.every(
    (i) =>
        i['categoryId'] != null && i['categoryId'] == items.first['categoryId'],
  );
  final subtitle = [
    l10n.assistant.approvalDiaryCount(count: items.length),
    if (sameCategory)
      l10n.assistant.approvalCategoryTo(
        name: await categoryName(items.first['categoryId']),
      ),
  ].join(' · ');
  final lines = <ToolApprovalLine>[];
  for (final item in items.take(_kPreviewRows)) {
    final diary = await diaries.getDiaryByBusinessId(_str(item['id']));
    lines.add((
      label: '',
      value: diary == null ? _str(item['id']) : _diaryLabel(diary, l10n),
    ));
  }
  if (items.length > _kPreviewRows) {
    lines.add((
      label: '',
      value: l10n.assistant.approvalMore(count: items.length - _kPreviewRows),
    ));
  }
  return ToolApprovalPreview(
    subtitle: subtitle,
    lines: lines,
    warning: rewrites ? l10n.assistant.approvalOverwriteWarning : null,
    confirmLabel: rewrites
        ? l10n.assistant.approvalOverwrite
        : l10n.assistant.approvalConfirmUpdateCount(count: items.length),
  );
}

Future<ToolApprovalPreview> _diaries(
  Translations l10n,
  List<String> ids, {
  required String confirmLabel,
}) async {
  final repo = getIt<DiaryRepository>();
  final lines = <ToolApprovalLine>[];
  for (final id in ids.take(_kPreviewRows)) {
    final diary = await repo.getDiaryByBusinessId(id);
    lines.add((
      label: '',
      value: diary == null ? id : _diaryLabel(diary, l10n),
    ));
  }
  if (ids.length > _kPreviewRows) {
    lines.add((
      label: '',
      value: l10n.assistant.approvalMore(count: ids.length - _kPreviewRows),
    ));
  }
  return ToolApprovalPreview(
    subtitle: l10n.assistant.approvalDiaryCount(count: ids.length),
    lines: lines,
    confirmLabel: confirmLabel,
  );
}

Future<ToolApprovalPreview> _updateCategory(
  Translations l10n,
  List<Map<String, dynamic>> items,
) async {
  final repo = getIt<CategoryRepository>();
  final lines = <ToolApprovalLine>[];
  for (final item in items.take(_kPreviewRows)) {
    final current = await repo.getCategoryById(_str(item['id']));
    lines.add((
      label: l10n.assistant.approvalFieldName,
      value:
          '${current?.categoryName ?? _str(item['id'])} → ${_str(item['name'])}',
    ));
  }
  return ToolApprovalPreview(
    subtitle: l10n.assistant.approvalItemCount(count: items.length),
    lines: lines,
    confirmLabel: items.length == 1
        ? l10n.assistant.approvalConfirmUpdate
        : l10n.assistant.approvalConfirmUpdateCount(count: items.length),
  );
}

Future<ToolApprovalPreview> _categories(
  Translations l10n,
  List<String> ids,
) async {
  final repo = getIt<CategoryRepository>();
  final lines = <ToolApprovalLine>[];
  for (final id in ids.take(_kPreviewRows)) {
    final category = await repo.getCategoryById(id);
    lines.add((label: '', value: category?.categoryName ?? id));
  }
  return ToolApprovalPreview(
    subtitle: l10n.assistant.approvalItemCount(count: ids.length),
    lines: lines,
    warning: l10n.assistant.approvalIrreversible,
    confirmLabel: l10n.assistant.approvalConfirmDelete,
  );
}

Future<ToolApprovalPreview> _facts(Translations l10n, List<String> ids) async {
  final repo = getIt<MemoryRepository>();
  final lines = <ToolApprovalLine>[];
  for (final id in ids.take(_kPreviewRows)) {
    final fact = await repo.get(id);
    lines.add((label: '', value: fact == null ? id : '「${fact.text}」'));
  }
  return ToolApprovalPreview(
    subtitle: l10n.assistant.approvalItemCount(count: ids.length),
    lines: lines,
    warning: l10n.assistant.approvalIrreversible,
    confirmLabel: l10n.assistant.approvalConfirmDelete,
  );
}
