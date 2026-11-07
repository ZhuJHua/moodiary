import 'dart:async';

import '../server/mcp_server.dart';

/// Socket level settings of the local MCP endpoint.
class McpTransportConfig {
  const McpTransportConfig({
    required this.port,
    required this.allowLan,
    required this.token,
  });

  /// Preferred port; a busy port is replaced by a free one, reported by
  /// [McpTransport.port].
  final int port;

  /// `false` binds loopback only, `true` binds every interface so other devices
  /// on the LAN can reach the server.
  final bool allowLan;

  /// Bearer token every request has to present.
  final String token;
}

/// One running local HTTP endpoint speaking MCP.
///
/// The concrete implementation owns sockets, HTTP framing, session ids and SSE;
/// it delegates every JSON-RPC frame to the [McpServer] core.
abstract interface class McpTransport {
  Future<void> start(McpTransportConfig config, McpServer server);

  Future<void> stop();

  /// The port actually bound, which may differ from the preferred one.
  int get port;

  /// URLs a client can paste, loopback first; empty while stopped.
  List<Uri> get endpoints;
}
