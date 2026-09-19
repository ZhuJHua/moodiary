import 'dart:convert';

import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

({IconData icon, String title, String description}) assistantToolDisplay(
  BuildContext context,
  AssistantTool tool,
) {
  final l10n = context.l10n;
  return switch (tool) {
    .runJavascript => (
      icon: LucideIcons.squareTerminal,
      title: l10n.assistant.toolJsTitle,
      description: l10n.assistant.toolJsDes,
    ),
    .searchDiaries => (
      icon: LucideIcons.textSearch,
      title: l10n.assistant.toolSearchTitle,
      description: l10n.assistant.toolSearchDes,
    ),
    .getDiary => (
      icon: LucideIcons.fileText,
      title: l10n.assistant.toolGetTitle,
      description: l10n.assistant.toolGetDes,
    ),
    .diaryOverview => (
      icon: LucideIcons.chartNoAxesCombined,
      title: l10n.assistant.toolOverviewTitle,
      description: l10n.assistant.toolOverviewDes,
    ),
    .createDiary => (
      icon: LucideIcons.filePlus,
      title: l10n.assistant.toolCreateTitle,
      description: l10n.assistant.toolCreateDes,
    ),
    .updateDiary => (
      icon: LucideIcons.filePenLine,
      title: l10n.assistant.toolUpdateTitle,
      description: l10n.assistant.toolUpdateDes,
    ),
    .deleteDiary => (
      icon: LucideIcons.trash2,
      title: l10n.assistant.toolDeleteTitle,
      description: l10n.assistant.toolDeleteDes,
    ),
    .listCategories => (
      icon: LucideIcons.folderOpen,
      title: l10n.assistant.toolListCategoriesTitle,
      description: l10n.assistant.toolListCategoriesDes,
    ),
    .createCategory => (
      icon: LucideIcons.folderPlus,
      title: l10n.assistant.toolCreateCategoryTitle,
      description: l10n.assistant.toolCreateCategoryDes,
    ),
    .updateCategory => (
      icon: LucideIcons.folderPen,
      title: l10n.assistant.toolUpdateCategoryTitle,
      description: l10n.assistant.toolUpdateCategoryDes,
    ),
    .deleteCategory => (
      icon: LucideIcons.folderX,
      title: l10n.assistant.toolDeleteCategoryTitle,
      description: l10n.assistant.toolDeleteCategoryDes,
    ),
    .recallMemory => (
      icon: LucideIcons.brain,
      title: l10n.assistant.toolRecallMemoryTitle,
      description: l10n.assistant.toolRecallMemoryDes,
    ),
    .rememberFact => (
      icon: LucideIcons.bookmarkPlus,
      title: l10n.assistant.toolRememberTitle,
      description: l10n.assistant.toolRememberDes,
    ),
    .forgetFact => (
      icon: LucideIcons.eraser,
      title: l10n.assistant.toolForgetTitle,
      description: l10n.assistant.toolForgetDes,
    ),
  };
}

class AssistantToolDetail extends StatelessWidget {
  final Map<String, dynamic> args;
  final String result;

  const AssistantToolDetail({
    super.key,
    required this.args,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final label = typography.labelSmall.onSurfaceVariant.copyWith(
      color: context.theme.colors.onSurfaceVariant.withValues(alpha: 0.7),
    );
    final body = typography.bodySmall.onSurfaceVariant;
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        if (args.isNotEmpty) ...[
          Text(l10n.assistant.toolArgs, style: label),
          const SizedBox(height: 2),
          Text(formatToolArgs(args), style: body),
        ],
        if (args.isNotEmpty && result.isNotEmpty) const SizedBox(height: 8),
        if (result.isNotEmpty) ...[
          Text(l10n.assistant.toolResult, style: label),
          const SizedBox(height: 2),
          Text(result, style: body),
        ],
      ],
    );
  }
}

String formatToolArgs(Map<String, dynamic> args) {
  const encoder = JsonEncoder.withIndent('  ');
  return [
    for (final MapEntry(:key, :value) in args.entries)
      switch (value) {
        String() => '$key: $value',
        num() || bool() => '$key: $value',
        null => '$key: null',
        _ => '$key: ${encoder.convert(value)}',
      },
  ].join('\n');
}
