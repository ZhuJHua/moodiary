import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../prompts/diary_prompts.dart';
import '../transport/server_icon.dart';
import 'mcp_results.dart';

McpServer buildMoodiaryServer({
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required TagRepository tags,
  required MoodInsightsRepository insights,
  required String appVersion,
  required Uri iconUri,
  DiaryMediaStore? mediaStore,
  EmbedIndexService? semantic,
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
  registerMoodiaryTools(
    server,
    diaries: diaries,
    categories: categories,
    tags: tags,
    insights: insights,
    mediaStore: mediaStore,
    semantic: semantic,
  );
  registerDiaryPrompts(server, diaries: diaries, insights: insights);
  return server;
}

void registerMoodiaryTools(
  McpServer server, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  required TagRepository tags,
  required MoodInsightsRepository insights,
  DiaryMediaStore? mediaStore,
  EmbedIndexService? semantic,
}) {
  for (final def in toolsFor(ToolSurface.mcp)) {
    server.registerTool(
      def.name,
      title: def.title,
      description: def.description(ToolSurface.mcp),
      inputSchema: _ToolInputSchema(def.input(ToolSurface.mcp).value),
      outputSchema: ToolOutputSchema.fromJson(def.output.value),
      annotations: ToolAnnotations(
        readOnlyHint: def.effect == ToolEffect.read,
        destructiveHint: def.effect == ToolEffect.destructive,
        idempotentHint: def.idempotent,
        openWorldHint: false,
      ),
      callback: (arguments, call) async {
        try {
          final result = await def.call(
            arguments,
            ToolContext(
              diaries: diaries,
              categories: categories,
              tags: tags,
              insights: insights,
              surface: ToolSurface.mcp,
              mediaStore: mediaStore,
              semantic: semantic,
            ),
          );
          final json = jsonToolResult(result.data);
          if (result.media.isEmpty) return json;
          return CallToolResult(
            content: [
              for (final media in result.media)
                ImageContent(
                  data: base64Encode(media.bytes),
                  mimeType: media.mimeType,
                ),
              ...json.content,
            ],
            structuredContent: result.data,
          );
        } on ToolArgumentException catch (error) {
          throw McpError(ErrorCode.invalidParams.value, error.message);
        } on ToolFailure catch (error) {
          return toolError(error.message);
        }
      },
    );
  }
}

class _ToolInputSchema extends ToolInputSchema {
  const _ToolInputSchema(this.schema);
  final Map<String, Object?> schema;
  @override
  Map<String, dynamic> toJson() => schema;
  @override
  Object toJsonValue() => const {'type': 'object'};
}
