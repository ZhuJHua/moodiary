import 'dart:async';
import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';

const String mcpServerName = 'moodiary';
const String mcpServerInstructions =
    'Moodiary is a local diary app. These tools read and write the diary '
    'database of the device that runs this server: diaries (title, body, time, '
    'mood, tags, category), categories, full text search, statistics and media. '
    'A body is stored as a Tiptap document, and the contentFormat '
    'argument selects the representation on reads and writes: markdown '
    '(default), text, or document for the raw Tiptap JSON object. On update '
    'calls a field you omit is left unchanged and an explicit null clears a '
    'nullable one (categoryId, mood, tags, color); title is cleared '
    'with an empty string. Media is attached with add_diary_image or '
    'add_diary_attachment, listed by list_diary_media and returned by '
    'read_diary_media for images only. delete_diary moves a diary to the '
    'recycle bin; permanent deletion is only available in the app. '
    'A bad argument is a JSON-RPC invalid params error, while '
    'an unknown id is a normal tool result with isError. Diary bodies and '
    'titles are private user data: quote them only when the user asks about '
    'them.';

CallToolResult jsonToolResult(Map<String, dynamic> data) => CallToolResult(
  content: [TextContent(text: jsonEncode(data))],
  structuredContent: data,
);

CallToolResult toolError(String message) =>
    CallToolResult(content: [TextContent(text: message)], isError: true);

PromptMessage userPromptMessage(String text) => PromptMessage(
  role: PromptMessageRole.user,
  content: TextContent(text: text),
);

void reportProgress(
  RequestHandlerExtra call,
  num progress, {
  num? total,
  String? message,
}) {
  if (call.meta?['progressToken'] == null) return;
  unawaited(
    call.sendProgress(
      progress.toDouble(),
      total: total?.toDouble(),
      message: message,
    ),
  );
}

void registerPrompt(
  McpServer server,
  Prompt prompt,
  Future<GetPromptResult> Function(
    Map<String, String> arguments,
    RequestHandlerExtra? call,
  )
  handler, {
  required Future<List<String>> Function(String argument, String partial)
  complete,
}) {
  server.registerPrompt(
    prompt.name,
    title: prompt.title,
    description: prompt.description,
    argsSchema: {
      for (final argument in prompt.arguments ?? <PromptArgument>[])
        argument.name: PromptArgumentDefinition(
          description: argument.description,
          required: argument.required ?? false,
          completable: CompletableField(
            def: CompletableDef(
              complete: (value) => complete(argument.name, value),
            ),
          ),
        ),
    },
    callback: (arguments, call) =>
        handler((arguments ?? {}).cast<String, String>(), call),
  );
}
