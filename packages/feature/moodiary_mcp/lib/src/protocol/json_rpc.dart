/// JSON-RPC 2.0 framing shared by every MCP transport.
///
/// The server only ever consumes requests and notifications from the peer and
/// emits results, errors and notifications; it never sends a request of its
/// own, so a decoded response is dropped instead of answered.
library;

/// Standard JSON-RPC 2.0 codes plus the MCP specific ones.
abstract final class JsonRpcCode {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;

  /// MCP: the requested resource does not exist.
  static const int resourceNotFound = -32002;

  /// MCP: the client cancelled the request before it finished.
  static const int requestCancelled = -32800;
}

class JsonRpcException implements Exception {
  const JsonRpcException(this.code, this.message, {this.data});

  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => 'JsonRpcException($code, $message)';
}

/// One request or notification decoded from the peer.
///
/// [id] is `null` for notifications; JSON-RPC allows any string or integral
/// number as a request id and MCP clients use both.
class JsonRpcRequest {
  const JsonRpcRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  final Object? id;
  final String method;
  final Map<String, dynamic> params;

  bool get isNotification => id == null;

  @override
  String toString() => 'JsonRpcRequest($method, id: $id)';
}

/// Decodes a single JSON-RPC value into a [JsonRpcRequest].
///
/// Returns `null` when the value is a response (handled by nobody, but a peer
/// may still echo one) and throws a [JsonRpcException] with
/// [JsonRpcCode.invalidRequest] for malformed frames.
JsonRpcRequest? parseJsonRpc(Object? raw) {
  if (raw is! Map) {
    throw const JsonRpcException(
      JsonRpcCode.invalidRequest,
      'request must be a JSON object',
    );
  }
  if (raw['jsonrpc'] != '2.0') {
    throw const JsonRpcException(
      JsonRpcCode.invalidRequest,
      'jsonrpc must be exactly "2.0"',
    );
  }
  if (!raw.containsKey('method')) {
    if (raw.containsKey('result') || raw.containsKey('error')) return null;
    throw const JsonRpcException(JsonRpcCode.invalidRequest, 'missing method');
  }
  final method = raw['method'];
  if (method is! String || method.isEmpty) {
    throw const JsonRpcException(
      JsonRpcCode.invalidRequest,
      'method must be a non-empty string',
    );
  }
  final id = raw['id'];
  if (id != null && id is! String && id is! int) {
    throw const JsonRpcException(
      JsonRpcCode.invalidRequest,
      'id must be a string or an integer',
    );
  }
  final params = raw['params'];
  if (params != null && params is! Map) {
    throw const JsonRpcException(
      JsonRpcCode.invalidParams,
      'params must be an object',
    );
  }
  return JsonRpcRequest(
    id: id,
    method: method,
    params: params == null
        ? const {}
        : Map<String, dynamic>.from(params as Map),
  );
}

Map<String, dynamic> jsonRpcResult(Object? id, Object? result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

Map<String, dynamic> jsonRpcFailure(Object? id, JsonRpcException error) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': error.code, 'message': error.message, 'data': ?error.data},
};
