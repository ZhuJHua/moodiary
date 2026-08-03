import 'package:flutter/material.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart' show LucideIcons;

({IconData icon, String title, String description}) assistantToolDisplay(
  BuildContext context,
  AssistantTool tool,
) {
  final l10n = context.l10n;
  return switch (tool) {
    AssistantTool.queryDiaries => (
      icon: LucideIcons.textSearch,
      title: l10n.assistantToolQueryTitle,
      description: l10n.assistantToolQueryDes,
    ),
    AssistantTool.getDiary => (
      icon: LucideIcons.fileText,
      title: l10n.assistantToolGetTitle,
      description: l10n.assistantToolGetDes,
    ),
    AssistantTool.diaryOverview => (
      icon: LucideIcons.chartNoAxesCombined,
      title: l10n.assistantToolOverviewTitle,
      description: l10n.assistantToolOverviewDes,
    ),
    AssistantTool.createDiary => (
      icon: LucideIcons.filePlus,
      title: l10n.assistantToolCreateTitle,
      description: l10n.assistantToolCreateDes,
    ),
    AssistantTool.updateDiary => (
      icon: LucideIcons.filePenLine,
      title: l10n.assistantToolUpdateTitle,
      description: l10n.assistantToolUpdateDes,
    ),
    AssistantTool.deleteDiary => (
      icon: LucideIcons.trash2,
      title: l10n.assistantToolDeleteTitle,
      description: l10n.assistantToolDeleteDes,
    ),
    AssistantTool.listCategories => (
      icon: LucideIcons.folderOpen,
      title: l10n.assistantToolListCategoriesTitle,
      description: l10n.assistantToolListCategoriesDes,
    ),
    AssistantTool.createCategory => (
      icon: LucideIcons.folderPlus,
      title: l10n.assistantToolCreateCategoryTitle,
      description: l10n.assistantToolCreateCategoryDes,
    ),
    AssistantTool.updateCategory => (
      icon: LucideIcons.folderPen,
      title: l10n.assistantToolUpdateCategoryTitle,
      description: l10n.assistantToolUpdateCategoryDes,
    ),
    AssistantTool.deleteCategory => (
      icon: LucideIcons.folderX,
      title: l10n.assistantToolDeleteCategoryTitle,
      description: l10n.assistantToolDeleteCategoryDes,
    ),
    AssistantTool.listMemories => (
      icon: LucideIcons.brain,
      title: l10n.assistantToolListMemoriesTitle,
      description: l10n.assistantToolListMemoriesDes,
    ),
    AssistantTool.rememberFact => (
      icon: LucideIcons.bookmarkPlus,
      title: l10n.assistantToolRememberTitle,
      description: l10n.assistantToolRememberDes,
    ),
    AssistantTool.updateMemory => (
      icon: LucideIcons.filePenLine,
      title: l10n.assistantToolUpdateMemoryTitle,
      description: l10n.assistantToolUpdateMemoryDes,
    ),
    AssistantTool.forgetFact => (
      icon: LucideIcons.eraser,
      title: l10n.assistantToolForgetTitle,
      description: l10n.assistantToolForgetDes,
    ),
  };
}
