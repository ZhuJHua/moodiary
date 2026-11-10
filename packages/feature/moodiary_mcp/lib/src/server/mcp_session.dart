import 'dart:async';

import '../protocol/mcp_types.dart';

/// Server side state of one MCP session: the negotiated protocol version, the
/// log level the client picked, when it last did something, the server-to-client
/// notification stream and the set of cancelled request ids.
///
/// Transports own the session id; the server keeps the state as long as the
/// transport reports the session alive.
class McpSessionState {
  McpSessionState({required this.id});

  final String id;

  /// `null` until `initialize` negotiated a version.
  String? protocolVersion;

  bool get initialized => protocolVersion != null;

  McpLogLevel logLevel = McpLogLevel.info;

  /// When the session last carried a request; the core prunes idle sessions.
  DateTime lastSeen = DateTime.now();

  void touch() => lastSeen = DateTime.now();

  bool _disposed = false;

  final StreamController<Map<String, dynamic>> _outgoing =
      StreamController<Map<String, dynamic>>.broadcast();

  final Set<Object?> _cancelled = {};

  /// Notifications produced while a request runs; a transport may relay them to
  /// an open SSE stream or drop them.
  Stream<Map<String, dynamic>> get outgoing => _outgoing.stream;

  bool get isDisposed => _disposed;

  bool isCancelled(Object? requestId) => _cancelled.contains(requestId);

  void cancel(Object? requestId) => _cancelled.add(requestId);

  void clearCancelled(Object? requestId) => _cancelled.remove(requestId);

  void notify(Map<String, dynamic> message) {
    if (_disposed) return;
    if (!_outgoing.isClosed) _outgoing.add(message);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _outgoing.close();
  }
}
