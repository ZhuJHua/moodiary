import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/protocol/mcp_types.dart';
import 'package:moodiary_mcp/src/registry/mcp_registry.dart';

void main() {
  group('JSON-RPC 2.0 framing', () {
    test('decodes a request with an integer id', () {
      final request = parseJsonRpc({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'ping',
      });
      expect(request, isNotNull);
      expect(request!.id, 7);
      expect(request.method, 'ping');
      expect(request.params, isEmpty);
      expect(request.isNotification, isFalse);
    });

    test('decodes a notification (no id)', () {
      final request = parseJsonRpc({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      expect(request!.isNotification, isTrue);
      expect(request.params, isEmpty);
    });

    test('copies the params map instead of aliasing it', () {
      final params = <String, dynamic>{'a': 1};
      final request = parseJsonRpc({
        'jsonrpc': '2.0',
        'id': 'x',
        'method': 'tools/call',
        'params': params,
      });
      params['b'] = 2;
      expect(request!.params, {'a': 1});
    });

    test('drops a response frame instead of answering it', () {
      expect(parseJsonRpc({'jsonrpc': '2.0', 'id': 1, 'result': {}}), isNull);
      expect(
        parseJsonRpc({
          'jsonrpc': '2.0',
          'id': 1,
          'error': {'code': -32601, 'message': 'nope'},
        }),
        isNull,
      );
    });

    test('rejects malformed frames with invalid request', () {
      for (final bad in <Object?>[
        null,
        'ping',
        <String, dynamic>{'id': 1, 'method': 'ping'},
        <String, dynamic>{'jsonrpc': '1.0', 'id': 1, 'method': 'ping'},
        <String, dynamic>{'jsonrpc': '2.0', 'id': 1},
        <String, dynamic>{'jsonrpc': '2.0', 'id': 1, 'method': ''},
        <String, dynamic>{'jsonrpc': '2.0', 'id': 1.5, 'method': 'ping'},
        <String, dynamic>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
          'params': [1, 2],
        },
      ]) {
        expect(
          () => parseJsonRpc(bad),
          throwsA(
            isA<JsonRpcException>().having(
              (e) => e.code,
              'code',
              anyOf(JsonRpcCode.invalidRequest, JsonRpcCode.invalidParams),
            ),
          ),
          reason: '$bad',
        );
      }
    });

    test('builds result and error frames', () {
      expect(jsonRpcResult(3, const {'ok': true}), {
        'jsonrpc': '2.0',
        'id': 3,
        'result': {'ok': true},
      });
      final failure = jsonRpcFailure(
        null,
        const JsonRpcException(JsonRpcCode.parseError, 'bad json'),
      );
      expect(failure['id'], isNull);
      expect(failure['error'], {
        'code': JsonRpcCode.parseError,
        'message': 'bad json',
      });
      final withData = jsonRpcFailure(
        'a',
        const JsonRpcException(
          JsonRpcCode.resourceNotFound,
          'missing',
          data: {'uri': 'moodiary://diary/1'},
        ),
      );
      expect((withData['error'] as Map)['data'], {'uri': 'moodiary://diary/1'});
    });
  });

  group('protocol negotiation', () {
    test('accepts every advertised version', () {
      for (final version in mcpSupportedProtocolVersions) {
        expect(negotiateProtocolVersion(version), version);
      }
    });

    test('falls back to the newest version for unknown input', () {
      expect(negotiateProtocolVersion(null), mcpLatestProtocolVersion);
      expect(negotiateProtocolVersion('1999-01-01'), mcpLatestProtocolVersion);
      expect(negotiateProtocolVersion(42), mcpLatestProtocolVersion);
    });
  });

  group('descriptor JSON', () {
    test('tools carry their annotations and omit empty optional fields', () {
      const tool = McpTool(
        name: 'list_diaries',
        description: 'Lists diaries',
        inputSchema: {'type': 'object'},
        readOnly: true,
        idempotent: true,
      );
      final json = tool.toJson();
      expect(json['name'], 'list_diaries');
      expect(json.containsKey('title'), isFalse);
      expect(json.containsKey('outputSchema'), isFalse);
      expect(json['annotations'], {
        'readOnlyHint': true,
        'destructiveHint': false,
        'idempotentHint': true,
        'openWorldHint': false,
      });
    });

    test('a structured result keeps text content and structuredContent', () {
      final result = McpToolResult.json(const {'total': 2});
      final json = result.toJson();
      expect(json['isError'], isFalse);
      expect(json['structuredContent'], {'total': 2});
      expect((json['content'] as List).single, {
        'type': 'text',
        'text': '{"total":2}',
      });
    });
  });

  group('resource templates', () {
    const template = McpResourceTemplate(
      uriTemplate: 'moodiary://diary/{id}',
      name: 'diary',
    );

    test('matches and decodes variables', () {
      expect(template.match('moodiary://diary/abc'), {'id': 'abc'});
      expect(template.match('moodiary://diary/a%20b'), {'id': 'a b'});
    });

    test('rejects other shapes', () {
      expect(template.match('moodiary://diary'), isNull);
      expect(template.match('moodiary://diary/1/2'), isNull);
      expect(template.match('moodiary://categories'), isNull);
    });
  });

  group('cursor pagination', () {
    final registry = McpRegistry();
    final items = [for (var i = 0; i < mcpPageSize * 2 + 3; i++) i];

    test('returns a full first page and a cursor', () {
      final page = registry.page(items, null);
      expect(page.items.length, mcpPageSize);
      expect(page.nextCursor, '$mcpPageSize');
    });

    test('walks to the last page without a cursor', () {
      var cursor = null as String?;
      final seen = <int>[];
      var rounds = 0;
      do {
        final page = registry.page(items, cursor);
        seen.addAll(page.items);
        cursor = page.nextCursor;
        rounds++;
      } while (cursor != null && rounds < 10);
      expect(seen, items);
      expect(rounds, 3);
    });

    test('rejects a nonsense cursor', () {
      expect(
        () => registry.page(items, 'abc'),
        throwsA(isA<JsonRpcException>()),
      );
      expect(
        () => registry.page(items, '-1'),
        throwsA(isA<JsonRpcException>()),
      );
    });
  });

  group('registry lookups', () {
    test('prefers a static resource over a template', () {
      final registry = McpRegistry();
      registry.addResource(
        const McpResource(uri: 'moodiary://diary/fixed', name: 'fixed'),
        (call, uri) async => McpResourceReadResult.text(uri, 'static'),
      );
      registry.addResourceTemplate(
        const McpResourceTemplate(
          uriTemplate: 'moodiary://diary/{id}',
          name: 'diary',
        ),
        (call, uri, variables) async =>
            McpResourceReadResult.text(uri, 'template ${variables['id']}'),
      );
      expect(registry.resolveResource('moodiary://diary/fixed'), isNotNull);
      expect(registry.resolveResource('moodiary://diary/other'), isNotNull);
      expect(registry.resolveResource('moodiary://nope'), isNull);
    });

    test('refuses duplicate names', () {
      final registry = McpRegistry();
      const tool = McpTool(
        name: 't',
        description: 'd',
        inputSchema: {'type': 'object'},
      );
      registry.addTool(tool, (call, args) async => McpToolResult.text('ok'));
      expect(
        () => registry.addTool(
          tool,
          (call, args) async => McpToolResult.text(''),
        ),
        throwsArgumentError,
      );
    });
  });
}
