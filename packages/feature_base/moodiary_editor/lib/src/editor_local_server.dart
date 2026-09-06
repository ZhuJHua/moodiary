import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';

import 'media.dart';

@lazySingleton
class EditorLocalServer {
  EditorLocalServer(this._server);

  static const _assetBase = 'packages/moodiary_editor/assets/editor';

  final String _token = _randomToken();
  final IHttpServer _server;
  bool _started = false;
  int _port = 0;
  Future<void>? _starting;

  MediaResolver? mediaResolver;

  ({String family, String path})? Function()? fontResolver;

  Future<String?> Function(String name)? mediaNameResolver;

  static String _randomToken() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static void _log(String msg, {Object? error, int level = 0}) {
    developer.log(msg, name: 'EditorLocalServer', error: error, level: level);
  }

  Future<void> ensureStarted() async {
    if (_started) return;
    _starting ??= _start();
    try {
      await _starting;
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<void> _start() async {
    await _server.start(handler: _handle, loopbackOnly: true);
    _port = _server.port;
    _started = true;
  }

  @disposeMethod
  Future<void> dispose() async {
    if (!_started) return;
    _started = false;
    _starting = null;
    await _server.stop();
  }

  Future<HttpServerResponse> _handle(HttpServerRequest request) async {
    final seg = request.path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (seg.length == 3 && seg[0] == _token && seg[1] == 'media') {
      final name = seg[2];
      final poster = request.query['poster'] == '1';
      try {
        final resolved = _isSafeMediaName(name)
            ? await mediaResolver?.call(name, poster: poster)
            : null;
        if (resolved == null) return .notFound();
        return .file(resolved.path, contentType: resolved.mime);
      } catch (e) {
        _log('media request failed: ${request.path}', error: e, level: 1000);
        return .text(500, 'media request failed');
      }
    }
    if (seg.length == 3 && seg[0] == _token && seg[1] == 'mediainfo') {
      final name = seg[2];
      final resolver = mediaNameResolver;
      if (resolver == null || !_isSafeMediaName(name)) return .notFound();
      try {
        return .json({'name': await resolver(name)});
      } catch (e) {
        _log(
          'mediainfo request failed: ${request.path}',
          error: e,
          level: 1000,
        );
        return .text(500, 'mediainfo request failed');
      }
    }
    if (seg.length == 2 && seg[0] == _token && seg[1] == 'font') {
      try {
        final font = fontResolver?.call();
        if (font == null) return .notFound();
        return .file(
          font.path,
          contentType: _fontMime(font.path),
          headers: const {'cache-control': 'max-age=31536000, immutable'},
        );
      } catch (e) {
        _log('font request failed: ${request.path}', error: e, level: 1000);
        return .text(500, 'font request failed');
      }
    }
    return _serveAsset(request.path);
  }

  Future<HttpServerResponse> _serveAsset(String path) async {
    var rel = path.startsWith('/') ? path.substring(1) : path;
    if (rel.isEmpty) rel = 'index.html';
    if (rel.contains('..') || rel.contains('\\')) {
      return .notFound();
    }
    final contentType = _assetContentType(rel);
    final compressed = await _tryLoadAsset('$_assetBase/$rel.gz');
    if (compressed != null) {
      return HttpServerResponse(
        200,
        headers: {'content-type': contentType},
        body: .fromList(gzip.decode(compressed)),
      );
    }
    final raw = await _tryLoadAsset('$_assetBase/$rel');
    if (raw != null) {
      return HttpServerResponse(
        200,
        headers: {'content-type': contentType},
        body: raw,
      );
    }
    return .notFound();
  }

  static Future<Uint8List?> _tryLoadAsset(String key) async {
    try {
      final data = await rootBundle.load(key);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  static String _assetContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      return 'text/javascript; charset=utf-8';
    }
    if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.json') || lower.endsWith('.map')) {
      return 'application/json; charset=utf-8';
    }
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.wasm')) return 'application/wasm';
    return 'application/octet-stream';
  }

  // video- 长度须 ≥42：宿主 substring(6, 42) 取 uuid 依赖该长度
  static bool _isSafeMediaName(String name) {
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      return false;
    }
    if (name.startsWith('image-')) return name.length > 'image-'.length;
    if (name.startsWith('audio-')) return name.length > 'audio-'.length;
    if (name.startsWith('video-')) return name.length >= 42;
    return false;
  }

  static String _fontMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.otf')) return 'font/otf';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.woff')) return 'font/woff';
    return 'font/ttf';
  }

  String get mediaBase => 'http://localhost:$_port/$_token/media/';

  String get fontBase => 'http://localhost:$_port/$_token/font';

  String get mediaInfoBase => 'http://localhost:$_port/$_token/mediainfo/';

  Uri pageUri(Map<String, dynamic> boot) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(boot)));
    return Uri.parse('http://localhost:$_port/index.html')
        .replace(queryParameters: {'boot': encoded});
  }
}
