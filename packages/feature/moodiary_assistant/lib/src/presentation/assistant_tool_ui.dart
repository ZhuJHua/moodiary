import 'package:flutter/material.dart';
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

({IconData icon, String title, String description}) assistantToolDisplay(
  BuildContext context,
  AssistantTool tool,
) {
  final l10n = context.l10n;
  return switch (tool) {
    AssistantTool.searchDiaries => (
      icon: Icons.travel_explore_rounded,
      title: l10n.assistantToolSearchTitle,
      description: l10n.assistantToolSearchDes,
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
  };
}
