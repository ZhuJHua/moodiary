import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_mcp/src/tools/register_moodiary_tools.dart';
import 'package:moodiary_mcp/src/transport/mcp_http_endpoint.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _ControlledEndpoint extends McpHttpEndpoint {
  _ControlledEndpoint({
    required super.serverFactory,
    super.now,
    super.listLanHosts,
    this.startGate,
    this.startFailure,
  });

  final Completer<void>? startGate;
  final Object? startFailure;
  final bound = Completer<void>();
  bool? boundLan;

  @override
  Future<void> start({
    required int port,
    required bool allowLan,
    required String token,
  }) async {
    await super.start(port: port, allowLan: allowLan, token: token);
    boundLan = allowLan;
    bound.complete();
    if (startFailure case final failure?) throw failure;
    await startGate?.future;
  }
}

void main() {
  late MoodiaryDatabase db;
  late McpService service;
  late ProviderContainer container;
  late HttpClient http;
  late Completer<_ControlledEndpoint> firstEndpoint;
  Completer<void>? startGate;
  Object? startFailure;
  List<String>? lanHosts;
  late DateTime now;
  int interfaceReads = 0;
  late StreamController<Object?> networkChanges;
  final endpoints = <_ControlledEndpoint>[];

  setUp(() {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    SecureKVStore.installForTesting(MemorySecureKVStorage());
    addTearDown(SecureKVStore.resetForTesting);
  });

  setUp(() async {
    MoodiaryKVs.mcpPort.set(0);
    endpoints.clear();
    firstEndpoint = Completer<_ControlledEndpoint>();
    startGate = null;
    startFailure = null;
    lanHosts = null;
    now = DateTime.utc(2026);
    interfaceReads = 0;
    networkChanges = StreamController<Object?>.broadcast();
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    final diaries = DiaryRepository(db);
    final categories = CategoryRepository(db);
    final tags = TagRepository(db);
    final insights = MoodInsightsRepository(db);
    container = ProviderContainer.test(retry: (_, _) => null);
    service = McpService.forTesting(
      diaries,
      categories,
      tags,
      insights,
      container.read(mcpServerStateProvider.notifier),
      () {
        final endpoint = _ControlledEndpoint(
          now: () => now,
          listLanHosts: lanHosts == null
              ? null
              : () async {
                  interfaceReads++;
                  return lanHosts!;
                },
          startGate: endpoints.isEmpty ? startGate : null,
          startFailure: startFailure,
          serverFactory: (iconUri) => buildMoodiaryServer(
            diaries: diaries,
            categories: categories,
            tags: tags,
            insights: insights,
            appVersion: 'test',
            iconUri: iconUri,
          ),
        );
        endpoints.add(endpoint);
        if (!firstEndpoint.isCompleted) firstEndpoint.complete(endpoint);
        return endpoint;
      },
      networkChanges.stream,
    );
    http = HttpClient();
    addTearDown(() async {
      if (startGate case final gate? when !gate.isCompleted) gate.complete();
      http.close(force: true);
      await service.stop();
      await networkChanges.close();
      await service.dispose();
      await db.close();
    });
  });

  Future<void> waitUntilBound() async {
    await (await firstEndpoint.future).bound.future;
  }

  Future<int> authStatus(String? token) async {
    final request = await http.getUrl(
      container
          .read(mcpServerStateProvider)
          .endpoints
          .first
          .replace(path: '/missing'),
    );
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  test('unexpected start failure tears down and allows a retry', () async {
    startFailure = StateError('private exception detail');

    await service.enable();

    const failed = McpServerState(status: .failed, port: 0, failure: .unknown);
    expect(container.read(mcpServerStateProvider), failed);
    expect(container.read(mcpServerStateProvider).hashCode, failed.hashCode);
    expect(endpoints.single.port, 0);
    expect(service.enabled, isTrue);

    startFailure = null;
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final newPort = socket.port;
    await socket.close();
    await service.updateConfig(port: newPort);

    expect(container.read(mcpServerStateProvider).running, isTrue);
    expect(container.read(mcpServerStateProvider).port, newPort);
    expect(container.read(mcpServerStateProvider).failure, isNull);
    expect(endpoints, hasLength(2));
  });

  test(
    'LAN host refresh updates sessions and advertised service endpoints',
    () async {
      lanHosts = ['192.168.1.2'];
      MoodiaryKVs.mcpAllowLan.set(true);
      await service.enable();
      final token = await service.ensureToken();
      final uri = container.read(mcpServerStateProvider).endpoints.first;

      Future<HttpClientResponse> call(
        String host, {
        String? sessionId,
        String? origin,
      }) async {
        final request = await http.postUrl(uri);
        request.headers
          ..contentType = ContentType.json
          ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
          ..set(HttpHeaders.hostHeader, '$host:${uri.port}')
          ..set(
            HttpHeaders.acceptHeader,
            'application/json, text/event-stream',
          );
        if (sessionId != null) request.headers.set('mcp-session-id', sessionId);
        if (origin != null) request.headers.set('origin', origin);
        request.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': sessionId == null ? 'initialize' : 'tools/list',
            if (sessionId == null)
              'params': {
                'protocolVersion': '2025-06-18',
                'capabilities': <String, dynamic>{},
                'clientInfo': {'name': 'test', 'version': '1'},
              },
          }),
        );
        return request.close();
      }

      final initialized = await call('192.168.1.2');
      expect(initialized.statusCode, HttpStatus.ok);
      final sessionId = initialized.headers.value('mcp-session-id');
      expect(sessionId, isNotNull);
      await initialized.drain<void>();

      lanHosts = ['192.168.2.2'];
      final throttled = await call('192.168.2.2', sessionId: sessionId);
      expect(throttled.statusCode, HttpStatus.forbidden);
      await throttled.drain<void>();
      expect(interfaceReads, 1);

      now = now.add(const Duration(seconds: 5));
      final refreshed = await call('192.168.2.2', sessionId: sessionId);
      expect(refreshed.statusCode, HttpStatus.ok);
      await refreshed.drain<void>();
      expect(interfaceReads, 2);
      expect(
        container
            .read(mcpServerStateProvider)
            .endpoints
            .map((endpoint) => endpoint.host),
        ['127.0.0.1', '192.168.2.2'],
      );
      expect(endpoints, hasLength(1));

      for (final host in ['192.168.1.2', 'evil.example']) {
        final rejected = await call(host, sessionId: sessionId);
        expect(rejected.statusCode, HttpStatus.forbidden);
        await rejected.drain<void>();
      }
      final origin = await call(
        '192.168.2.2',
        sessionId: sessionId,
        origin: 'https://evil.example',
      );
      expect(origin.statusCode, HttpStatus.forbidden);
      await origin.drain<void>();
      expect(interfaceReads, 2);
    },
  );

  test('network changes refresh LAN state without throttling', () async {
    lanHosts = ['192.168.1.2'];
    MoodiaryKVs.mcpAllowLan.set(true);
    await service.enable();
    expect(interfaceReads, 1);
    expect(networkChanges.hasListener, isTrue);

    for (final hosts in [
      <String>['192.168.2.2'],
      <String>[],
    ]) {
      final changed = Completer<void>();
      void onChanged() => changed.complete();
      final sub = container.listen(
        mcpServerStateProvider,
        (_, _) => onChanged(),
      );
      lanHosts = hosts;
      networkChanges.add('wifi');
      await changed.future;
      sub.close();
      expect(
        container
            .read(mcpServerStateProvider)
            .endpoints
            .map((endpoint) => endpoint.host),
        ['127.0.0.1', ...hosts],
      );
    }
    expect(interfaceReads, 3);
    expect(endpoints, hasLength(1));

    await service.stop();
    expect(networkChanges.hasListener, isFalse);
  });

  test('LAN update during start restarts with the new configuration', () async {
    startGate = Completer<void>();
    final starting = service.enable();
    await waitUntilBound();
    expect(
      container.read(mcpServerStateProvider).status,
      McpServerStatus.starting,
    );
    expect(endpoints.single.boundLan, isFalse);

    final updating = service.updateConfig(lan: true);
    expect(McpService.allowLan, isFalse);
    startGate!.complete();
    await Future.wait([starting, updating]);

    expect(container.read(mcpServerStateProvider).running, isTrue);
    expect(McpService.allowLan, isTrue);
    expect(endpoints, hasLength(2));
    expect(endpoints.first.port, 0);
    expect(endpoints.last.boundLan, isTrue);
    expect(await authStatus(await service.ensureToken()), HttpStatus.notFound);
  });

  test(
    'disable during start closes the socket and blocks queued starts',
    () async {
      startGate = Completer<void>();
      final starting = service.enable();
      await waitUntilBound();
      final boundPort = endpoints.single.port;

      final disabling = service.disable();
      final restarting = service.restore();
      final restoring = service.restore();
      startGate!.complete();
      await Future.wait([starting, disabling, restarting, restoring]);

      expect(service.enabled, isFalse);
      expect(
        container.read(mcpServerStateProvider).status,
        McpServerStatus.stopped,
      );
      expect(container.read(mcpServerStateProvider).endpoints, isEmpty);
      expect(endpoints, hasLength(1));
      expect(endpoints.single.port, 0);
      await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4, boundPort),
        throwsA(isA<SocketException>()),
      );
      final rebound = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        boundPort,
      );
      await rebound.close(force: true);
    },
  );

  test('token rotation restarts and accepts only the new token', () async {
    await service.enable();
    final oldToken = await service.ensureToken();
    expect(await authStatus(oldToken), HttpStatus.notFound);

    final newToken = await service.regenerateToken();

    expect(newToken, isNot(oldToken));
    expect(await service.ensureToken(), newToken);
    expect(await MoodiarySecureKVs.mcpToken.get(), newToken);
    expect(container.read(mcpServerStateProvider).running, isTrue);
    expect(endpoints, hasLength(2));
    expect(endpoints.first.port, 0);
    expect(await authStatus(oldToken), HttpStatus.unauthorized);
    expect(await authStatus(newToken), HttpStatus.notFound);
    expect(await authStatus(null), HttpStatus.unauthorized);
  });

  test(
    'configuration and token changes leave a stopped server stopped',
    () async {
      MoodiaryKVs.mcpEnabled.set(true);
      await service.updateConfig(port: 12345, lan: true);
      final token = await service.regenerateToken();

      expect(await service.ensureToken(), token);
      expect(
        container.read(mcpServerStateProvider).status,
        McpServerStatus.stopped,
      );
      expect(container.read(mcpServerStateProvider).port, 12345);
      expect(endpoints, isEmpty);
    },
  );

  test('concurrent restores leave a disabled server stopped', () async {
    await Future.wait([service.restore(), service.restore()]);

    expect(
      container.read(mcpServerStateProvider).status,
      McpServerStatus.stopped,
    );
    expect(endpoints, isEmpty);
    expect(await MoodiarySecureKVs.mcpToken.get(), isNull);
  });
}
