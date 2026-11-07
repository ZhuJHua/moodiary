/// The `dart:io` implementation of [McpTransport].
///
/// Two MCP transports share one [HttpServer]:
///
/// * Streamable HTTP (protocol 2025-03-26 and 2025-06-18) on `/mcp`: `POST`
///   carries client messages and answers either with plain JSON or with a one
///   shot event stream, `GET` opens the server to client notification stream and
///   `DELETE` ends a session.
/// * Legacy HTTP+SSE (protocol 2024-11-05) on `/sse` (the event stream, whose
///   first event points at the message endpoint) and `/messages` (where the
///   client posts, receiving `202 Accepted` and the answers on the stream).
///
/// Both are private endpoints: every request except the CORS preflight has to
/// present the configured bearer token, and browser origins are restricted to
/// local pages so a hostile website cannot reach the diary through DNS
/// rebinding.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:moodiary_logging/moodiary_logging.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../server/mcp_server.dart';
import '../server/mcp_session.dart';
import 'http_auth.dart';
import 'sse_writer.dart';
import 'transport.dart';

const String _mcpPath = '/mcp';
const String _ssePath = '/sse';
const String _messagesPath = '/messages';

const String _sessionIdHeader = 'Mcp-Session-Id';
const String _protocolVersionHeader = 'MCP-Protocol-Version';
const String _lastEventIdHeader = 'Last-Event-ID';
const String _originHeaderName = 'origin';
const String _sessionIdQuery = 'sessionId';

const String _wwwAuthenticateValue = 'Bearer realm="moodiary-mcp"';
const String _corsMethods = 'POST, GET, DELETE, OPTIONS';
const String _corsHeaders =
    'Content-Type, Authorization, Mcp-Session-Id, MCP-Protocol-Version, '
    'Last-Event-ID';
const String _corsMaxAge = '600';

/// A browser client cannot read the session id off the response otherwise.
const String _corsExposeHeaders = 'Mcp-Session-Id';

/// MCP clients send small JSON-RPC frames; anything bigger is not a client.
const int _maxBodyBytes = 4 * 1024 * 1024;

/// Sessions kept at once, oldest evicted first.
const int _maxSessions = 64;

const int _maxBindAttempts = 12;
const int _maxLanEndpoints = 4;

const Duration _pingInterval = Duration(seconds: 25);
const Duration _idleTimeout = Duration(minutes: 30);
const Duration _sweepInterval = Duration(minutes: 5);

class IoMcpTransport implements McpTransport {
  HttpServer? _server;
  McpServer? _core;
  String _token = '';
  int _port = 0;
  List<Uri> _endpoints = const [];
  Timer? _sweeper;
  bool _starting = false;

  /// Bumped by [stop] so a bind that is still in flight cannot resurrect a
  /// transport the caller already stopped.
  int _generation = 0;

  /// Live sessions, in creation order, with their last activity.
  final Map<String, _TrackedSession> _sessions = {};

  /// Open event streams, so [stop] can end every one of them.
  final Set<_SseConnection> _connections = {};

  @override
  int get port => _port;

  @override
  List<Uri> get endpoints => _endpoints;

  @override
  Future<void> start(McpTransportConfig config, McpServer server) async {
    if (_server != null || _starting) {
      logger.d('MCP transport is already running');
      return;
    }
    _starting = true;
    final generation = ++_generation;
    try {
      _token = config.token;
      if (_token.isEmpty) {
        logger.e(
          'MCP transport started without a bearer token, every request will '
          'be rejected',
          error: const FormatException('empty bearer token'),
        );
      }
      final address = config.allowLan
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4;
      final bound = await _bind(address, config.port);
      if (generation != _generation) {
        await bound.close(force: true);
        return;
      }
      _server = bound;
      _core = server;
      _port = bound.port;
      bound.listen(
        _handleRequest,
        onError: (Object error, StackTrace stackTrace) {
          logger.e(
            'MCP transport socket failed',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      _sweeper = Timer.periodic(_sweepInterval, (_) => _sweepIdleSessions());
      _endpoints = await _endpointsFor(bound.port, config.allowLan);
      logger.d('MCP transport listening on ${_endpoints.join(', ')}');
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _sweeper?.cancel();
    _sweeper = null;
    final server = _server;
    _server = null;
    _core = null;
    _port = 0;
    _endpoints = const [];
    _sessions.clear();
    final connections = _connections.toList();
    _connections.clear();
    for (final connection in connections) {
      unawaited(connection.close());
    }
    if (server == null) return;
    try {
      await server.close(force: true);
    } catch (error, stackTrace) {
      logger.e(
        'MCP transport could not close its socket',
        error: error,
        stackTrace: stackTrace,
      );
    }
    logger.d('MCP transport stopped');
  }

  /// Binds the preferred port, then the next ones, then an OS assigned port.
  Future<HttpServer> _bind(InternetAddress address, int preferredPort) async {
    for (var attempt = 0; attempt < _maxBindAttempts; attempt++) {
      final port = preferredPort == 0 ? 0 : preferredPort + attempt;
      try {
        return await HttpServer.bind(address, port);
      } on SocketException catch (e) {
        logger.d('MCP: port $port is not available (${e.message}), retrying');
      }
    }
    logger.d('MCP: no candidate port is free, using an OS assigned one');
    return HttpServer.bind(address, 0);
  }

  /// Loopback first; in LAN mode one entry per reachable IPv4 interface.
  Future<List<Uri>> _endpointsFor(int port, bool allowLan) async {
    final endpoints = [_endpoint(port, InternetAddress.loopbackIPv4.address)];
    if (!allowLan) return endpoints;
    final hosts = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type != InternetAddressType.IPv4) continue;
          if (address.isLoopback || address.isLinkLocal) continue;
          hosts.add(address.address);
        }
      }
    } catch (error, stackTrace) {
      logger.e(
        'MCP transport could not enumerate the network interfaces',
        error: error,
        stackTrace: stackTrace,
      );
    }
    var lanEndpoints = 0;
    for (final host in hosts) {
      if (lanEndpoints >= _maxLanEndpoints) break;
      endpoints.add(_endpoint(port, host));
      lanEndpoints++;
    }
    return endpoints;
  }

  Uri _endpoint(int port, String host) =>
      Uri(scheme: 'http', host: host, port: port, path: _mcpPath);

  // ---------------------------------------------------------------- requests

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      await _route(request);
    } catch (error, stackTrace) {
      logger.e(
        'MCP transport failed to answer ${request.method} '
        '${request.uri.path}',
        error: error,
        stackTrace: stackTrace,
      );
      await _sendError(
        request,
        HttpStatus.internalServerError,
        JsonRpcCode.internalError,
        'internal error',
      );
    }
  }

  Future<void> _route(HttpRequest request) async {
    final origin = _header(request, _originHeaderName);
    if (request.method == 'OPTIONS') {
      await _preflight(request, origin);
      return;
    }
    if (origin != null && !_isAllowedOrigin(request, origin)) {
      logger.d('MCP transport rejected a request from origin $origin');
      await _sendError(
        request,
        HttpStatus.forbidden,
        JsonRpcCode.invalidRequest,
        'origin not allowed',
      );
      return;
    }
    if (!hasValidBearerToken(request, _token)) {
      logger.d('MCP transport rejected an unauthenticated request');
      await _unauthorized(request);
      return;
    }
    switch (_normalizePath(request.uri.path)) {
      case _mcpPath:
        await _routeMcp(request);
      case _ssePath:
        if (request.method != 'GET') {
          await _methodNotAllowed(request, 'GET, OPTIONS');
          return;
        }
        await _openLegacyStream(request);
      case _messagesPath:
        if (request.method != 'POST') {
          await _methodNotAllowed(request, 'POST, OPTIONS');
          return;
        }
        await _postLegacyMessage(request);
      default:
        await _sendError(
          request,
          HttpStatus.notFound,
          JsonRpcCode.invalidRequest,
          'unknown endpoint',
        );
    }
  }

  Future<void> _routeMcp(HttpRequest request) async {
    switch (request.method) {
      case 'POST':
        await _postStreamable(request);
      case 'GET':
        await _openStreamableStream(request);
      case 'DELETE':
        await _deleteStreamable(request);
      default:
        await _methodNotAllowed(request, 'GET, POST, DELETE, OPTIONS');
    }
  }

  /// `POST /mcp`: one JSON-RPC message in, its answer out.
  Future<void> _postStreamable(HttpRequest request) async {
    if (!_isJsonRequest(request)) {
      await _sendError(
        request,
        HttpStatus.unsupportedMediaType,
        JsonRpcCode.invalidRequest,
        'Content-Type must be application/json',
      );
      return;
    }
    final body = await _readBody(request);
    if (body == null) {
      await _sendError(
        request,
        HttpStatus.requestEntityTooLarge,
        JsonRpcCode.invalidRequest,
        'request body is larger than 4 MiB',
      );
      return;
    }
    final version = _header(request, _protocolVersionHeader);
    if (version != null &&
        version.isNotEmpty &&
        !mcpSupportedProtocolVersions.contains(version)) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        JsonRpcCode.invalidRequest,
        'unsupported MCP-Protocol-Version',
      );
      return;
    }
    final message = await _decodeOrReject(request, body);
    if (message == null) return;
    final core = _core;
    if (core == null) {
      await _sendError(
        request,
        HttpStatus.internalServerError,
        JsonRpcCode.internalError,
        'server is stopping',
      );
      return;
    }
    final headerSessionId = _header(request, _sessionIdHeader);
    final McpSessionState session;
    if (headerSessionId != null && headerSessionId.isNotEmpty) {
      final existing = core.session(headerSessionId);
      if (existing == null) {
        await _sendError(
          request,
          HttpStatus.notFound,
          JsonRpcCode.invalidRequest,
          'unknown MCP session',
        );
        return;
      }
      _touch(headerSessionId);
      session = existing;
    } else if (_isInitialize(message)) {
      session = _createSession(core);
    } else {
      await _sendError(
        request,
        HttpStatus.badRequest,
        JsonRpcCode.invalidRequest,
        'Mcp-Session-Id is required after initialize',
      );
      return;
    }
    final notifications = <Map<String, dynamic>>[];
    final frame = await _dispatch(core, session, message, notifications);
    if (frame == null) {
      // A notification: the client is told it was accepted, not answered.
      await _respondEmpty(request, HttpStatus.accepted, sessionId: session.id);
      return;
    }
    if (_acceptsEventStream(request) || notifications.isNotEmpty) {
      await _respondEventStream(request, [...notifications, frame], session.id);
      return;
    }
    await _respondJson(request, HttpStatus.ok, frame, sessionId: session.id);
  }

  /// `GET /mcp`: the stream the server pushes notifications on.
  Future<void> _openStreamableStream(HttpRequest request) async {
    final sessionId = _header(request, _sessionIdHeader);
    if (sessionId == null || sessionId.isEmpty) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        JsonRpcCode.invalidRequest,
        'Mcp-Session-Id is required',
      );
      return;
    }
    final session = _core?.session(sessionId);
    if (session == null) {
      await _sendError(
        request,
        HttpStatus.notFound,
        JsonRpcCode.invalidRequest,
        'unknown MCP session',
      );
      return;
    }
    if (_header(request, _lastEventIdHeader) != null) {
      logger.d('MCP: streams are not resumable, ignoring Last-Event-ID');
    }
    _touch(sessionId);
    await _serveStream(request, session);
  }

  /// `DELETE /mcp`: the client ends its session explicitly.
  Future<void> _deleteStreamable(HttpRequest request) async {
    final sessionId = _header(request, _sessionIdHeader);
    if (sessionId == null || sessionId.isEmpty) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        JsonRpcCode.invalidRequest,
        'Mcp-Session-Id is required',
      );
      return;
    }
    if (_core?.session(sessionId) == null) {
      await _sendError(
        request,
        HttpStatus.notFound,
        JsonRpcCode.invalidRequest,
        'unknown MCP session',
      );
      return;
    }
    _dropSession(sessionId);
    await _respondEmpty(request, HttpStatus.ok);
  }

  /// `GET /sse`: the 2024-11-05 stream, whose first event names the message
  /// endpoint to POST to.
  Future<void> _openLegacyStream(HttpRequest request) async {
    final core = _core;
    if (core == null) {
      await _sendError(
        request,
        HttpStatus.internalServerError,
        JsonRpcCode.internalError,
        'server is stopping',
      );
      return;
    }
    final session = _createSession(core);
    final endpoint = Uri(
      path: _messagesPath,
      queryParameters: {_sessionIdQuery: session.id},
    ).toString();
    // A legacy session exists only for the lifetime of its stream.
    await _serveStream(request, session, endpoint: endpoint, dispose: true);
  }

  /// `POST /messages?sessionId=…`: answers `202 Accepted` right away and pushes
  /// the JSON-RPC answers to the event stream of the session.
  Future<void> _postLegacyMessage(HttpRequest request) async {
    final sessionId = request.uri.queryParameters[_sessionIdQuery];
    if (sessionId == null || sessionId.isEmpty) {
      await _sendError(
        request,
        HttpStatus.badRequest,
        JsonRpcCode.invalidRequest,
        'sessionId is required',
      );
      return;
    }
    final core = _core;
    if (core == null) {
      await _sendError(
        request,
        HttpStatus.internalServerError,
        JsonRpcCode.internalError,
        'server is stopping',
      );
      return;
    }
    final session = core.session(sessionId);
    if (session == null) {
      await _sendError(
        request,
        HttpStatus.notFound,
        JsonRpcCode.invalidRequest,
        'unknown MCP session',
      );
      return;
    }
    _touch(sessionId);
    if (!_isJsonRequest(request)) {
      await _sendError(
        request,
        HttpStatus.unsupportedMediaType,
        JsonRpcCode.invalidRequest,
        'Content-Type must be application/json',
      );
      return;
    }
    final body = await _readBody(request);
    if (body == null) {
      await _sendError(
        request,
        HttpStatus.requestEntityTooLarge,
        JsonRpcCode.invalidRequest,
        'request body is larger than 4 MiB',
      );
      return;
    }
    final message = await _decodeOrReject(request, body);
    if (message == null) return;
    await _respondEmpty(request, HttpStatus.accepted);
    try {
      final frame = await _dispatch(core, session, message, []);
      if (frame != null) session.notify(frame);
    } catch (error, stackTrace) {
      logger.e(
        'MCP legacy message failed',
        error: error,
        stackTrace: stackTrace,
      );
      session.notify(
        jsonRpcFailure(
          message['id'],
          const JsonRpcException(JsonRpcCode.internalError, 'internal error'),
        ),
      );
    }
  }

  // ----------------------------------------------------------------- streams

  /// Writes one event stream until the peer goes away, [stop] runs or the
  /// session is disposed.
  Future<void> _serveStream(
    HttpRequest request,
    McpSessionState session, {
    String? endpoint,
    bool dispose = false,
  }) async {
    final response = request.response;
    _applyCors(request, response);
    final sse = SseWriter(response);
    final connection = _SseConnection(sse, session.id);
    _connections.add(connection);
    // The response completes when the peer disconnects or the stream is closed.
    unawaited(
      response.done.then(
        (_) => connection.finish(),
        onError: (Object error, StackTrace stackTrace) => connection.finish(),
      ),
    );
    final ping = Timer.periodic(_pingInterval, (_) async {
      await sse.comment('ping');
      if (sse.isClosed) connection.finish();
    });
    StreamSubscription<Map<String, dynamic>>? subscription;
    try {
      sse.start();
      if (endpoint != null) {
        // The 2024-11-05 handshake, which also flushes the headers.
        await sse.endpoint(endpoint);
      } else {
        // Nothing to relay yet, but the client must see the stream open.
        await sse.comment('connected');
      }
      if (sse.isClosed) {
        logger.d('MCP: the client left before its stream opened');
        return;
      }
      subscription = session.outgoing.listen(
        (message) async {
          await sse.message(message);
          if (sse.isClosed) connection.finish();
        },
        onError: _logStreamError,
        onDone: connection.finish,
      );
      await connection.done;
    } catch (error, stackTrace) {
      logger.e('MCP event stream failed', error: error, stackTrace: stackTrace);
    } finally {
      ping.cancel();
      await subscription?.cancel();
      connection.finish();
      _connections.remove(connection);
      if (dispose) _dropSession(session.id);
      await sse.close();
    }
  }

  void _logStreamError(Object error, StackTrace stackTrace) => logger.e(
    'MCP session notification stream failed',
    error: error,
    stackTrace: stackTrace,
  );

  // ------------------------------------------------------------------ shared

  /// Runs one message through the core while collecting the notifications the
  /// handlers emit, so the caller can pick the response encoding afterwards.
  Future<Map<String, dynamic>?> _dispatch(
    McpServer core,
    McpSessionState session,
    Map<String, dynamic> message,
    List<Map<String, dynamic>> notifications,
  ) async {
    final subscription = session.outgoing.listen(notifications.add);
    try {
      return await core.handle(session, message);
    } finally {
      await subscription.cancel();
    }
  }

  /// `initialize` is the one request allowed to arrive without a session; every
  /// other message has to name an existing one.
  bool _isInitialize(Map<String, dynamic> message) =>
      message['method'] == 'initialize' && message['id'] != null;

  McpSessionState _createSession(McpServer core) {
    final session = core.createSession();
    _sessions[session.id] = _TrackedSession(lastSeen: DateTime.now());
    _enforceSessionLimit();
    return session;
  }

  void _enforceSessionLimit() {
    while (_sessions.length > _maxSessions) {
      // Insertion order is creation order, so the first key is the oldest one.
      final oldest = _sessions.keys.first;
      logger.d('MCP: session limit reached, dropping the oldest session');
      _dropSession(oldest);
    }
  }

  void _dropSession(String id) {
    _sessions.remove(id);
    final connections = [
      for (final connection in _connections)
        if (connection.sessionId == id) connection,
    ];
    for (final connection in connections) {
      _connections.remove(connection);
      unawaited(connection.close());
    }
    _core?.disposeSession(id);
  }

  void _touch(String id) {
    final tracked = _sessions[id];
    if (tracked != null) tracked.lastSeen = DateTime.now();
  }

  void _sweepIdleSessions() {
    if (_server == null) return;
    final cutoff = DateTime.now().subtract(_idleTimeout);
    final idle = [
      for (final entry in _sessions.entries)
        if (entry.value.lastSeen.isBefore(cutoff)) entry.key,
    ];
    if (idle.isEmpty) return;
    logger.d('MCP: dropping ${idle.length} idle session(s)');
    for (final id in idle) {
      _dropSession(id);
    }
  }

  /// Reads the body, returning `null` once it exceeds [_maxBodyBytes]. The
  /// declared length is checked first so a huge upload is not buffered at all.
  Future<Uint8List?> _readBody(HttpRequest request) async {
    if (request.contentLength > _maxBodyBytes) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > _maxBodyBytes) return null;
    }
    return builder.takeBytes();
  }

  /// Decodes one JSON-RPC message object.
  ///
  /// Throws [JsonRpcException] with [JsonRpcCode.parseError] for malformed JSON
  /// and with [JsonRpcCode.invalidRequest] for a batch or a non object: batches
  /// are gone from 2025-06-18 and this server never produces them.
  Map<String, dynamic> _decodeMessage(Uint8List body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException {
      throw const JsonRpcException(JsonRpcCode.parseError, 'invalid JSON body');
    }
    if (decoded is List) {
      throw const JsonRpcException(
        JsonRpcCode.invalidRequest,
        'JSON-RPC batches are not supported',
      );
    }
    if (decoded is! Map) {
      throw const JsonRpcException(
        JsonRpcCode.invalidRequest,
        'request must be a JSON object',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// [_decodeMessage] that answers the client and returns `null` on a bad body.
  Future<Map<String, dynamic>?> _decodeOrReject(
    HttpRequest request,
    Uint8List body,
  ) async {
    try {
      return _decodeMessage(body);
    } on JsonRpcException catch (e) {
      await _sendError(request, HttpStatus.badRequest, e.code, e.message);
      return null;
    }
  }

  bool _isJsonRequest(HttpRequest request) {
    final ContentType? contentType;
    try {
      contentType = request.headers.contentType;
    } on FormatException {
      return false;
    }
    if (contentType == null) return false;
    if (contentType.mimeType == 'application/json') return true;
    // Structured syntax suffix, e.g. application/vnd.api+json.
    return contentType.subType.endsWith('+json');
  }

  bool _acceptsEventStream(HttpRequest request) {
    final values = request.headers[HttpHeaders.acceptHeader];
    if (values == null) return false;
    for (final value in values) {
      if (value.toLowerCase().contains('text/event-stream')) return true;
    }
    return false;
  }

  /// First value of [name], `null` when absent.
  ///
  /// `HttpHeaders.value` throws when a header arrives more than once, which is
  /// exactly what a hostile client would try, so the list form is used here.
  String? _header(HttpRequest request, String name) {
    final values = request.headers[name];
    if (values == null || values.isEmpty) return null;
    return values.first.trim();
  }

  bool _isAllowedOrigin(HttpRequest request, String origin) =>
      isAllowedOrigin(origin, host: _header(request, HttpHeaders.hostHeader));

  Future<void> _preflight(HttpRequest request, String? origin) async {
    if (origin != null) {
      if (!_isAllowedOrigin(request, origin)) {
        await _sendError(
          request,
          HttpStatus.forbidden,
          JsonRpcCode.invalidRequest,
          'origin not allowed',
        );
        return;
      }
      request.response.headers
        ..set(HttpHeaders.accessControlAllowMethodsHeader, _corsMethods)
        ..set(HttpHeaders.accessControlAllowHeadersHeader, _corsHeaders)
        ..set(HttpHeaders.accessControlMaxAgeHeader, _corsMaxAge);
    }
    await _respondEmpty(request, HttpStatus.noContent);
  }

  String _normalizePath(String path) {
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  // --------------------------------------------------------------- responses

  void _applyCors(HttpRequest request, HttpResponse response) {
    final origin = _header(request, _originHeaderName);
    if (origin == null || !_isAllowedOrigin(request, origin)) return;
    response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, origin)
      ..set('Access-Control-Expose-Headers', _corsExposeHeaders)
      ..set(HttpHeaders.varyHeader, 'Origin');
  }

  Future<void> _respondJson(
    HttpRequest request,
    int status,
    Object? body, {
    String? sessionId,
  }) async {
    final String encoded;
    try {
      encoded = jsonEncode(body);
    } catch (error, stackTrace) {
      logger.e(
        'MCP transport could not encode a response',
        error: error,
        stackTrace: stackTrace,
      );
      await _sendError(
        request,
        HttpStatus.internalServerError,
        JsonRpcCode.internalError,
        'internal error',
      );
      return;
    }
    final response = request.response;
    try {
      response.statusCode = status;
      response.headers.contentType = ContentType.json;
      if (sessionId != null) response.headers.set(_sessionIdHeader, sessionId);
      _applyCors(request, response);
      response.write(encoded);
      await response.close();
    } catch (error) {
      logger.d('MCP transport could not write its response ($error)');
    }
  }

  Future<void> _respondEmpty(
    HttpRequest request,
    int status, {
    String? sessionId,
  }) async {
    final response = request.response;
    try {
      response.statusCode = status;
      if (sessionId != null) response.headers.set(_sessionIdHeader, sessionId);
      _applyCors(request, response);
      await response.close();
    } catch (error) {
      logger.d('MCP transport could not close its response ($error)');
    }
  }

  Future<void> _respondEventStream(
    HttpRequest request,
    List<Map<String, dynamic>> frames,
    String sessionId,
  ) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.set(_sessionIdHeader, sessionId);
    _applyCors(request, response);
    final sse = SseWriter(response);
    sse.start();
    for (final frame in frames) {
      await sse.message(frame);
    }
    await sse.close();
  }

  Future<void> _unauthorized(HttpRequest request) async {
    request.response.headers.set(
      HttpHeaders.wwwAuthenticateHeader,
      _wwwAuthenticateValue,
    );
    await _sendError(
      request,
      HttpStatus.unauthorized,
      JsonRpcCode.invalidRequest,
      'missing or invalid bearer token',
    );
  }

  Future<void> _methodNotAllowed(HttpRequest request, String allow) async {
    request.response.headers.set(HttpHeaders.allowHeader, allow);
    await _sendError(
      request,
      HttpStatus.methodNotAllowed,
      JsonRpcCode.invalidRequest,
      'method not allowed',
    );
  }

  Future<void> _sendError(
    HttpRequest request,
    int status,
    int code,
    String message,
  ) async {
    final response = request.response;
    try {
      response.statusCode = status;
      response.headers.contentType = ContentType.json;
      _applyCors(request, response);
      response.write(
        jsonEncode(jsonRpcFailure(null, JsonRpcException(code, message))),
      );
      await response.close();
    } catch (error) {
      logger.d('MCP transport could not send an error response ($error)');
    }
  }
}

/// When a session last did something; the core does not need to know.
class _TrackedSession {
  _TrackedSession({required this.lastSeen});

  DateTime lastSeen;
}

/// One open event stream plus the signal that ends its handler.
class _SseConnection {
  _SseConnection(this.writer, this.sessionId);

  final SseWriter writer;
  final String sessionId;
  final Completer<void> _done = Completer<void>();

  Future<void> get done => _done.future;

  void finish() {
    if (!_done.isCompleted) _done.complete();
  }

  Future<void> close() async {
    finish();
    await writer.close();
  }
}
