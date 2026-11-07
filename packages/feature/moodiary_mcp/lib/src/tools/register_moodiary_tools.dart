/// Diary domain catalog: everything `tools/list`, `resources/*` and `prompts/*`
/// answer with.
///
/// Split by responsibility; [buildMoodiaryRegistry] wires them together and is
/// the only entry point the service needs.
library;

import 'package:moodiary_data/moodiary_data.dart';

import '../prompts/diary_prompts.dart';
import '../registry/mcp_registry.dart';
import '../resources/diary_resources.dart';
import 'category_tools.dart';
import 'diary_tools.dart';
import 'stats_tools.dart';

/// Builds the frozen catalog of one server instance.
///
/// The catalog is immutable once built, which is why the list-changed
/// capabilities stay `false`: a client sees database changes by calling the
/// tools again and through `notifications/resources/updated`.
McpRegistry buildMoodiaryRegistry({
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
  required String appVersion,
}) {
  final registry = McpRegistry();
  registerDiaryTools(registry, diaries: diaries, categories: categories);
  registerCategoryTools(registry, diaries: diaries, categories: categories);
  registerStatsTools(
    registry,
    diaries: diaries,
    categories: categories,
    insights: insights,
    appVersion: appVersion,
  );
  registerDiaryResources(
    registry,
    diaries: diaries,
    categories: categories,
    insights: insights,
  );
  registerDiaryPrompts(
    registry,
    diaries: diaries,
    categories: categories,
    insights: insights,
  );
  return registry;
}
