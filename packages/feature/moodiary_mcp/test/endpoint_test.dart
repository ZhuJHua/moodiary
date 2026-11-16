import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_mcp/src/tools/register_moodiary_tools.dart';
import 'package:moodiary_mcp/src/transport/mcp_http_endpoint.dart';
import 'package:moodiary_mcp/src/transport/server_icon.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

import 'support.dart';

const initializeBody =
    '{"jsonrpc":"2.0","id":1,"method":"initialize",'
    '"params":{"protocolVersion":"2025-06-18","capabilities":{},'
    '"clientInfo":{"name":"test","version":"1"}}}';

void main() {
  late MoodiaryDatabase db;
  late McpHttpEndpoint endpoint;
  late HttpClient http;
  late DateTime now;
  InternetAddress? remoteAddress;
  final servers = <McpServer>[];

  setUpAll(() {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    getIt.registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
  });

  tearDownAll(getIt.reset);

  setUp(() async {
    now = DateTime.utc(2026);
    remoteAddress = InternetAddress.loopbackIPv4;
    servers.clear();
    getIt<IKVStorage>().clear();
    await getIt<ISecureKVStorage>().clear();
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    final diaries = DiaryRepository(db);
    await diaries.insertADiary(makeDiary('one', 'A sunny afternoon'));
    endpoint = McpHttpEndpoint(
      now: () => now,
      listLanHosts: () async => ['192.168.1.2'],
      remoteAddress: (_) => remoteAddress,
      serverFactory: (iconUri) {
        final server = buildMoodiaryServer(
          diaries: diaries,
          categories: CategoryRepository(db),
          insights: MoodInsightsRepository(db),
          appVersion: 'test',
          iconUri: iconUri,
        );
        servers.add(server);
        return server;
      },
    );
    await endpoint.start(port: 0, allowLan: false, token: 'secret');
    http = HttpClient();
  });

  tearDown(() async {
    http.close(force: true);
    await endpoint.stop();
    await db.close();
  });

  Future<HttpClientResponse> request({
    String method = 'POST',
    String path = '/mcp',
    String? token = 'secret',
    String? origin,
    String? host,
    String? sessionId,
    String? body,
    bool chunked = false,
  }) async {
    final request = await http.openUrl(
      method,
      endpoint.endpoints.first.replace(path: path),
    );
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (origin != null) request.headers.set('origin', origin);
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    if (sessionId != null) request.headers.set('mcp-session-id', sessionId);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json, text/event-stream',
      );
      final bytes = utf8.encode(body);
      if (!chunked) request.contentLength = bytes.length;
      request.add(bytes);
    }
    return request.close();
  }

  for (final profile in [McpProtocol.stable, McpProtocol.legacy]) {
    test('SDK ${profile.name} handshake and diary call', () async {
      final client = McpClient(
        const Implementation(name: 'test', version: '1'),
        options: McpClientOptions(protocol: profile),
      );
      final transport = StreamableHttpClientTransport(
        endpoint.endpoints.first,
        opts: const StreamableHttpClientTransportOptions(
          requestInit: {
            'headers': {'Authorization': 'Bearer secret'},
          },
        ),
      );
      addTearDown(client.close);
      await client.connect(transport);
      expect(client.getProtocolVersion(), profile.preferredProtocolVersion);
      expect(
        client.getServerVersion()!.icons!.single.src,
        endpoint.endpoints.first.replace(path: '/icon.png').toString(),
      );
      final capabilities = client.getServerCapabilities()!.toJson();
      expect(capabilities.containsKey('resources'), isFalse);
      expect(capabilities, isNot(contains('logging')));
      final result = await client.callTool(
        const CallToolRequest(name: 'list_diaries'),
      );
      expect(diaryIds(result.structuredContent!), ['one']);
      expect(
        jsonDecode((result.content.single as TextContent).text),
        result.structuredContent,
      );
      if (profile == McpProtocol.legacy) {
        expect(transport.sessionId, isNotNull);
        await transport.terminateSession();
      } else {
        expect(transport.sessionId, isNull);
      }
    });
  }

  for (final token in <String?>[null, 'wrong']) {
    test(
      'missing or wrong token is rejected before origin validation: $token',
      () async {
        final response = await request(
          token: token,
          origin: 'https://evil.example',
        );
        expect(response.statusCode, HttpStatus.unauthorized);
        expect(
          response.headers.value(HttpHeaders.wwwAuthenticateHeader),
          'Bearer',
        );
        await response.drain<void>();
      },
    );
  }

  test('DNS rebinding protection rejects remote origins and hosts', () async {
    for (final origin in [
      'https://evil.example',
      'null',
      'http://192.168.1.10:9000',
    ]) {
      final response = await request(origin: origin, body: '{}');
      expect(response.statusCode, HttpStatus.forbidden, reason: origin);
      await response.drain<void>();
    }
    final response = await request(host: 'evil.example', body: '{}');
    expect(response.statusCode, HttpStatus.forbidden);
    await response.drain<void>();
  });

  test('loopback origins with arbitrary ports reach the SDK', () async {
    for (final origin in [
      'http://localhost:12345',
      'https://127.0.0.1:54321',
      'http://[::1]:34567',
    ]) {
      final response = await request(origin: origin, body: initializeBody);
      expect(response.statusCode, HttpStatus.ok, reason: origin);
      await response.drain<void>();
    }
  });

  for (final chunked in [false, true]) {
    test('HTTP rejects a body exceeding 24 MiB (chunked=$chunked)', () async {
      final response = await request(
        body: ' ' * (McpHttpEndpoint.maxIncomingMessageBytes + 1),
        chunked: chunked,
      );
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
      await response.drain<void>();
    });
  }

  test(
    'HTTP accepts a valid message larger than the SDK stream default',
    () async {
      final client = McpClient(
        const Implementation(name: 'test', version: '1'),
      );
      addTearDown(client.close);
      await client.connect(
        StreamableHttpClientTransport(
          endpoint.endpoints.first,
          opts: const StreamableHttpClientTransportOptions(
            requestInit: {
              'headers': {'Authorization': 'Bearer secret'},
            },
          ),
        ),
      );
      final result = await client.callTool(
        CallToolRequest(
          name: 'list_diaries',
          arguments: {'padding': 'a' * (22 * 1024 * 1024)},
        ),
      );
      expect(diaryIds(result.structuredContent!), ['one']);
    },
  );

  test('icon GET and HEAD are served without the token', () async {
    final response = await request(
      method: 'GET',
      path: '/icon.png',
      token: null,
    );
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType!.mimeType, 'image/png');
    expect(
      await response.fold<List<int>>(
        [],
        (bytes, chunk) => bytes..addAll(chunk),
      ),
      mcpIconPngBytes,
    );
    final head = await request(method: 'HEAD', path: '/icon.png', token: null);
    expect(head.statusCode, HttpStatus.ok);
    expect(head.contentLength, mcpIconPngBytes.length);
    expect(
      await head.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk)),
      isEmpty,
    );
  });

  test('LAN requires a token and still rejects LAN browser origins', () async {
    await endpoint.stop();
    await endpoint.start(port: 0, allowLan: true, token: 'secret');
    final denied = await request(token: null);
    expect(denied.statusCode, HttpStatus.unauthorized);
    await denied.drain<void>();
    final originResponse = await request(
      origin: 'http://192.168.1.10:54321',
      body: '{}',
    );
    expect(originResponse.statusCode, HttpStatus.forbidden);
    await originResponse.drain<void>();
    for (final uri in endpoint.endpoints.skip(1)) {
      final response = await request(host: uri.authority, body: initializeBody);
      expect(response.statusCode, HttpStatus.ok, reason: uri.toString());
      await response.drain<void>();
    }
  });

  test('an empty configured token rejects every request', () async {
    await endpoint.stop();
    await endpoint.start(port: 0, allowLan: false, token: '');
    for (final path in ['/mcp', '/unknown']) {
      for (final token in <String?>[null, '', 'secret']) {
        final response = await request(path: path, token: token);
        expect(response.statusCode, HttpStatus.unauthorized);
        await response.drain<void>();
      }
    }
  });

  test('a busy configured port fails without a fallback', () async {
    await endpoint.stop();
    final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => occupied.close(force: true));
    await expectLater(
      endpoint.start(port: occupied.port, allowLan: false, token: 'secret'),
      throwsA(
        isA<McpPortInUseException>().having(
          (error) => error.port,
          'port',
          occupied.port,
        ),
      ),
    );
    expect(endpoint.port, 0);
    expect(endpoint.endpoints, isEmpty);
  });

  test('service reports a busy port and always ensures a token', () async {
    final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => occupied.close(force: true));
    MoodiaryKVs.mcpPort.set(occupied.port);
    final service = McpService(
      DiaryRepository(db),
      CategoryRepository(db),
      MoodInsightsRepository(db),
    );
    addTearDown(() async {
      await service.stop();
      service.state.dispose();
    });
    await service.enable();
    expect(service.state.value.status, McpServerStatus.failed);
    expect(service.state.value.failure, McpServerFailure.portInUse);
    expect(service.state.value.port, occupied.port);
    expect(await service.ensureToken(), hasLength(43));
    expect(await MoodiarySecureKVs.mcpToken.get(), await service.ensureToken());
    expect(MoodiaryKVs.mcpAllowLan.get(), isFalse);
  });

  Future<void> failAuth(int count) async {
    for (var attempt = 0; attempt < count; attempt++) {
      final response = await request(token: 'wrong');
      expect(response.statusCode, HttpStatus.unauthorized);
      await response.drain<void>();
    }
  }

  Future<void> expectAuthenticated() async {
    // Past the auth check an unknown path is a plain 404.
    final response = await request(method: 'GET', path: '/unknown');
    expect(response.statusCode, HttpStatus.notFound);
    await response.drain<void>();
  }

  test('five failures lock an address for fifteen minutes', () async {
    remoteAddress = InternetAddress('192.0.2.1');
    await failAuth(5);
    for (final token in ['secret', 'wrong']) {
      final response = await request(token: token);
      expect(response.statusCode, HttpStatus.tooManyRequests);
      expect(response.headers.value(HttpHeaders.retryAfterHeader), '900');
      await response.drain<void>();
    }
    remoteAddress = InternetAddress('192.0.2.2');
    await expectAuthenticated();
    remoteAddress = InternetAddress('192.0.2.1');
    now = now.add(
      const Duration(minutes: 15) - const Duration(milliseconds: 1),
    );
    final blocked = await request();
    expect(blocked.statusCode, HttpStatus.tooManyRequests);
    expect(blocked.headers.value(HttpHeaders.retryAfterHeader), '1');
    await blocked.drain<void>();
    now = now.add(const Duration(milliseconds: 1));
    await expectAuthenticated();
    await failAuth(4);
    await expectAuthenticated();
  });

  test('successful authentication resets consecutive failures', () async {
    remoteAddress = InternetAddress('192.0.2.1');
    await failAuth(4);
    await expectAuthenticated();
    await failAuth(4);
    await expectAuthenticated();
  });

  for (final address in ['127.0.0.1', '::1']) {
    test('loopback $address is never locked out', () async {
      remoteAddress = InternetAddress(address);
      await failAuth(10);
      await expectAuthenticated();
    });
  }

  test('the 33rd legacy session closes and evicts the oldest', () async {
    final sessionIds = <String>[];
    for (var index = 0; index < 33; index++) {
      final response = await request(body: initializeBody);
      expect(response.statusCode, HttpStatus.ok);
      sessionIds.add(response.headers.value('mcp-session-id')!);
      await response.drain<void>();
    }
    final evicted = await request(sessionId: sessionIds.first, body: '{}');
    expect(evicted.statusCode, HttpStatus.notFound);
    await evicted.drain<void>();
    expect(servers.first.server.transport, isNull);
    expect(
      servers.where((server) => server.server.transport != null),
      hasLength(32),
    );
    for (final id in sessionIds.skip(1)) {
      final response = await request(
        sessionId: id,
        body: jsonEncode({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'}),
      );
      expect(response.statusCode, HttpStatus.ok);
      await response.drain<void>();
    }
  });
}
