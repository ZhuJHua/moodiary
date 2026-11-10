import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/protocol/mcp_types.dart';
import 'package:moodiary_mcp/src/registry/mcp_registry.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/server/mcp_session.dart';

McpTool _tool(String name, {bool readOnly = true}) => McpTool(
  name: name,
  description: 'Tool $name',
  inputSchema: const {'type': 'object', 'properties': {}},
  readOnly: readOnly,
);

McpRegistry _registry({Completer<McpToolResult>? slow}) {
  final registry = McpRegistry();
  registry.addTool(_tool('echo'), (call, arguments) async {
    return McpToolResult.json({'echo': arguments['value']});
  });
  registry.addTool(_tool('fails'), (call, arguments) async {
    throw StateError('database is closed');
  });
  registry.addTool(
    _tool('slow'),
    (call, arguments) => (slow ?? Completer<McpToolResult>()).future,
  );
  registry.addTool(_tool('progress'), (call, arguments) async {
    call.reportProgress(1, total: 2, message: 'half');
    call.reportProgress(2, total: 2);
    return McpToolResult.text('done');
  });
  registry.addTool(_tool('logger'), (call, arguments) async {
    call.log(McpLogLevel.info, 'info line');
    call.log(McpLogLevel.error, 'error line', data: {'e': 1});
    return McpToolResult.text('logged');
  });
  registry.addResource(
    const McpResource(
      uri: 'moodiary://categories',
      name: 'categories',
      description: 'Every diary category',
    ),
    (call, uri) async => McpResourceReadResult.json(uri, const [
      {'id': 'a'},
    ]),
  );
  registry.addResourceTemplate(
    const McpResourceTemplate(
      uriTemplate: 'moodiary://diary/{id}',
      name: 'diary',
      description: 'One diary',
    ),
    (call, uri, variables) async {
      if (variables['id'] == 'missing') {
        throw JsonRpcException(JsonRpcCode.resourceNotFound, 'no $uri');
      }
      return McpResourceReadResult.text(uri, 'diary ${variables['id']}');
    },
  );
  registry.addPrompt(
    const McpPrompt(
      name: 'daily_review',
      description: 'Reviews a day',
      arguments: [McpPromptArgument(name: 'date', description: 'yyyy-MM-dd')],
    ),
    (call, arguments) async => McpPromptResult(
      messages: [
        McpPromptMessage.user('Review ${arguments['date'] ?? 'today'}'),
      ],
    ),
    complete: (call, argument, value) async => McpCompletionResult(
      values: [
        for (final day in const ['2026-01-01', '2026-01-02'])
          if (day.startsWith(value)) day,
      ],
    ),
  );
  return registry;
}

void main() {
  late McpServer server;
  late McpSessionState session;
  late Completer<McpToolResult> slow;
  var seq = 0;

  setUp(() {
    slow = Completer<McpToolResult>();
    server = McpServer(
      registry: _registry(slow: slow),
      serverVersion: '9.9.9',
    );
    session = server.createSession();
    seq = 0;
  });

  tearDown(() => server.dispose());

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await server.handle(session, {
      'jsonrpc': '2.0',
      'id': ++seq,
      'method': method,
      'params': params,
    });
    expect(response, isNotNull, reason: '$method must answer a request');
    return response!;
  }

  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
    Map<String, dynamic> meta = const {},
  ]) => call('tools/call', {
    'name': name,
    'arguments': arguments,
    if (meta.isNotEmpty) '_meta': meta,
  });

  group('initialize', () {
    test(
      'negotiates the newest shared version and advertises capabilities',
      () async {
        final response = await call('initialize', {
          'protocolVersion': '2025-03-26',
          'clientInfo': {'name': 'test-client', 'version': '1.0'},
          'capabilities': <String, dynamic>{},
        });
        final result = response['result'] as Map<String, dynamic>;
        expect(result['protocolVersion'], '2025-03-26');
        expect((result['serverInfo'] as Map)['name'], 'moodiary');
        expect((result['serverInfo'] as Map)['version'], '9.9.9');
        final instructions = result['instructions'] as String;
        expect(instructions, isNotEmpty);
        // The instructions have to describe the shared conventions: a model
        // reads them before it sees any tool description.
        expect(instructions, contains('contentFormat'));
        expect(instructions, contains('null'));
        expect(instructions, contains('render_diary_image'));
        final capabilities = result['capabilities'] as Map;
        expect(
          capabilities.keys,
          containsAll(<String>[
            'tools',
            'resources',
            'prompts',
            'logging',
            'completions',
          ]),
        );
        expect((capabilities['resources'] as Map)['subscribe'], isFalse);
        expect(session.protocolVersion, '2025-03-26');
        expect(session.initialized, isTrue);
      },
    );

    test('falls back to the newest version for an unknown one', () async {
      final response = await call('initialize', {'protocolVersion': '0.0.1'});
      expect(
        (response['result'] as Map)['protocolVersion'],
        mcpLatestProtocolVersion,
      );
    });

    test('ping answers an empty object', () async {
      expect((await call('ping'))['result'], isEmpty);
    });

    test('an unknown method is method not found', () async {
      final response = await call('resources/subscribe');
      final error = response['error'] as Map;
      expect(error['code'], JsonRpcCode.methodNotFound);
      expect(response.containsKey('result'), isFalse);
    });
  });

  group('tools', () {
    test('lists every tool under the tools property', () async {
      final result = (await call('tools/list'))['result'] as Map;
      final tools = (result['tools'] as List).cast<Map<String, dynamic>>();
      expect([
        for (final tool in tools) tool['name'],
      ], containsAll(<String>['echo', 'fails', 'slow', 'progress', 'logger']));
      // The catalog is frozen at a size below any page limit, so a list answer
      // carries neither a cursor nor a truncated array.
      expect(result.containsKey('nextCursor'), isFalse);
    });

    test('returns structured content for a successful call', () async {
      final response = await toolCall('echo', {'value': 42});
      final result = response['result'] as Map;
      expect(result['isError'], isFalse);
      expect(result['structuredContent'], {'echo': 42});
      expect((result['content'] as List).single, {
        'type': 'text',
        'text': '{"echo":42}',
      });
    });

    test('unknown tool is an invalid params error', () async {
      final response = await toolCall('nope');
      expect((response['error'] as Map)['code'], JsonRpcCode.invalidParams);
    });

    test(
      'a throwing tool becomes an isError result, not a protocol error',
      () async {
        final response = await toolCall('fails');
        final result = response['result'] as Map;
        expect(result['isError'], isTrue);
        expect(
          ((result['content'] as List).single as Map)['text'],
          contains('database is closed'),
        );
      },
    );

    test(
      'forwards progress notifications when the client sent a token',
      () async {
        final notifications = <Map<String, dynamic>>[];
        final sub = session.outgoing.listen(notifications.add);
        await toolCall('progress', const {}, {'progressToken': 'p-1'});
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(notifications.length, 2);
        final params = notifications.first['params'] as Map;
        expect(notifications.first['method'], 'notifications/progress');
        expect(params['progressToken'], 'p-1');
        expect(params['progress'], 1);
        expect(params['total'], 2);
      },
    );

    test('emits no progress notification without a token', () async {
      final notifications = <Map<String, dynamic>>[];
      final sub = session.outgoing.listen(notifications.add);
      await toolCall('progress');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(notifications, isEmpty);
    });

    test('logging respects the level the client set', () async {
      final notifications = <Map<String, dynamic>>[];
      final sub = session.outgoing.listen(notifications.add);
      await call('logging/setLevel', {'level': 'warning'});
      await toolCall('logger');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(notifications.length, 1);
      expect(notifications.single['method'], 'notifications/message');
      final params = notifications.single['params'] as Map;
      expect(params['level'], 'error');
      expect(params['data'], {'e': 1});
    });

    test('a cancelled request answers with the cancellation error', () async {
      final pending = server.handle(session, {
        'jsonrpc': '2.0',
        'id': 'cancel-me',
        'method': 'tools/call',
        'params': {'name': 'slow', 'arguments': <String, dynamic>{}},
      });
      await server.handle(session, {
        'jsonrpc': '2.0',
        'method': 'notifications/cancelled',
        'params': {'requestId': 'cancel-me', 'reason': 'user aborted'},
      });
      expect(session.isCancelled('cancel-me'), isTrue);
      slow.complete(McpToolResult.text('too late'));
      final response = await pending;
      expect((response!['error'] as Map)['code'], JsonRpcCode.requestCancelled);
      expect(session.isCancelled('cancel-me'), isFalse);
    });
  });

  group('resources', () {
    test('lists static resources and templates', () async {
      final resources = (await call('resources/list'))['result'] as Map;
      expect((resources['resources'] as List).single, {
        'uri': 'moodiary://categories',
        'name': 'categories',
        'description': 'Every diary category',
      });
      final templates =
          (await call('resources/templates/list'))['result'] as Map;
      expect((templates['resourceTemplates'] as List).single, {
        'uriTemplate': 'moodiary://diary/{id}',
        'name': 'diary',
        'description': 'One diary',
      });
    });

    test('reads a static resource as json', () async {
      final result =
          (await call('resources/read', {
                'uri': 'moodiary://categories',
              }))['result']
              as Map;
      final content = (result['contents'] as List).single as Map;
      expect(content['uri'], 'moodiary://categories');
      expect(content['mimeType'], 'application/json');
      expect(content['text'], contains('"id": "a"'));
    });

    test('reads a template resource', () async {
      final result =
          (await call('resources/read', {
                'uri': 'moodiary://diary/abc',
              }))['result']
              as Map;
      expect(((result['contents'] as List).single as Map)['text'], 'diary abc');
    });

    test('an unknown uri is resource not found', () async {
      final response = await call('resources/read', {'uri': 'moodiary://nope'});
      expect((response['error'] as Map)['code'], JsonRpcCode.resourceNotFound);
    });

    test('a handler error propagates its code', () async {
      final response = await call('resources/read', {
        'uri': 'moodiary://diary/missing',
      });
      expect((response['error'] as Map)['code'], JsonRpcCode.resourceNotFound);
    });

    test('resourceUpdated reaches initialized sessions only', () async {
      final notifications = <Map<String, dynamic>>[];
      final sub = session.outgoing.listen(notifications.add);
      server.resourceUpdated('moodiary://stats/overview');
      await call('initialize', {'protocolVersion': mcpLatestProtocolVersion});
      server.resourceUpdated('moodiary://categories');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(notifications.length, 1);
      expect(notifications.single['method'], 'notifications/resources/updated');
      expect(
        (notifications.single['params'] as Map)['uri'],
        'moodiary://categories',
      );
    });
  });

  group('prompts and completions', () {
    test('lists prompts and renders one', () async {
      final list = (await call('prompts/list'))['result'] as Map;
      final prompt = (list['prompts'] as List).single as Map;
      expect(prompt['name'], 'daily_review');
      expect((prompt['arguments'] as List).single, {
        'name': 'date',
        'description': 'yyyy-MM-dd',
        'required': false,
      });
      final result =
          (await call('prompts/get', {
                'name': 'daily_review',
                'arguments': {'date': '2026-01-02'},
              }))['result']
              as Map;
      final message = (result['messages'] as List).single as Map;
      expect(message['role'], 'user');
      expect((message['content'] as Map)['text'], 'Review 2026-01-02');
    });

    test('an unknown prompt is invalid params', () async {
      final response = await call('prompts/get', {'name': 'nope'});
      expect((response['error'] as Map)['code'], JsonRpcCode.invalidParams);
    });

    test('completes prompt arguments', () async {
      final response = await call('completion/complete', {
        'ref': {'type': 'ref/prompt', 'name': 'daily_review'},
        'argument': {'name': 'date', 'value': '2026-01-0'},
      });
      final completion = (response['result'] as Map)['completion'] as Map;
      expect(completion['values'], ['2026-01-01', '2026-01-02']);
    });

    test('answers empty completions for unknown refs', () async {
      final response = await call('completion/complete', {
        'ref': {'type': 'ref/resource', 'uri': 'moodiary://diary/{id}'},
        'argument': {'name': 'id', 'value': 'a'},
      });
      expect(
        ((response['result'] as Map)['completion'] as Map)['values'],
        isEmpty,
      );
    });
  });

  // The property names are part of the protocol, not formatting: a client reads
  // `tools` off a `tools/list` result and throws "type 'Null' is not a subtype
  // of type 'List<dynamic>'" when the server answers a generic wrapper instead.
  group('list result shapes', () {
    test('every list endpoint names its array as the schema does', () async {
      const expected = <String, String>{
        'tools/list': 'tools',
        'resources/list': 'resources',
        'resources/templates/list': 'resourceTemplates',
        'prompts/list': 'prompts',
      };
      for (final entry in expected.entries) {
        final result =
            (await call(entry.key))['result'] as Map<String, dynamic>;
        expect(result.keys, contains(entry.value), reason: entry.key);
        expect(result.keys, isNot(contains('items')), reason: entry.key);
        expect(result[entry.value], isA<List<dynamic>>(), reason: entry.key);
      }
    });
  });

  group('session lifecycle', () {
    test('notifications never get a response frame', () async {
      final response = await server.handle(session, {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      expect(response, isNull);
    });

    test('disposing a session closes its stream', () async {
      var closed = false;
      session.outgoing.listen(null, onDone: () => closed = true);
      server.disposeSession(session.id);
      await Future<void>.delayed(Duration.zero);
      expect(server.session(session.id), isNull);
      expect(closed, isTrue);
      expect(session.isDisposed, isTrue);
    });

    test('prunes idle sessions and reports their ids', () async {
      final idle = server.createSession()
        ..lastSeen = DateTime.now().subtract(const Duration(hours: 1));
      expect(server.pruneIdleSessions(const Duration(minutes: 30)), [idle.id]);
      expect(server.session(idle.id), isNull);
      expect(idle.isDisposed, isTrue);
      expect(server.pruneIdleSessions(const Duration(minutes: 30)), isEmpty);
    });

    test('evicts the oldest session at the limit', () async {
      final bounded = McpServer(
        registry: _registry(),
        serverVersion: '9.9.9',
        maxSessions: 2,
      );
      addTearDown(bounded.dispose);
      final first = bounded.createSession();
      bounded.createSession();
      bounded.createSession();
      expect(bounded.session(first.id), isNull);
      expect(first.isDisposed, isTrue);
    });
  });
}
