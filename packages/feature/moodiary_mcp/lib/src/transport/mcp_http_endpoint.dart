import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

import 'http_auth.dart';
import 'server_icon.dart';

class McpHttpEndpoint {
  McpHttpEndpoint({
    required this.serverFactory,
    DateTime Function()? now,
    InternetAddress? Function(HttpRequest)? remoteAddress,
    Future<List<String>> Function()? listLanHosts,
  }) : _now = now ?? DateTime.now,
       _listLanHosts =
           listLanHosts ??
           (() async {
             final host = await NetworkStatus.getDeviceIP();
             return [?host];
           }),
       _remoteAddress =
           remoteAddress ??
           ((request) => request.connectionInfo?.remoteAddress);

  static const maxIncomingMessageBytes = 24 * 1024 * 1024;

  static const _maxSessions = 32;
  static const _maxAuthFailures = 5;
  static const _lockoutDuration = Duration(minutes: 15);
  static const _hostRefreshInterval = Duration(seconds: 5);
  final McpServer Function(Uri iconUri) serverFactory;
  final DateTime Function() _now;
  final Future<List<String>> Function() _listLanHosts;
  final InternetAddress? Function(HttpRequest) _remoteAddress;
  void Function(List<Uri>)? onEndpointsChanged;
  final Map<String, _AuthFailures> _authFailures = {};
  final Map<String, _Connection> _sessions = {};
  final Set<_Connection> _connections = {};
  final Set<String> _allowedHosts = {};
  HttpServer? _http;
  List<Uri> _endpoints = const [];
  String _token = '';
  bool _allowLan = false;
  DateTime? _lastHostRefresh;
  Future<void>? _hostRefresh;

  int get port => _http?.port ?? 0;
  List<Uri> get endpoints => _endpoints;

  Future<void> start({
    required int port,
    required bool allowLan,
    required String token,
  }) async {
    if (_http != null) return;
    _token = token;
    _allowLan = allowLan;
    final address = allowLan
        ? InternetAddress.anyIPv4
        : InternetAddress.loopbackIPv4;
    final HttpServer http;
    try {
      http = await HttpServer.bind(address, port);
    } on SocketException catch (error) {
      if (const {48, 98, 10048}.contains(error.osError?.errorCode) ||
          error.osError?.message.contains('The shared flag to bind()') ==
              true) {
        throw McpPortInUseException(port);
      }
      rethrow;
    }
    _http = http;
    try {
      _setHosts(http, const []);
      if (allowLan) await _refreshLanHosts(http);
      if (_http != http) return;
      http.listen((request) => unawaited(_handle(request)));
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  void _setHosts(HttpServer http, List<String> lanHosts) {
    final hosts = <String>{'localhost', '127.0.0.1', '[::1]', ...lanHosts};
    _allowedHosts
      ..clear()
      ..addAll({
        for (final host in hosts) ...[host, '$host:${http.port}'],
      });
    _endpoints = List.unmodifiable([
      for (final host in <String>{'127.0.0.1', ...lanHosts})
        Uri(scheme: 'http', host: host, port: http.port, path: '/mcp'),
    ]);
    onEndpointsChanged?.call(_endpoints);
  }

  Future<void> refreshLanHosts() async {
    final http = _http;
    if (http != null && _allowLan) {
      await _refreshLanHosts(http, force: true);
    }
  }

  Future<void> _refreshLanHosts(HttpServer http, {bool force = false}) async {
    if (_hostRefresh case final pending?) {
      await pending;
      if (!force) return;
    }
    if (_http != http) return;
    final now = _now();
    final lastRefresh = _lastHostRefresh;
    if (!force &&
        lastRefresh != null &&
        now.difference(lastRefresh) < _hostRefreshInterval) {
      return;
    }
    _lastHostRefresh = now;
    final refresh = _updateLanHosts(http);
    _hostRefresh = refresh;
    try {
      await refresh;
    } finally {
      if (_hostRefresh == refresh) _hostRefresh = null;
    }
  }

  Future<void> _updateLanHosts(HttpServer http) async {
    try {
      final hosts = await _listLanHosts();
      if (_http == http) _setHosts(http, hosts);
    } catch (error, stackTrace) {
      logger.e(
        'MCP could not read the LAN address',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> stop() async {
    final http = _http;
    _http = null;
    _endpoints = const [];
    _allowedHosts.clear();
    _allowLan = false;
    _lastHostRefresh = null;
    _hostRefresh = null;
    await http?.close(force: true);
    await Future.wait([
      for (final connection in _connections.toList()) connection.server.close(),
    ]);
    _connections.clear();
    _sessions.clear();
    _authFailures.clear();
  }

  Future<bool> _checkAuth(HttpRequest request) async {
    final address = _remoteAddress(request);
    final key = address != null && !address.isLoopback ? address.address : null;
    final now = _now();
    final failures = _authFailures[key];
    final blockedUntil = failures?.blockedUntil;
    if (blockedUntil != null) {
      if (now.isBefore(blockedUntil)) {
        request.response.statusCode = HttpStatus.tooManyRequests;
        request.response.headers.set(
          HttpHeaders.retryAfterHeader,
          (blockedUntil.difference(now).inMicroseconds /
                  Duration.microsecondsPerSecond)
              .ceil(),
        );
        await request.response.close();
        return false;
      }
      _authFailures.remove(key);
    }
    if (hasValidBearerToken(request, _token)) {
      _authFailures.remove(key);
      return true;
    }
    if (key != null) {
      final failures = _authFailures.putIfAbsent(key, _AuthFailures.new);
      if (++failures.count >= _maxAuthFailures) {
        failures.blockedUntil = now.add(_lockoutDuration);
      }
    }
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
    await request.response.close();
    return false;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (_http == null) return;
      // Clients fetch the advertised icon without credentials; it is app artwork.
      if (request.uri.path == '/icon.png' &&
          (request.method == 'GET' || request.method == 'HEAD')) {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.contentLength = mcpIconPngBytes.length;
        if (request.method == 'GET') request.response.add(mcpIconPngBytes);
        await request.response.close();
        return;
      }
      if (!await _checkAuth(request)) return;
      final http = _http;
      if (http == null) return;
      if (_allowLan &&
          !_allowedHosts.contains(
            request.headers.value(HttpHeaders.hostHeader),
          )) {
        await _refreshLanHosts(http);
      }
      if (request.uri.path != '/mcp') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      dynamic body;
      if (request.method == 'POST') {
        if (request.contentLength > maxIncomingMessageBytes) {
          request.response.statusCode = HttpStatus.requestEntityTooLarge;
          await request.response.close();
          return;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in request) {
          if (bytes.length + chunk.length > maxIncomingMessageBytes) {
            request.response.statusCode = HttpStatus.requestEntityTooLarge;
            await request.response.close();
            return;
          }
          bytes.add(chunk);
        }
        try {
          body = jsonDecode(utf8.decode(bytes.takeBytes()));
        } on FormatException {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
      }
      if (_http == null) return;
      final stateless =
          request.headers.value('mcp-protocol-version') ==
          McpProtocol.stable.preferredProtocolVersion;
      final sessionId = request.headers.value('mcp-session-id');
      if (!stateless &&
          sessionId != null &&
          !_sessions.containsKey(sessionId)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final connection = !stateless && sessionId != null
          ? _sessions[sessionId]!
          : await _connect(request, stateless);
      if (_http == null) {
        await connection.server.close();
        return;
      }
      // The SDK matches origins exactly; offer only loopback hosts at the requested port.
      final origin = Uri.tryParse(request.headers.value('origin') ?? '');
      final suffix = origin?.hasPort == true ? ':${origin!.port}' : '';
      connection.origins
        ..clear()
        ..addAll({
          for (final scheme in ['http', 'https'])
            for (final host in ['localhost', '127.0.0.1', '[::1]'])
              '$scheme://$host$suffix',
        });
      try {
        await connection.transport.handleRequest(request, body);
      } finally {
        if (connection.transport.sessionId == null) {
          _connections.remove(connection);
          await connection.server.close();
        }
      }
    } catch (error, stackTrace) {
      logger.e('MCP HTTP request failed', error: error, stackTrace: stackTrace);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<_Connection> _connect(HttpRequest request, bool stateless) async {
    final origins = <String>{};
    late final _Connection connection;
    final transport = StreamableHTTPServerTransport(
      options: StreamableHTTPServerTransportOptions(
        sessionIdGenerator: stateless ? () => null : generateUUID,
        onsessioninitialized: (id) {
          if (_sessions.length >= _maxSessions) {
            final oldest = _sessions.remove(_sessions.keys.first)!;
            unawaited(oldest.server.close());
          }
          _sessions[id] = connection;
        },
        enableJsonResponse: true,
        enableDnsRebindingProtection: true,
        allowedHosts: _allowedHosts,
        allowedOrigins: origins,
      ),
    );
    final host = request.headers.value(HttpHeaders.hostHeader);
    final iconUri =
        Uri.tryParse('http://${host ?? '127.0.0.1:$port'}/icon.png') ??
        endpoints.first.replace(path: '/icon.png');
    final server = serverFactory(iconUri);
    connection = _Connection(server, transport, origins);
    _connections.add(connection);
    server.server.onclose = () {
      _connections.remove(connection);
      _sessions.remove(transport.sessionId);
    };
    try {
      await server.connect(transport);
      return connection;
    } catch (_) {
      _connections.remove(connection);
      await server.close();
      rethrow;
    }
  }
}

class McpPortInUseException implements Exception {
  const McpPortInUseException(this.port);

  final int port;

  @override
  String toString() => 'MCP port $port is already in use';
}

class _AuthFailures {
  int count = 0;
  DateTime? blockedUntil;
}

class _Connection {
  _Connection(this.server, this.transport, this.origins);
  final McpServer server;
  final StreamableHTTPServerTransport transport;
  final Set<String> origins;
}
