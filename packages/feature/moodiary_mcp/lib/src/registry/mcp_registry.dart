/// The catalog of tools, resources and prompts this server exposes.
///
/// Guests (the diary domain in `tools/`, `resources/` and `prompts/`) register
/// handlers; the server core only looks them up. Everything is immutable once
/// the service has started, which is why the list-changed capabilities stay
/// `false`.
library;

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

class McpRegistry {
  /// The descriptor a list endpoint advertises next to the handler that serves
  /// it.
  final Map<String, (McpTool, McpToolHandler)> _tools = {};
  final Map<String, (McpResource, McpResourceReader)> _resources = {};
  final List<(McpResourceTemplate, McpResourceTemplateReader)> _templates = [];
  final Map<String, (McpPrompt, McpPromptHandler, McpCompletionHandler?)>
  _prompts = {};

  void addTool(McpTool tool, McpToolHandler handler) {
    if (_tools.containsKey(tool.name)) {
      throw ArgumentError('duplicate MCP tool: ${tool.name}');
    }
    _tools[tool.name] = (tool, handler);
  }

  void addResource(McpResource resource, McpResourceReader reader) {
    if (_resources.containsKey(resource.uri)) {
      throw ArgumentError('duplicate MCP resource: ${resource.uri}');
    }
    _resources[resource.uri] = (resource, reader);
  }

  void addResourceTemplate(
    McpResourceTemplate template,
    McpResourceTemplateReader reader,
  ) {
    if (_templates.any((e) => e.$1.uriTemplate == template.uriTemplate)) {
      throw ArgumentError(
        'duplicate MCP resource template: '
        '${template.uriTemplate}',
      );
    }
    _templates.add((template, reader));
  }

  void addPrompt(
    McpPrompt prompt,
    McpPromptHandler handler, {
    McpCompletionHandler? complete,
  }) {
    if (_prompts.containsKey(prompt.name)) {
      throw ArgumentError('duplicate MCP prompt: ${prompt.name}');
    }
    _prompts[prompt.name] = (prompt, handler, complete);
  }

  /// Completion handler for a prompt argument, when the guest installed one.
  McpCompletionHandler? promptCompletion(String prompt) => _prompts[prompt]?.$3;

  List<McpTool> get tools => [for (final e in _tools.values) e.$1];

  List<McpResource> get resources => [for (final e in _resources.values) e.$1];

  List<McpResourceTemplate> get resourceTemplates => [
    for (final e in _templates) e.$1,
  ];

  List<McpPrompt> get prompts => [for (final e in _prompts.values) e.$1];

  McpToolHandler? toolHandler(String name) => _tools[name]?.$2;

  /// Matches a static resource first, then the registered templates.
  Future<McpResourceReadResult> Function(McpCallContext call)? resolveResource(
    String uri,
  ) {
    final direct = _resources[uri];
    if (direct != null) return (call) => direct.$2(call, uri);
    for (final entry in _templates) {
      final variables = entry.$1.match(uri);
      if (variables == null) continue;
      return (call) => entry.$2(call, uri, variables);
    }
    return null;
  }

  McpPromptHandler? promptHandler(String name) => _prompts[name]?.$2;
}
