import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';

import '../media/diary_media.dart';
import '../prompts/diary_prompts.dart';
import '../transport/server_icon.dart';
import 'category_tools.dart';
import 'diary_tools.dart';
import 'mcp_results.dart';
import 'media_tools.dart';
import 'stats_tools.dart';

McpServer buildMoodiaryServer({
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required MoodInsightsRepository insights,
  required String appVersion,
  required Uri iconUri,
  DiaryMediaStore? mediaStore,
}) {
  final server = McpServer(
    Implementation(
      name: mcpServerName,
      title: 'Moodiary',
      websiteUrl: 'https://github.com/ZhuJHua/moodiary',
      version: appVersion,
      icons: [
        McpIcon(
          src: iconUri.toString(),
          mimeType: mcpIconMimeType,
          sizes: ['${mcpIconEdge}x$mcpIconEdge'],
        ),
      ],
    ),
    options: const McpServerOptions(
      protocol: McpProtocol.stable,
      instructions: mcpServerInstructions,
    ),
  );
  registerDiaryTools(server, diaries: diaries, categories: categories);
  registerCategoryTools(server, diaries: diaries, categories: categories);
  registerMediaTools(
    server,
    diaries: diaries,
    categories: categories,
    store: mediaStore,
  );
  registerStatsTools(
    server,
    diaries: diaries,
    categories: categories,
    insights: insights,
  );
  registerDiaryPrompts(server, diaries: diaries, insights: insights);
  return server;
}
