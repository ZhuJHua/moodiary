/// Socket level configuration and the transport interface of the local MCP
/// endpoint.
///
/// The config fields are related by one invariant the transport enforces at
/// [McpTransport.start]:
///
/// * [McpTransportConfig.requireToken] may only be `false` while
///   [McpTransportConfig.allowLan] is `false`. A server reachable from the
///   network without a shared secret would publish private diary data to every
///   device on the Wi-Fi, so a config with `allowLan: true, requireToken: false`
///   is a programming error and makes `start` throw [ArgumentError].
/// * When `requireToken` is `true`, `token` has to be non empty; an empty token
///   with the requirement on is not "auth off", it is a server that rejects
///   every request (that is what [McpTransport.start] logs and does).
///
/// Every other rule (origin policy, session ids, `MCP-Protocol-Version`, CORS
/// and the token-less `GET /icon.png`) is independent of `requireToken`.
library;

import 'dart:async';

import '../server/mcp_server.dart';

/// Socket level settings of the local MCP endpoint.
class McpTransportConfig {
  const McpTransportConfig({
    required this.port,
    required this.allowLan,
    required this.token,
    required this.requireToken,
  });

  /// Preferred port; a busy port is replaced by a free one, reported by
  /// [McpTransport.port].
  final int port;

  /// `false` binds loopback only, `true` binds every interface so other devices
  /// on the LAN can reach the server.
  final bool allowLan;

  /// Bearer token every request has to present when [requireToken] is `true`;
  /// ignored otherwise (it may stay empty in that case).
  final String token;

  /// Whether a request has to carry `Authorization: Bearer <token>`.
  ///
  /// `true` keeps the endpoint private behind the shared secret, `false` lets a
  /// client on the same device connect without one. See the library doc for the
  /// invariant tying this to [allowLan].
  final bool requireToken;
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
