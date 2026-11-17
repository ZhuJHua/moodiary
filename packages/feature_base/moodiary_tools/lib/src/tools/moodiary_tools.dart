import 'category_tools.dart';
import 'diary_tools.dart';
import 'media_tools.dart';
import 'stats_tools.dart';
import 'tool_def.dart';

final List<ToolDefinition> moodiaryTools = List.unmodifiable([
  ...diaryTools,
  ...categoryTools,
  ...mediaTools,
  ...statsTools,
]);
