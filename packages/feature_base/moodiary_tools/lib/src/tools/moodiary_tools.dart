import 'category_tools.dart';
import 'diary_tools.dart';
import 'media_tools.dart';
import 'stats_tools.dart';
import 'tool_def.dart';

final List<ToolDef> moodiaryTools = List.unmodifiable([
  ...diaryTools,
  ...categoryTools,
  ...mediaTools,
  ...statsTools,
]);

Iterable<ToolDef> toolsFor(ToolSurface surface) =>
    moodiaryTools.where((tool) => tool.surfaces.contains(surface));
