/// Server-Sent Events framing for the MCP transports.
///
/// The writer owns exactly one [HttpResponse] and emits the byte sequences MCP
/// clients expect: `event: message` frames carrying one JSON-RPC message each,
/// the legacy `event: endpoint` handshake line and `: ping` comments that keep
/// idle streams alive through proxies.
///
/// Package internal: the public surface of this package is the transport
/// interface, not this helper.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moodiary_logging/moodiary_logging.dart';

const String _contentType = 'text/event-stream; charset=utf-8';

/// Proxies such as nginx buffer event streams unless told otherwise.
const String _accelBufferingHeader = 'x-accel-buffering';

/// Closing a stream whose peer vanished must not hang [stop]; this bounds the
/// wait for the final chunk to reach the socket.
const Duration _closeTimeout = Duration(seconds: 5);

/// Writes SSE frames to one response and reports when the peer is gone.
///
/// Every method is a no-op after the first failed write, so a caller may keep
/// calling [message] from a stream subscription without guarding each call.
class SseWriter {
  SseWriter(this._response);

  final HttpResponse _response;

  bool _closed = false;

  /// `true` once the stream was closed on purpose or the write failed because
  /// the peer disconnected.
  bool get isClosed => _closed;

  /// Sets the SSE response headers. Nothing reaches the socket until the first
  /// frame is written, so a caller that has nothing to say yet sends
  /// `comment('connected')` to flush the headers and confirm the stream.
  void start() {
    _response.bufferOutput = false;
    _response.headers
      ..set(HttpHeaders.contentTypeHeader, _contentType)
      ..set(HttpHeaders.cacheControlHeader, 'no-cache, no-transform')
      ..set(HttpHeaders.connectionHeader, 'keep-alive')
      ..set(_accelBufferingHeader, 'no');
  }

  /// One server to client JSON-RPC message. [jsonEncode] escapes newlines, so a
  /// single `data:` line always carries the whole frame.
  ///
  /// A payload that cannot be encoded is logged and dropped instead of killing
  /// the stream and the subscription that feeds it.
  Future<void> message(Object? payload) async {
    final String data;
    try {
      data = jsonEncode(payload);
    } catch (error, stackTrace) {
      logger.e(
        'MCP: event stream payload is not encodable',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    await _write('event: message\ndata: $data\n\n');
  }

  /// The 2024-11-05 handshake: the URL the client must POST messages to.
  Future<void> endpoint(String uri) =>
      _write('event: endpoint\ndata: $uri\n\n');

  /// A comment line, which every SSE parser ignores; used as a keep alive.
  Future<void> comment(String text) => _write(': $text\n\n');

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _response.close().timeout(_closeTimeout);
    } catch (e) {
      logger.d('MCP: event stream did not close cleanly ($e)');
    }
  }

  Future<void> _write(String frame) async {
    if (_closed) return;
    try {
      _response.write(frame);
      await _response.flush();
    } catch (e) {
      // The peer disconnected; the owner notices through [isClosed] and the
      // completion of `HttpResponse.done`.
      _closed = true;
      logger.d('MCP: event stream is gone ($e)');
    }
  }
}
