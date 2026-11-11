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

  static McpLogLevel? tryParse(String? name) => switch (name) {
    'debug' => .debug,
    'info' => .info,
    'notice' => .notice,
    'warning' => .warning,
    'error' => .error,
    'critical' => .critical,
    'alert' => .alert,
    'emergency' => .emergency,
    _ => null,
  };

  static McpLogLevel fromName(String? name) => tryParse(name) ?? .info;

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
}

/// A tool the client can call.
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    this.title,
    this.readOnly = false,
    this.destructive = false,
    this.idempotent = false,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String? title;

  final bool readOnly;

  /// Only meaningful when [readOnly] is false.
  final bool destructive;
  final bool idempotent;

  Map<String, dynamic> toJson() => {
    'name': name,
    'title': ?title,
    'description': description,
    'inputSchema': inputSchema,
    'annotations': {
      'readOnlyHint': readOnly,
      'destructiveHint': destructive,
      'idempotentHint': idempotent,
      // Diaries live in a closed local database: every tool is closed-world.
      'openWorldHint': false,
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
    required this.notify,
    required this.cancelled,
    this.progressToken,
    this.logMessage,
  });

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
  ///
  /// Both numbers are sent as JSON reals rather than integers, because clients
  /// decode a `progress` value as a `double` and some of them reject an integer
  /// token. The measurement is the same; only its JSON shape changes.
  void reportProgress(num progress, {num? total, String? message}) {
    final token = progressToken;
    if (token == null) return;
    notify({
      'jsonrpc': '2.0',
      'method': 'notifications/progress',
      'params': {
        'progressToken': token,
        'progress': progress.toDouble(),
        'total': ?total?.toDouble(),
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
    required this.description,
    this.title,
    this.mimeType,
  });

  final String uri;
  final String name;
  final String? title;

  /// Required here although the 2025-06-18 schema marks it optional: SDK
  /// clients decode `description` as a non-null [String] and fail the whole
  /// `resources/list` response when a resource omits it.
  final String description;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
    'uri': uri,
    'name': name,
    'title': ?title,
    'description': description,
    'mimeType': ?mimeType,
  };
}

/// RFC 6570 level 1 template (`moodiary://diary/{id}`), which is what MCP
/// clients understand in `resources/templates/list`.
class McpResourceTemplate {
  const McpResourceTemplate({
    required this.uriTemplate,
    required this.name,
    required this.description,
    this.title,
    this.mimeType,
  });

  final String uriTemplate;
  final String name;
  final String? title;

  /// Required here although the 2025-06-18 schema marks it optional: SDK
  /// clients decode `description` as a non-null [String] and fail the whole
  /// `resources/templates/list` response when a template omits it.
  final String description;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
    'uriTemplate': uriTemplate,
    'name': name,
    'title': ?title,
    'description': description,
    'mimeType': ?mimeType,
  };

  /// Returns the template variables for [uri], or `null` when it does not match.
  ///
  /// Both sides are compared after URI parsing, so a percent-encoded segment
  /// arrives decoded here and no hand-built pattern has to escape anything.
  Map<String, String>? match(String uri) {
    final parsed = Uri.tryParse(uri);
    final template = Uri.tryParse(uriTemplate);
    if (parsed == null || template == null) return null;
    if (parsed.hasQuery || parsed.hasFragment) return null;
    if (parsed.scheme != template.scheme || parsed.host != template.host) {
      return null;
    }
    final actual = parsed.pathSegments;
    final expected = template.pathSegments;
    if (actual.length != expected.length) return null;
    final variables = <String, String>{};
    for (var i = 0; i < expected.length; i++) {
      final segment = expected[i];
      final value = actual[i];
      if (segment.startsWith('{') && segment.endsWith('}')) {
        if (value.isEmpty) return null;
        variables[segment.substring(1, segment.length - 1)] = value;
        continue;
      }
      if (segment != value) return null;
    }
    return variables;
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
