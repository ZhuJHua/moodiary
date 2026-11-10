import 'dart:async';

import 'package:moodiary_logging/moodiary_logging.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'mcp_session.dart';

/// Transport independent MCP server core: session bookkeeping, `initialize`
/// negotiation, capability advertisement and the method dispatch table.
///
/// Transports (Streamable HTTP, legacy HTTP+SSE) hand decoded JSON-RPC messages
/// in and write the returned responses out; the core never touches sockets.
class McpServer {
  McpServer({
    required this.registry,
    this.serverVersion = '0.0.0',
    this.maxSessions = 64,
  });

  final McpRegistry registry;
  final String serverVersion;

  /// Sessions kept at once; the oldest is evicted when a new one would exceed
  /// it. A local endpoint has one client, so this only bounds a client that
  /// keeps connecting without ending its sessions.
  final int maxSessions;

  final Map<String, McpSessionState> _sessions = {};
  int _sessionSeq = 0;

  McpSessionState createSession([String? id]) {
    final session = McpSessionState(
      id:
          id ??
          'moodiary-${++_sessionSeq}-${DateTime.now().microsecondsSinceEpoch}',
    );
    _sessions[session.id] = session;
    while (_sessions.length > maxSessions) {
      // Insertion order is creation order, so the first key is the oldest one.
      final oldest = _sessions.keys.first;
      logger.d('MCP: session limit reached, dropping the oldest session');
      disposeSession(oldest);
    }
    return session;
  }

  McpSessionState? session(String id) => _sessions[id];

  void disposeSession(String id) {
    _sessions.remove(id)?.dispose();
  }

  /// Drops the sessions idle for longer than [idleTimeout] and returns their
  /// ids, so a transport can close the streams it still holds for them.
  List<String> pruneIdleSessions(Duration idleTimeout) {
    final cutoff = DateTime.now().subtract(idleTimeout);
    final idle = [
      for (final entry in _sessions.entries)
        if (entry.value.lastSeen.isBefore(cutoff)) entry.key,
    ];
    if (idle.isEmpty) return const [];
    logger.d('MCP: dropping ${idle.length} idle session(s)');
    for (final id in idle) {
      disposeSession(id);
    }
    return idle;
  }

  void dispose() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  /// Handles one decoded JSON-RPC message and returns the frame to send back,
  /// or `null` for notifications (and for stray responses, which this server
  /// never expects).
  Future<Map<String, dynamic>?> handle(
    McpSessionState session,
    Map<String, dynamic> message,
  ) async {
    JsonRpcRequest? request;
    try {
      request = parseJsonRpc(message);
    } on JsonRpcException catch (e) {
      return jsonRpcFailure(null, e);
    }
    if (request == null) return null;
    if (request.isNotification) {
      await _notification(session, request);
      return null;
    }
    final id = request.id;
    try {
      final result = await _request(session, request);
      if (session.isCancelled(id)) {
        session.clearCancelled(id);
        return jsonRpcFailure(
          id,
          const JsonRpcException(
            JsonRpcCode.requestCancelled,
            'request cancelled by the client',
          ),
        );
      }
      return jsonRpcResult(id, result);
    } on JsonRpcException catch (e) {
      session.clearCancelled(id);
      return jsonRpcFailure(id, e);
    } catch (e, s) {
      session.clearCancelled(id);
      logger.e(
        'MCP request failed: ${request.method}',
        error: e,
        stackTrace: s,
      );
      return jsonRpcFailure(
        id,
        JsonRpcException(JsonRpcCode.internalError, e.toString()),
      );
    }
  }

  Future<Object?> _request(
    McpSessionState session,
    JsonRpcRequest request,
  ) async => switch (request.method) {
    'initialize' => _initialize(session, request.params),
    'ping' => const <String, dynamic>{},
    'tools/list' => _listTools(),
    'tools/call' => _callTool(session, request),
    'resources/list' => _listResources(),
    'resources/templates/list' => _listResourceTemplates(),
    'resources/read' => _readResource(session, request),
    'prompts/list' => _listPrompts(),
    'prompts/get' => _getPrompt(session, request),
    'logging/setLevel' => _setLevel(session, request.params),
    'completion/complete' => _complete(session, request),
    _ => throw JsonRpcException(
      JsonRpcCode.methodNotFound,
      'method not found: ${request.method}',
    ),
  };

  Future<void> _notification(
    McpSessionState session,
    JsonRpcRequest request,
  ) async {
    switch (request.method) {
      case 'notifications/cancelled':
        final id = request.params['requestId'];
        if (id != null) session.cancel(id);
      case 'notifications/initialized':
        // Nothing to do: `initialize` already stored the negotiated version.
        break;
      case 'notifications/progress':
        // Only the client talks about its own progress; the server ignores it.
        break;
      default:
        // Unknown notifications must not be answered.
        break;
    }
  }

  Map<String, dynamic> _initialize(
    McpSessionState session,
    Map<String, dynamic> params,
  ) {
    session.protocolVersion = negotiateProtocolVersion(
      params['protocolVersion'],
    );
    final clientInfo = params['clientInfo'];
    final clientName = clientInfo is Map
        ? clientInfo['name']?.toString()
        : null;
    logger.d(
      'MCP session ${session.id} initialized '
      '(client: ${clientName ?? 'unknown'}, '
      'protocol: ${session.protocolVersion})',
    );
    return {
      'protocolVersion': session.protocolVersion,
      'capabilities': {
        'tools': {'listChanged': false},
        'resources': {'subscribe': false, 'listChanged': false},
        'prompts': {'listChanged': false},
        'logging': <String, dynamic>{},
        'completions': <String, dynamic>{},
      },
      'serverInfo': {
        'name': mcpServerName,
        'title': 'Moodiary',
        'version': serverVersion,
      },
      'instructions': mcpServerInstructions,
    };
  }

  // The property names below are the protocol, not formatting: a client reads
  // `tools` off a `tools/list` result, so a generic `items` wrapper makes a
  // typed client fail while decoding the response.
  Map<String, dynamic> _listTools() => {
    'tools': [for (final tool in registry.tools) tool.toJson()],
  };

  Map<String, dynamic> _listResources() => {
    'resources': [for (final resource in registry.resources) resource.toJson()],
  };

  Map<String, dynamic> _listResourceTemplates() => {
    'resourceTemplates': [
      for (final template in registry.resourceTemplates) template.toJson(),
    ],
  };

  Map<String, dynamic> _listPrompts() => {
    'prompts': [for (final prompt in registry.prompts) prompt.toJson()],
  };

  Future<Map<String, dynamic>> _callTool(
    McpSessionState session,
    JsonRpcRequest request,
  ) async {
    final name = request.params['name'];
    if (name is! String || name.isEmpty) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'name must be the tool name',
      );
    }
    final handler = registry.toolHandler(name);
    if (handler == null) {
      throw JsonRpcException(JsonRpcCode.invalidParams, 'unknown tool: $name');
    }
    final arguments = request.params['arguments'];
    if (arguments != null && arguments is! Map) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'arguments must be an object',
      );
    }
    final call = _context(session, request);
    try {
      final result = await handler(
        call,
        arguments == null
            ? const {}
            : Map<String, dynamic>.from(arguments as Map),
      );
      return result.toJson();
    } on JsonRpcException {
      rethrow;
    } catch (e, s) {
      // A tool that fails is a tool level error, not a protocol error: the
      // client decides whether to surface it to the model.
      logger.e('MCP tool failed: $name', error: e, stackTrace: s);
      return McpToolResult.error('$e').toJson();
    }
  }

  Future<Map<String, dynamic>> _readResource(
    McpSessionState session,
    JsonRpcRequest request,
  ) async {
    final uri = request.params['uri'];
    if (uri is! String || uri.isEmpty) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'uri must be the resource uri',
      );
    }
    final reader = registry.resolveResource(uri);
    if (reader == null) {
      throw JsonRpcException(
        JsonRpcCode.resourceNotFound,
        'resource not found: $uri',
      );
    }
    final result = await reader(_context(session, request));
    return result.toJson();
  }

  Future<Map<String, dynamic>> _getPrompt(
    McpSessionState session,
    JsonRpcRequest request,
  ) async {
    final name = request.params['name'];
    if (name is! String || name.isEmpty) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'name must be the prompt name',
      );
    }
    final handler = registry.promptHandler(name);
    if (handler == null) {
      throw JsonRpcException(
        JsonRpcCode.invalidParams,
        'unknown prompt: $name',
      );
    }
    final raw = request.params['arguments'];
    final arguments = <String, String>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.value != null) '${entry.key}': '${entry.value}',
    };
    final result = await handler(_context(session, request), arguments);
    return result.toJson();
  }

  Map<String, dynamic> _setLevel(
    McpSessionState session,
    Map<String, dynamic> params,
  ) {
    session.logLevel = McpLogLevel.fromName(params['level']?.toString());
    return const {};
  }

  Future<Map<String, dynamic>> _complete(
    McpSessionState session,
    JsonRpcRequest request,
  ) async {
    final ref = request.params['ref'];
    final argument = request.params['argument'];
    if (ref is! Map || argument is! Map) {
      throw const JsonRpcException(
        JsonRpcCode.invalidParams,
        'ref and argument are required',
      );
    }
    final name = argument['name']?.toString() ?? '';
    final value = argument['value']?.toString() ?? '';
    final type = ref['type'];
    if (type == 'ref/prompt') {
      final handler = registry.promptCompletion(ref['name']?.toString() ?? '');
      if (handler == null) {
        return const McpCompletionResult(values: []).toJson();
      }
      final result = await handler(_context(session, request), name, value);
      return result.toJson();
    }
    // Resource template completions are not offered: URIs are ids, not enums.
    return const McpCompletionResult(values: []).toJson();
  }

  McpCallContext _context(McpSessionState session, JsonRpcRequest request) {
    final meta = request.params['_meta'];
    final progressToken = meta is Map ? meta['progressToken'] : null;
    return McpCallContext(
      progressToken: progressToken,
      notify: session.notify,
      cancelled: () => session.isCancelled(request.id),
      logMessage: (level, message, data) {
        if (!session.logLevel.allows(level)) return;
        session.notify({
          'jsonrpc': '2.0',
          'method': 'notifications/message',
          'params': {
            'level': level.name,
            'logger': 'moodiary',
            'data': data ?? message,
          },
        });
      },
    );
  }

  /// Tells every initialized client that one resource changed. Used by the
  /// service when the diary database emits an event.
  void resourceUpdated(String uri) {
    for (final session in _sessions.values) {
      if (!session.initialized) continue;
      session.notify({
        'jsonrpc': '2.0',
        'method': 'notifications/resources/updated',
        'params': {'uri': uri},
      });
    }
  }
}
