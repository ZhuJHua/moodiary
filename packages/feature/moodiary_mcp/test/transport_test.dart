import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/protocol/mcp_types.dart';
import 'package:moodiary_mcp/src/registry/mcp_registry.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/transport/http_auth.dart';
import 'package:moodiary_mcp/src/transport/io_mcp_transport.dart';
import 'package:moodiary_mcp/src/transport/transport.dart';

const String _token = 'test-token-0123456789';

McpRegistry _registry() {
  final registry = McpRegistry();
  registry.addTool(
    const McpTool(
      name: 'echo',
      description: 'echoes',
      inputSchema: {
        'type': 'object',
        'properties': {
          'value': {'type': 'string'},
        },
      },
      readOnly: true,
    ),
    (call, arguments) async => McpToolResult.json({'echo': arguments['value']}),
  );
  registry.addTool(
    const McpTool(
      name: 'progress',
      description: 'reports progress',
      inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
      readOnly: true,
    ),
    (call, arguments) async {
      call.reportProgress(1, total: 2);
      return McpToolResult.text('done');
    },
  );
  registry.addResource(
    const McpResource(
      uri: 'moodiary://ping',
      name: 'ping',
      description: 'Answers pong',
    ),
    (call, uri) async => McpResourceReadResult.text(uri, 'pong'),
  );
  return registry;
}

class _Harness {
  _Harness(this.transport, this.server);

  final IoMcpTransport transport;
  final McpServer server;
  final HttpClient client = HttpClient();

  Uri get mcp => Uri.parse('http://127.0.0.1:${transport.port}/mcp');

  Uri get sse => Uri.parse('http://127.0.0.1:${transport.port}/sse');

  Uri get icon => Uri.parse('http://127.0.0.1:${transport.port}/icon.png');

  Uri messages(String sessionId) => Uri.parse(
    'http://127.0.0.1:${transport.port}/messages?sessionId=$sessionId',
  );

  Future<void> close() async {
    client.close(force: true);
    await transport.stop();
    server.dispose();
  }

  /// [send] for a body that is not text, such as the PNG icon.
  Future<({int status, Map<String, String> headers, List<int> bytes})> sendRaw(
    String method,
    Uri uri, {
    String? token = _token,
    Map<String, String> extraHeaders = const {},
  }) async {
    final request = await client.openUrl(method, uri);
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    extraHeaders.forEach(request.headers.set);
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    final headers = <String, String>{};
    response.headers.forEach(
      (name, values) => headers[name] = values.join(','),
    );
    return (status: response.statusCode, headers: headers, bytes: bytes);
  }

  Future<({int status, Map<String, String> headers, String body})> send(
    String method,
    Uri uri,
    Object? body, {
    String? token = _token,
    String? sessionId,
    Map<String, String> extraHeaders = const {},
  }) async {
    final request = await client.openUrl(method, uri);
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    if (sessionId != null) request.headers.set('mcp-session-id', sessionId);
    extraHeaders.forEach(request.headers.set);
    if (body != null) {
      final text = body is String ? body : jsonEncode(body);
      request.headers.contentType = ContentType.json;
      request.write(text);
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final headers = <String, String>{};
    response.headers.forEach(
      (name, values) => headers[name] = values.join(','),
    );
    return (status: response.statusCode, headers: headers, body: text);
  }

  Future<({int status, String body})> post(
    Map<String, dynamic> message, {
    String? sessionId,
  }) async {
    final response = await send('POST', mcp, message, sessionId: sessionId);
    return (status: response.status, body: response.body);
  }
}

Future<_Harness> _start({
  bool allowLan = false,
  bool requireToken = true,
  String token = _token,
}) async {
  final transport = IoMcpTransport();
  final server = McpServer(registry: _registry(), serverVersion: 'test');
  await transport.start(
    McpTransportConfig(
      port: 0,
      allowLan: allowLan,
      token: token,
      requireToken: requireToken,
    ),
    server,
  );
  final harness = _Harness(transport, server);
  addTearDown(harness.close);
  return harness;
}

/// Reads `data:` lines from one HTTP event stream.
///
/// A response body can only be listened to once, so every wait shares one
/// iterator; the events a wait did not consume stay buffered in it.
class _SseLines {
  _SseLines(Stream<List<int>> body)
    : _lines = StreamIterator(
        body.transform(utf8.decoder).transform(const LineSplitter()),
      );

  final StreamIterator<String> _lines;

  /// The payload of the next event whose `data:` line satisfies [test].
  Future<String> next(bool Function(String data) test) =>
      _next(test).timeout(const Duration(seconds: 10));

  Future<String> _next(bool Function(String data) test) async {
    while (await _lines.moveNext()) {
      final line = _lines.current;
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (test(data)) return data;
    }
    throw StateError('stream closed before the event arrived');
  }

  Future<void> close() => _lines.cancel();
}

/// Writes one raw HTTP/1.1 request and returns the response text.
///
/// `HttpClient` always sends the URI host in `Host`, and these tests need a
/// spoofed authority to model a DNS-rebinding page, so the exchange goes over a
/// plain socket. The request asks for `Connection: close`; the read also stops
/// after a timeout, because the caller only needs what already arrived.
Future<String> _rawExchange(IoMcpTransport transport, String request) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    transport.port,
  );
  final buffer = StringBuffer();
  final lines = StreamIterator(
    utf8.decoder.bind(socket).transform(const LineSplitter()),
  );
  try {
    socket.write(request);
    await socket.flush();
    while (await lines.moveNext().timeout(
      const Duration(seconds: 5),
      onTimeout: () => false,
    )) {
      buffer.writeln(lines.current);
    }
  } finally {
    await lines.cancel();
    socket.destroy();
  }
  return buffer.toString();
}

void main() {
  group('authentication and origin checks', () {
    test('rejects a request without the bearer token', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, token: null);
      expect(response.status, HttpStatus.unauthorized);
      expect(response.headers['www-authenticate'], contains('Bearer'));
    });

    test('rejects a wrong bearer token', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, token: 'nope');
      expect(response.status, HttpStatus.unauthorized);
    });

    test('rejects a foreign origin', () async {
      final harness = await _start();
      final response = await harness.send(
        'POST',
        harness.mcp,
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        extraHeaders: {'origin': 'https://evil.example'},
      );
      expect(response.status, HttpStatus.forbidden);
    });

    test('accepts a loopback origin', () async {
      final harness = await _start();
      final response = await harness.send(
        'POST',
        harness.mcp,
        {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {'protocolVersion': mcpLatestProtocolVersion},
        },
        extraHeaders: {'origin': 'http://localhost:3000'},
      );
      expect(response.status, HttpStatus.ok);
      expect(response.headers['access-control-allow-origin'], isNotNull);
    });

    test('answers the CORS preflight without a token', () async {
      final harness = await _start();
      final response = await harness.send(
        'OPTIONS',
        harness.mcp,
        null,
        token: null,
        extraHeaders: {'origin': 'http://localhost:5173'},
      );
      expect(response.status, HttpStatus.noContent);
      expect(response.headers['access-control-allow-origin'], isNotNull);
      expect(
        response.headers['access-control-allow-headers'],
        contains('Mcp-Session-Id'),
      );
    });
  });

  group('origin policy', () {
    test('allows loopback origins on any port', () {
      expect(isAllowedOrigin('http://localhost:3000'), isTrue);
      expect(isAllowedOrigin('https://127.0.0.1:8765'), isTrue);
      expect(isAllowedOrigin('http://[::1]:9000'), isTrue);
    });

    test('rejects a non-loopback origin even when it matches the host', () {
      // A DNS-rebinding page is served from the attacker's name, which is
      // exactly the Host header it sends: the pair must not be accepted.
      expect(isAllowedOrigin('http://rebind.example:8765'), isFalse);
      expect(isAllowedOrigin('null'), isFalse);
      expect(isAllowedOrigin(''), isFalse);
      expect(isAllowedOrigin('ftp://localhost'), isFalse);
    });

    test('rejects a same-authority non-loopback origin over HTTP', () async {
      final harness = await _start();
      final authority = 'rebind.example:${harness.transport.port}';
      final response = await _rawExchange(
        harness.transport,
        [
          'POST /mcp HTTP/1.1',
          'Host: $authority',
          'Origin: http://$authority',
          'Authorization: Bearer $_token',
          'Content-Type: application/json',
          'Content-Length: 2',
          'Connection: close',
          '',
          '{}',
        ].join('\r\n'),
      );
      expect(response, contains('403'));
    });

    test('refuses a declared body above the transport limit', () async {
      final harness = await _start();
      final response = await _rawExchange(
        harness.transport,
        [
          'POST /mcp HTTP/1.1',
          'Host: 127.0.0.1:${harness.transport.port}',
          'Authorization: Bearer $_token',
          'Content-Type: application/json',
          'Content-Length: ${25 * 1024 * 1024}',
          'Connection: close',
          '',
          '',
        ].join('\r\n'),
      );
      expect(response, contains('413'));
      expect(response, contains('24 MiB'));
    });
  });

  group('optional bearer token', () {
    test('GET /mcp skips the auth gate when no token is required', () async {
      final harness = await _start(requireToken: false, token: '');
      final response = await harness.send(
        'GET',
        harness.mcp,
        null,
        token: null,
      );
      // Authentication is off, so the missing session id is what the transport
      // complains about, not the missing Authorization header.
      expect(response.status, HttpStatus.badRequest);
      expect(response.headers['www-authenticate'], isNull);
    });

    test('GET /mcp still needs the token when it is required', () async {
      final harness = await _start();
      final response = await harness.send(
        'GET',
        harness.mcp,
        null,
        token: null,
      );
      expect(response.status, HttpStatus.unauthorized);
      expect(response.headers['www-authenticate'], contains('Bearer'));
    });

    test('a whole session works without a token', () async {
      final harness = await _start(requireToken: false, token: '');
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      }, token: null);
      expect(init.status, HttpStatus.ok);
      final sessionId = init.headers['mcp-session-id'];
      expect(sessionId, isNotNull);
      final response = await harness.send(
        'POST',
        harness.mcp,
        {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 'echo',
            'arguments': {'value': 'hi'},
          },
        },
        token: null,
        sessionId: sessionId,
      );
      expect(response.status, HttpStatus.ok);
      final frame = jsonDecode(response.body) as Map<String, dynamic>;
      expect((frame['result'] as Map)['structuredContent'], {'echo': 'hi'});
    });

    test('the origin policy still applies without a token', () async {
      final harness = await _start(requireToken: false, token: '');
      final response = await harness.send(
        'POST',
        harness.mcp,
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        token: null,
        extraHeaders: {'origin': 'https://evil.example'},
      );
      expect(response.status, HttpStatus.forbidden);
    });

    test('LAN access without a token is refused', () async {
      final transport = IoMcpTransport();
      final server = McpServer(registry: _registry(), serverVersion: 'test');
      addTearDown(server.dispose);
      await expectLater(
        transport.start(
          const McpTransportConfig(
            port: 0,
            allowLan: true,
            token: '',
            requireToken: false,
          ),
          server,
        ),
        throwsArgumentError,
      );
      expect(transport.port, 0);
      expect(transport.endpoints, isEmpty);
    });
  });

  group('server icon', () {
    const pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    test('GET /icon.png answers the PNG without a token', () async {
      final harness = await _start();
      final response = await harness.sendRaw('GET', harness.icon, token: null);
      expect(response.status, HttpStatus.ok);
      expect(response.headers['content-type'], startsWith('image/png'));
      expect(response.bytes.take(8).toList(), pngSignature);
      expect(
        int.parse(response.headers['content-length']!),
        response.bytes.length,
      );
      expect(response.headers['cache-control'], contains('max-age=3600'));
    });

    test('HEAD /icon.png answers the headers without a body', () async {
      final harness = await _start();
      final response = await harness.sendRaw('HEAD', harness.icon, token: null);
      expect(response.status, HttpStatus.ok);
      expect(response.headers['content-type'], startsWith('image/png'));
      expect(int.parse(response.headers['content-length']!), greaterThan(0));
      expect(response.bytes, isEmpty);
    });

    test('the origin policy still applies to the icon', () async {
      final harness = await _start();
      final response = await harness.sendRaw(
        'GET',
        harness.icon,
        token: null,
        extraHeaders: {'origin': 'https://evil.example'},
      );
      expect(response.status, HttpStatus.forbidden);
    });

    test('initialize advertises the icon and the website', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      expect(response.status, HttpStatus.ok);
      final result = (jsonDecode(response.body) as Map)['result'] as Map;
      final serverInfo = result['serverInfo'] as Map;
      expect(serverInfo['websiteUrl'], 'https://github.com/ZhuJHua/moodiary');
      final icon = (serverInfo['icons'] as List).single as Map;
      expect(
        icon['src'],
        'http://127.0.0.1:${harness.transport.port}/icon.png',
      );
      expect(icon['mimeType'], 'image/png');
      expect(icon['sizes'], ['512x512']);
    });

    test('the legacy initialize answer carries the same icon', () async {
      final harness = await _start();
      final request = await harness.client.getUrl(harness.sse);
      request.headers.set('authorization', 'Bearer $_token');
      request.headers.set('accept', 'text/event-stream');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final events = _SseLines(response);
      addTearDown(events.close);
      final endpoint = await events.next(
        (data) => data.contains('/messages?sessionId='),
      );
      final sessionId = Uri.parse(endpoint).queryParameters['sessionId']!;
      final posted = await harness.send('POST', harness.messages(sessionId), {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2024-11-05'},
      });
      expect(posted.status, HttpStatus.accepted);
      final frame = jsonDecode(
        await events.next((data) => data.contains('"icons"')),
      ) as Map<String, dynamic>;
      final serverInfo = (frame['result'] as Map)['serverInfo'] as Map;
      final icon = (serverInfo['icons'] as List).single as Map;
      expect(icon['src'], endsWith('/icon.png'));
      expect(icon['mimeType'], 'image/png');
    });
  });

  group('Streamable HTTP', () {
    test('initialize creates a session and reports the capabilities', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': mcpLatestProtocolVersion,
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'transport-test', 'version': '1.0'},
        },
      });
      expect(response.status, HttpStatus.ok);
      final sessionId = response.headers['mcp-session-id'];
      expect(sessionId, isNotNull);
      expect(sessionId, startsWith('moodiary-'));
      expect(
        RegExp(r'^moodiary-[A-Za-z0-9_-]{43}$').hasMatch(sessionId),
        isTrue,
      );
      final frame = jsonDecode(response.body) as Map<String, dynamic>;
      final result = frame['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], mcpLatestProtocolVersion);
      expect((result['capabilities'] as Map).keys, contains('tools'));
      expect(harness.server.session(sessionId), isNotNull);
    });

    test('lists tools for a known session', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final sessionId = init.headers['mcp-session-id'];
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      }, sessionId: sessionId);
      expect(response.status, HttpStatus.ok);
      final frame = jsonDecode(response.body) as Map<String, dynamic>;
      final tools = (frame['result'] as Map)['tools'] as List;
      expect([
        for (final tool in tools) (tool as Map)['name'],
      ], containsAll(<String>['echo', 'progress']));
    });

    test('calls a tool over the session', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final sessionId = init.headers['mcp-session-id'];
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/call',
        'params': {
          'name': 'echo',
          'arguments': {'value': 'hi'},
        },
      }, sessionId: sessionId);
      final frame = jsonDecode(response.body) as Map<String, dynamic>;
      expect((frame['result'] as Map)['structuredContent'], {'echo': 'hi'});
    });

    test('a notification is accepted with 202 and no body', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }, sessionId: init.headers['mcp-session-id']);
      expect(response.status, HttpStatus.accepted);
      expect(response.body, isEmpty);
    });

    test('a request without a session is rejected once initialized', () async {
      final harness = await _start();
      final response = await harness.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      });
      expect(response.status, HttpStatus.badRequest);
    });

    test('an unknown session is a 404', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, sessionId: 'not-a-session');
      expect(response.status, HttpStatus.notFound);
    });

    test('DELETE ends the session', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final sessionId = init.headers['mcp-session-id']!;
      final deleted = await harness.send(
        'DELETE',
        harness.mcp,
        null,
        sessionId: sessionId,
      );
      expect(deleted.status, HttpStatus.ok);
      final after = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'ping',
      }, sessionId: sessionId);
      expect(after.status, HttpStatus.notFound);
    });

    test('malformed JSON answers a JSON-RPC parse error', () async {
      final harness = await _start();
      final response = await harness.send('POST', harness.mcp, '{not json');
      expect(response.status, HttpStatus.badRequest);
      final frame = jsonDecode(response.body) as Map<String, dynamic>;
      expect((frame['error'] as Map)['code'], -32700);
    });

    test('an unsupported protocol version header is rejected', () async {
      final harness = await _start();
      final response = await harness.send(
        'POST',
        harness.mcp,
        {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'},
        extraHeaders: {'mcp-protocol-version': '1999-01-01'},
      );
      expect(response.status, HttpStatus.badRequest);
    });

    test('GET and DELETE validate the protocol version header', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final sessionId = init.headers['mcp-session-id']!;
      const supported = {'mcp-protocol-version': mcpLatestProtocolVersion};
      // A stale client must not be able to open or end a session under a
      // version the server never negotiated.
      for (final method in ['GET', 'DELETE']) {
        final rejected = await harness.send(
          method,
          harness.mcp,
          null,
          sessionId: sessionId,
          extraHeaders: {'mcp-protocol-version': '1999-01-01'},
        );
        expect(rejected.status, HttpStatus.badRequest, reason: method);
        final frame = jsonDecode(rejected.body) as Map<String, dynamic>;
        expect(
          (frame['error'] as Map)['code'],
          JsonRpcCode.invalidRequest,
          reason: method,
        );
        expect(
          (frame['error'] as Map)['message'],
          contains('MCP-Protocol-Version'),
          reason: method,
        );
      }
      // The rejected calls did not touch the session, and a supported version
      // still opens the stream.
      final request = await harness.client.getUrl(harness.mcp);
      request.headers.set('authorization', 'Bearer $_token');
      request.headers.set('mcp-session-id', sessionId);
      request.headers.set('accept', 'text/event-stream');
      supported.forEach(request.headers.set);
      final opened = await request.close();
      expect(opened.statusCode, HttpStatus.ok);
      expect(opened.headers.contentType?.mimeType, 'text/event-stream');
      final deleted = await harness.send(
        'DELETE',
        harness.mcp,
        null,
        sessionId: sessionId,
        extraHeaders: supported,
      );
      expect(deleted.status, HttpStatus.ok);
    });

    test(
      'a JSON-only client gets the frame without the notifications',
      () async {
        final harness = await _start();
        final init = await harness.send('POST', harness.mcp, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {'protocolVersion': mcpLatestProtocolVersion},
        });
        final response = await harness.send(
          'POST',
          harness.mcp,
          {
            'jsonrpc': '2.0',
            'id': 2,
            'method': 'tools/call',
            'params': {
              'name': 'progress',
              'arguments': <String, dynamic>{},
              '_meta': {'progressToken': 'p-1'},
            },
          },
          sessionId: init.headers['mcp-session-id'],
          extraHeaders: {'accept': 'application/json'},
        );
        expect(response.status, HttpStatus.ok);
        // A client that did not accept an event stream cannot parse one, so it
        // gets the single JSON frame and the progress notification is dropped.
        expect(
          response.headers['content-type'],
          startsWith('application/json'),
        );
        expect(response.body, isNot(contains('notifications/progress')));
        final frame = jsonDecode(response.body) as Map<String, dynamic>;
        expect(frame['id'], 2);
        expect(((frame['result'] as Map)['content'] as List).single, {
          'type': 'text',
          'text': 'done',
        });
      },
    );

    test('an event stream client still gets the notifications', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final response = await harness.send(
        'POST',
        harness.mcp,
        {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 'progress',
            'arguments': <String, dynamic>{},
            '_meta': {'progressToken': 'p-1'},
          },
        },
        sessionId: init.headers['mcp-session-id'],
        extraHeaders: {'accept': 'application/json, text/event-stream'},
      );
      expect(response.status, HttpStatus.ok);
      expect(response.headers['content-type'], startsWith('text/event-stream'));
      expect(response.body, contains('"method":"notifications/progress"'));
      expect(response.body, contains('"id":2'));
    });

    test('a non JSON content type is rejected', () async {
      final harness = await _start();
      final request = await harness.client.openUrl('POST', harness.mcp);
      request.headers.set('authorization', 'Bearer $_token');
      request.headers.contentType = ContentType.text;
      request.write('{"jsonrpc":"2.0","id":1,"method":"ping"}');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.unsupportedMediaType);
    });

    test('an unsupported method on /mcp is 405 with Allow', () async {
      final harness = await _start();
      final response = await harness.send('PUT', harness.mcp, null);
      expect(response.status, HttpStatus.methodNotAllowed);
      expect(response.headers['allow'], contains('POST'));
    });

    test('the SSE stream carries server notifications', () async {
      final harness = await _start();
      final init = await harness.send('POST', harness.mcp, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      final sessionId = init.headers['mcp-session-id']!;
      final request = await harness.client.getUrl(harness.mcp);
      request.headers.set('authorization', 'Bearer $_token');
      request.headers.set('mcp-session-id', sessionId);
      request.headers.set('accept', 'text/event-stream');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/event-stream');
      final events = _SseLines(response);
      addTearDown(events.close);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      harness.server.resourceUpdated('moodiary://ping');
      final data = await events.next(
        (data) => data.contains('notifications/resources/updated'),
      );
      expect(
        jsonDecode(data),
        containsPair('method', 'notifications/resources/updated'),
      );
    });

    test('GET /mcp without a session is rejected', () async {
      final harness = await _start();
      final response = await harness.send('GET', harness.mcp, null);
      expect(response.status, HttpStatus.badRequest);
    });

    test('exposes a loopback endpoint', () async {
      final harness = await _start();
      expect(harness.transport.port, greaterThan(0));
      expect(harness.transport.endpoints, isNotEmpty);
      expect(
        harness.transport.endpoints.first.toString(),
        'http://127.0.0.1:${harness.transport.port}/mcp',
      );
    });
  });

  group('legacy HTTP+SSE', () {
    test('serves the endpoint event and answers over the stream', () async {
      final harness = await _start();
      final request = await harness.client.getUrl(harness.sse);
      request.headers.set('authorization', 'Bearer $_token');
      request.headers.set('accept', 'text/event-stream');
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      final events = _SseLines(response);
      addTearDown(events.close);
      final endpoint = await events.next(
        (data) => data.contains('/messages?sessionId='),
      );
      expect(endpoint, contains('/messages?sessionId='));
      final sessionId = Uri.parse(endpoint).queryParameters['sessionId']!;
      final posted = await harness.send('POST', harness.messages(sessionId), {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': mcpLatestProtocolVersion},
      });
      expect(posted.status, HttpStatus.accepted);
      final frame = jsonDecode(
        await events.next((data) => data.contains('"protocolVersion"')),
      ) as Map<String, dynamic>;
      expect((frame['result'] as Map)['protocolVersion'], isNotNull);
    });

    test('POST /messages without a session is rejected', () async {
      final harness = await _start();
      final response = await harness.send(
        'POST',
        Uri.parse('http://127.0.0.1:${harness.transport.port}/messages'),
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
      );
      expect(response.status, HttpStatus.badRequest);
    });
  });

  group('stop', () {
    test('is safe to call twice and closes the port', () async {
      final transport = IoMcpTransport();
      final server = McpServer(registry: _registry(), serverVersion: 'test');
      await transport.start(
        const McpTransportConfig(
          port: 0,
          allowLan: false,
          token: _token,
          requireToken: true,
        ),
        server,
      );
      final port = transport.port;
      await transport.stop();
      await transport.stop();
      expect(transport.endpoints, isEmpty);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      await expectLater(
        Future(() async {
          final request = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port/mcp'),
          );
          await request.close();
        }),
        throwsA(isA<SocketException>()),
      );
      server.dispose();
    });
  });
}
