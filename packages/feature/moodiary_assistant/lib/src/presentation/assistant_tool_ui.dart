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
    .queryDiaries => (
      icon: LucideIcons.textSearch,
      title: l10n.assistant.toolQueryTitle,
      description: l10n.assistant.toolQueryDes,
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
    .listMemories => (
      icon: LucideIcons.brain,
      title: l10n.assistant.toolListMemoriesTitle,
      description: l10n.assistant.toolListMemoriesDes,
    ),
    .rememberFact => (
      icon: LucideIcons.bookmarkPlus,
      title: l10n.assistant.toolRememberTitle,
      description: l10n.assistant.toolRememberDes,
    ),
    .updateMemory => (
      icon: LucideIcons.filePenLine,
      title: l10n.assistant.toolUpdateMemoryTitle,
      description: l10n.assistant.toolUpdateMemoryDes,
    ),
    .forgetFact => (
      icon: LucideIcons.eraser,
      title: l10n.assistant.toolForgetTitle,
      description: l10n.assistant.toolForgetDes,
    ),
  };
}
