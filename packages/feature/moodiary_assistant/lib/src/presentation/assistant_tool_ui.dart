import 'package:flutter/material.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

({IconData icon, String title, String description}) assistantToolDisplay(
  BuildContext context,
  AssistantTool tool,
) {
  final l10n = context.l10n;
  return switch (tool) {
    AssistantTool.queryDiaries => (
      icon: Icons.manage_search_rounded,
      title: l10n.assistantToolQueryTitle,
      description: l10n.assistantToolQueryDes,
    ),
    AssistantTool.getDiary => (
      icon: Icons.article_outlined,
      title: l10n.assistantToolGetTitle,
      description: l10n.assistantToolGetDes,
    ),
    AssistantTool.diaryOverview => (
      icon: Icons.insights_rounded,
      title: l10n.assistantToolOverviewTitle,
      description: l10n.assistantToolOverviewDes,
    ),
    AssistantTool.createDiary => (
      icon: Icons.note_add_rounded,
      title: l10n.assistantToolCreateTitle,
      description: l10n.assistantToolCreateDes,
    ),
    AssistantTool.updateDiary => (
      icon: Icons.edit_note_rounded,
      title: l10n.assistantToolUpdateTitle,
      description: l10n.assistantToolUpdateDes,
    ),
    AssistantTool.deleteDiary => (
      icon: Icons.delete_outline_rounded,
      title: l10n.assistantToolDeleteTitle,
      description: l10n.assistantToolDeleteDes,
    ),
    AssistantTool.listCategories => (
      icon: Icons.folder_open_rounded,
      title: l10n.assistantToolListCategoriesTitle,
      description: l10n.assistantToolListCategoriesDes,
    ),
    AssistantTool.createCategory => (
      icon: Icons.create_new_folder_rounded,
      title: l10n.assistantToolCreateCategoryTitle,
      description: l10n.assistantToolCreateCategoryDes,
    ),
    AssistantTool.updateCategory => (
      icon: Icons.drive_file_rename_outline_rounded,
      title: l10n.assistantToolUpdateCategoryTitle,
      description: l10n.assistantToolUpdateCategoryDes,
    ),
    AssistantTool.deleteCategory => (
      icon: Icons.folder_delete_rounded,
      title: l10n.assistantToolDeleteCategoryTitle,
      description: l10n.assistantToolDeleteCategoryDes,
    ),
    AssistantTool.listMemories => (
      icon: Icons.psychology_outlined,
      title: l10n.assistantToolListMemoriesTitle,
      description: l10n.assistantToolListMemoriesDes,
    ),
    AssistantTool.rememberFact => (
      icon: Icons.bookmark_add_outlined,
      title: l10n.assistantToolRememberTitle,
      description: l10n.assistantToolRememberDes,
    ),
    AssistantTool.updateMemory => (
      icon: Icons.edit_note_outlined,
      title: l10n.assistantToolUpdateMemoryTitle,
      description: l10n.assistantToolUpdateMemoryDes,
    ),
    AssistantTool.forgetFact => (
      icon: Icons.delete_sweep_outlined,
      title: l10n.assistantToolForgetTitle,
      description: l10n.assistantToolForgetDes,
    ),
  };
}
