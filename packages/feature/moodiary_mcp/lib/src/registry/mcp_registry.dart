/// The catalog of tools, resources and prompts this server exposes.
///
/// Guests (the diary domain in `tools/`, `resources/` and `prompts/`) register
/// handlers; the server core only looks them up. Everything is immutable once
/// the service has started, which is why the list-changed capabilities stay
/// `false`.
library;

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';

typedef McpToolHandler = Future<McpToolResult> Function(
  McpCallContext call,
  Map<String, dynamic> arguments,
);

typedef McpResourceReader = Future<McpResourceReadResult> Function(
  McpCallContext call,
  String uri,
);

typedef McpResourceTemplateReader = Future<McpResourceReadResult> Function(
  McpCallContext call,
  String uri,
  Map<String, String> variables,
);

typedef McpPromptHandler = Future<McpPromptResult> Function(
  McpCallContext call,
  Map<String, String> arguments,
);

typedef McpCompletionHandler = Future<McpCompletionResult> Function(
  McpCallContext call,
  String argumentName,
  String partialValue,
);

/// One page of a list endpoint plus the cursor of the following page.
class McpPage<T> {
  const McpPage(this.items, this.nextCursor);

  final List<T> items;
  final String? nextCursor;

  /// Encodes the page under [key], the property name the schema gives the list
  /// (`tools`, `resources`, `resourceTemplates`, `prompts`).
  ///
  /// The name is not cosmetic: clients read exactly that property, so a generic
  /// wrapper such as `items` makes `tools/list` answer a result without
  /// `tools`, and a typed client fails while decoding it.
  Map<String, dynamic> toJson(String key, Object? Function(T item) encode) => {
    key: [for (final item in items) encode(item)],
    'nextCursor': ?nextCursor,
  };
}

class McpRegistry {
  final Map<String, _ToolEntry> _tools = {};
  final Map<String, _ResourceEntry> _resources = {};
  final List<_ResourceTemplateEntry> _templates = [];
  final Map<String, _PromptEntry> _prompts = {};

  bool get isEmpty => _tools.isEmpty && _resources.isEmpty && _prompts.isEmpty;

  void addTool(McpTool tool, McpToolHandler handler) {
    if (_tools.containsKey(tool.name)) {
      throw ArgumentError('duplicate MCP tool: ${tool.name}');
    }
    _tools[tool.name] = _ToolEntry(tool, handler);
  }

  void addResource(McpResource resource, McpResourceReader reader) {
    if (_resources.containsKey(resource.uri)) {
      throw ArgumentError('duplicate MCP resource: ${resource.uri}');
    }
    _resources[resource.uri] = _ResourceEntry(resource, reader);
  }

  void addResourceTemplate(
    McpResourceTemplate template,
    McpResourceTemplateReader reader,
  ) {
    if (_templates.any((e) => e.template.uriTemplate == template.uriTemplate)) {
      throw ArgumentError(
        'duplicate MCP resource template: '
        '${template.uriTemplate}',
      );
    }
    _templates.add(_ResourceTemplateEntry(template, reader));
  }

  void addPrompt(
    McpPrompt prompt,
    McpPromptHandler handler, {
    McpCompletionHandler? complete,
  }) {
    if (_prompts.containsKey(prompt.name)) {
      throw ArgumentError('duplicate MCP prompt: ${prompt.name}');
    }
    _prompts[prompt.name] = _PromptEntry(prompt, handler, complete);
  }

  /// Completion handler for a prompt argument, when the guest installed one.
  McpCompletionHandler? promptCompletion(String prompt) =>
      _prompts[prompt]?.complete;

  List<McpTool> get tools => [for (final e in _tools.values) e.tool];

  List<McpResource> get resources => [
    for (final e in _resources.values) e.resource,
  ];

  List<McpResourceTemplate> get resourceTemplates => [
    for (final e in _templates) e.template,
  ];

  List<McpPrompt> get prompts => [for (final e in _prompts.values) e.prompt];

  /// Cursor pagination over a descriptor list; [cursor] is the opaque value a
  /// previous page returned.
  McpPage<T> page<T>(List<T> all, Object? cursor) {
    final offset = _offset(cursor);
    final end = offset + mcpPageSize;
    return McpPage(
      all.skip(offset).take(mcpPageSize).toList(),
      end < all.length ? '$end' : null,
    );
  }

  static int _offset(Object? cursor) {
    if (cursor == null || cursor == '') return 0;
    final offset = int.tryParse('$cursor');
    if (offset == null || offset < 0) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'cursor is not a valid page cursor',
      );
    }
    return offset;
  }

  McpToolHandler? toolHandler(String name) => _tools[name]?.handler;

  bool hasTool(String name) => _tools.containsKey(name);

  /// Matches a static resource first, then the registered templates.
  McpResolvedResource? resolveResource(String uri) {
    final direct = _resources[uri];
    if (direct != null) {
      return McpResolvedResource(reader: (call) => direct.reader(call, uri));
    }
    for (final entry in _templates) {
      final variables = entry.template.match(uri);
      if (variables == null) continue;
      return McpResolvedResource(
        reader: (call) => entry.reader(call, uri, variables),
        template: entry.template,
      );
    }
    return null;
  }

  McpPromptHandler? promptHandler(String name) => _prompts[name]?.handler;
}

class McpResolvedResource {
  const McpResolvedResource({required this.reader, this.template});

  final Future<McpResourceReadResult> Function(McpCallContext call) reader;
  final McpResourceTemplate? template;
}

class _ToolEntry {
  const _ToolEntry(this.tool, this.handler);

  final McpTool tool;
  final McpToolHandler handler;
}

class _ResourceEntry {
  const _ResourceEntry(this.resource, this.reader);

  final McpResource resource;
  final McpResourceReader reader;
}

class _ResourceTemplateEntry {
  const _ResourceTemplateEntry(this.template, this.reader);

  final McpResourceTemplate template;
  final McpResourceTemplateReader reader;
}

class _PromptEntry {
  const _PromptEntry(this.prompt, this.handler, this.complete);

  final McpPrompt prompt;
  final McpPromptHandler handler;
  final McpCompletionHandler? complete;
}
