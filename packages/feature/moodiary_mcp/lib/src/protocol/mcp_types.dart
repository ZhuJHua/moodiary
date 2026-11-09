/// Wire shapes and descriptors of the Model Context Protocol.
///
/// Everything here is transport independent: the server core, the tool catalog
/// and the transports all share these types. Text that reaches a model is
/// hardcoded English on purpose; user facing strings live in the app i18n.
library;

import 'dart:convert';
import 'dart:typed_data';

const String mcpServerName = 'moodiary';

const String mcpLatestProtocolVersion = '2025-06-18';

/// Newest first. The server answers `initialize` with the newest version it
/// shares with the client and falls back to [mcpLatestProtocolVersion] when the
/// client asks for something unknown.
const List<String> mcpSupportedProtocolVersions = [
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

const String mcpServerInstructions =
    'Moodiary is a local diary app. These tools read and write the diary '
    'database of the device that runs this server: diaries (title, body, time, '
    'mood, tags, category), categories, full text search, statistics, media and '
    'long images. A body is stored as a Tiptap document, and the contentFormat '
    'argument selects the representation on reads and writes: markdown '
    '(default), text, or document for the raw Tiptap JSON object. On update '
    'calls a field you omit is left unchanged and an explicit null clears a '
    'nullable one (categoryId, mood, tags, color, parentId); title is cleared '
    'with an empty string. Media is attached with add_diary_image or '
    'add_diary_attachment, listed by list_diary_media and returned by '
    'read_diary_media; render_diary_image renders a diary as the same long PNG '
    'the app exports. A bad argument is a JSON-RPC invalid params error, while '
    'an unknown id is a normal tool result with isError. Diary bodies and '
    'titles are private user data: quote them only when the user asks about '
    'them.';

/// Page size for every list/cursor endpoint.
const int mcpPageSize = 50;

String negotiateProtocolVersion(Object? requested) {
  if (requested is String && mcpSupportedProtocolVersions.contains(requested)) {
    return requested;
  }
  return mcpLatestProtocolVersion;
}

/// MCP logging levels, least to most severe.
enum McpLogLevel {
  debug,
  info,
  notice,
  warning,
  error,
  critical,
  alert,
  emergency;

  static McpLogLevel fromName(String? name) => switch (name) {
    'debug' => .debug,
    'info' => .info,
    'notice' => .notice,
    'warning' => .warning,
    'error' => .error,
    'critical' => .critical,
    'alert' => .alert,
    'emergency' => .emergency,
    _ => .info,
  };

  bool allows(McpLogLevel level) => level.index >= index;
}

/// `content` items of tool results and prompt messages.
abstract final class McpContent {
  static Map<String, dynamic> text(String text) => {
    'type': 'text',
    'text': text,
  };

  static Map<String, dynamic> image({
    required String base64Data,
    required String mimeType,
  }) => {'type': 'image', 'data': base64Data, 'mimeType': mimeType};

  static Map<String, dynamic> resourceLink({
    required String uri,
    required String name,
    String? description,
    String? mimeType,
  }) => {
    'type': 'resource_link',
    'uri': uri,
    'name': name,
    'description': ?description,
    'mimeType': ?mimeType,
  };

  static Map<String, dynamic> embeddedResource({
    required String uri,
    required String mimeType,
    String? text,
    String? blob,
  }) => {
    'type': 'resource',
    'resource': {
      'uri': uri,
      'mimeType': mimeType,
      'text': ?text,
      'blob': ?blob,
    },
  };
}

/// A tool the client can call.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.title,
    this.outputSchema,
    this.readOnly = false,
    this.destructive = false,
    this.idempotent = false,
    this.openWorld = false,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String? title;
  final Map<String, dynamic>? outputSchema;

  final bool readOnly;

  /// Only meaningful when [readOnly] is false.
  final bool destructive;
  final bool idempotent;

  /// Diaries live in a closed local database, so this stays false.
  final bool openWorld;

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': ?title,
    'description': description,
    'inputSchema': inputSchema,
    'outputSchema': ?outputSchema,
    'annotations': {
      'readOnlyHint': readOnly,
      'destructiveHint': destructive,
      'idempotentHint': idempotent,
      'openWorldHint': openWorld,
    },
  };
}

/// Result of one `tools/call`.
class McpToolResult {
  McpToolResult({
    required this.content,
    this.structuredContent,
    this.isError = false,
  });

  /// Text-only convenience for tools that report prose.
  factory McpToolResult.text(String text) =>
      McpToolResult(content: [McpContent.text(text)]);

  /// Machine readable result: JSON text for older clients plus the same object
  /// as `structuredContent` for clients that read it.
  factory McpToolResult.json(Map<String, dynamic> data) => McpToolResult(
    content: [McpContent.text(jsonEncode(data))],
    structuredContent: data,
  );

  factory McpToolResult.error(String message) =>
      McpToolResult(content: [McpContent.text(message)], isError: true);

  final List<Map<String, dynamic>> content;
  final Map<String, dynamic>? structuredContent;
  final bool isError;

  Map<String, dynamic> toJson() => {
    'content': content,
    'structuredContent': ?structuredContent,
    'isError': isError,
  };
}

/// Per-call context handed to tool, resource and prompt handlers.
class McpCallContext {
  McpCallContext({
    required this.sessionId,
    required this.requestId,
    required this.protocolVersion,
    required this.notify,
    required this.cancelled,
    this.progressToken,
    this.logMessage,
  });

  final String sessionId;
  final Object? requestId;
  final String protocolVersion;

  /// Sends one server to client JSON-RPC notification to this session.
  final void Function(Map<String, dynamic> notification) notify;

  final Object? progressToken;

  /// Whether the client cancelled the request this context belongs to.
  final bool Function() cancelled;

  /// Sink for `notifications/message`; `null` when the caller did not wire it.
  final void Function(McpLogLevel level, String message, Object? data)?
  logMessage;

  bool get isCancelled => cancelled();

  /// No-op when the client did not send a `progressToken`.
  void reportProgress(num progress, {num? total, String? message}) {
    final token = progressToken;
    if (token == null) return;
    notify({
      'jsonrpc': '2.0',
      'method': 'notifications/progress',
      'params': {
        'progressToken': token,
        'progress': progress,
        'total': ?total,
        'message': ?message,
      },
    });
  }

  void log(McpLogLevel level, String message, {Object? data}) =>
      logMessage?.call(level, message, data);
}

class McpResource {
  const McpResource({
    required this.uri,
    required this.name,
    this.title,
    this.description,
    this.mimeType,
  });

  final String uri;
  final String name;
  final String? title;
  final String? description;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    'title': ?title,
    'description': ?description,
    'mimeType': ?mimeType,
  };
}

/// RFC 6570 level 1 template (`moodiary://diary/{id}`), which is what MCP
/// clients understand in `resources/templates/list`.
class McpResourceTemplate {
  const McpResourceTemplate({
    required this.uriTemplate,
    required this.name,
    this.title,
    this.description,
    this.mimeType,
  });

  final String uriTemplate;
  final String name;
  final String? title;
  final String? description;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
    'uriTemplate': uriTemplate,
    'name': name,
    'title': ?title,
    'description': ?description,
    'mimeType': ?mimeType,
  };

  /// Returns the template variables for [uri], or `null` when it does not match.
  Map<String, String>? match(String uri) {
    final pattern = StringBuffer('^');
    final names = <String>[];
    final segments = uriTemplate.split('/');
    for (var i = 0; i < segments.length; i++) {
      // `moodiary://…` already carries two empty segments; only add the
      // separator between segments or the pattern would require a leading `/`.
      if (i > 0) pattern.write('/');
      final segment = segments[i];
      if (segment.startsWith('{') && segment.endsWith('}')) {
        names.add(segment.substring(1, segment.length - 1));
        pattern.write('([^/]+)');
      } else {
        pattern.write(RegExp.escape(segment));
      }
    }
    pattern.write(r'$');
    final match = RegExp(pattern.toString()).firstMatch(uri);
    if (match == null) return null;
    return {
      for (var i = 0; i < names.length; i++)
        names[i]: Uri.decodeComponent(match.group(i + 1)!),
    };
  }
}

/// Result of one `resources/read`.
class McpResourceReadResult {
  const McpResourceReadResult(this.contents);

  factory McpResourceReadResult.text(
    String uri,
    String text, {
    String mimeType = 'text/plain',
  }) => McpResourceReadResult([
    {'uri': uri, 'mimeType': mimeType, 'text': text},
  ]);

  factory McpResourceReadResult.json(String uri, Object? value) =>
      McpResourceReadResult.text(
        uri,
        const JsonEncoder.withIndent('  ').convert(value),
        mimeType: 'application/json',
      );

  factory McpResourceReadResult.blob(
    String uri,
    Uint8List bytes, {
    required String mimeType,
  }) => McpResourceReadResult([
    {'uri': uri, 'mimeType': mimeType, 'blob': base64Encode(bytes)},
  ]);

  final List<Map<String, dynamic>> contents;

  Map<String, dynamic> toJson() => {'contents': contents};
}

class McpPromptArgument {
  const McpPromptArgument({
    required this.name,
    this.description,
    this.required = false,
  });

  final String name;
  final String? description;
  final bool required;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': ?description,
    'required': required,
  };
}

class McpPrompt {
  const McpPrompt({
    required this.name,
    required this.description,
    this.title,
    this.arguments = const [],
  });

  final String name;
  final String description;
  final String? title;
  final List<McpPromptArgument> arguments;

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': ?title,
    'description': description,
    'arguments': [for (final a in arguments) a.toJson()],
  };
}

class McpPromptMessage {
  const McpPromptMessage({required this.role, required this.content});

  factory McpPromptMessage.user(String text) =>
      McpPromptMessage(role: 'user', content: McpContent.text(text));

  final String role;
  final Map<String, dynamic> content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class McpPromptResult {
  const McpPromptResult({required this.messages, this.description});

  final List<McpPromptMessage> messages;
  final String? description;

  Map<String, dynamic> toJson() => {
    'description': ?description,
    'messages': [for (final m in messages) m.toJson()],
  };
}

/// Argument completions for one prompt or resource template (`completion/complete`).
class McpCompletionResult {
  const McpCompletionResult({
    required this.values,
    this.total,
    this.hasMore = false,
  });

  final List<String> values;
  final int? total;
  final bool hasMore;

  Map<String, dynamic> toJson() => {
    'completion': {'values': values, 'total': ?total, 'hasMore': hasMore},
  };
}
