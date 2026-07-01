import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'media.dart';

/// 编辑器页面与本地媒体服务，基于 [shelf]（127.0.0.1 回环，进程内懒启动单例，与 webview
/// 插件解耦——纯 dart:io HttpServer，四端同一管线）。
///
/// 编辑器单文件页面（index.html，无运行时同级资源）由 [_serveIndex] 从 Flutter assets
/// （rootBundle，键 [_indexAssetKey]）直接读出；磁盘媒体经 [_makeHandler] 拦截
/// `/<token>/media/<name>` 按需读字节（视频取缩略图，见 [MediaResolver]）—— 懒加载、二进制、
/// 省内存。boot 数据经 base64url 挂在页面 URL 的 `?boot=` 上（web 侧 readBoot 同步解析）。
///
/// 端口：`shelf_io.serve(..., 0)` 让 OS 分配空闲端口，再用 `server.port` 读回实际值——无需
/// 「探测后再传入」的 workaround。token 为每次启动随机生成的 128 位十六进制，拼进媒体 URL
/// 路径并在 handler 校验：防同机其它进程读日记媒体。
class EditorLocalServer {
  EditorLocalServer._();

  static final EditorLocalServer instance = EditorLocalServer._();

  static const _indexAssetKey =
      'packages/moodiary_editor/assets/editor/index.html';

  final String _token = _randomToken();
  HttpServer? _server;
  int _port = 0;
  Future<void>? _starting;

  /// 媒体名 → 磁盘路径 + MIME 的解析器（由宿主 app 注入）。未设置时媒体请求一律 404。
  /// 无头转换（仅 markdown→JSON，不加载媒体）可不设。
  MediaResolver? mediaResolver;

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

  /// 启动（或复用）服务。并发调用共享同一次启动；失败后允许重试。
  Future<void> ensureStarted() async {
    if (_server != null) return;
    _starting ??= _start();
    try {
      await _starting;
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<void> _start() async {
    // 端口 0 → OS 分配空闲端口；server.port 读回实际值。bind 失败时 serve 正常抛出
    // （不再像 InAppLocalhostServer 那样永挂），由 ensureStarted 的 catch 重置并上抛。
    final server = await shelf_io.serve(
      _makeHandler(),
      InternetAddress.loopbackIPv4,
      0,
      poweredByHeader: null,
    );
    _server = server;
    _port = server.port;
  }

  /// 路由：`/<token>/media/<name>`（可带 `?poster=1` 取视频海报）从磁盘供给；其余请求
  /// （页面）回单文件 index.html。媒体走 [_serveFile] 支持 HTTP Range —— WKWebView 的
  /// `<video>` 必须有 206 才能播放，`<audio>`/拖拽定位也依赖 Range。
  Handler _makeHandler() {
    return (Request request) async {
      // shelf 的 request.url 已去前导斜杠，pathSegments[0] 仍是 token。
      final seg = request.url.pathSegments;
      if (seg.length == 3 && seg[0] == _token && seg[1] == 'media') {
        final name = seg[2];
        final poster = request.url.queryParameters['poster'] == '1';
        try {
          final resolved = _isSafeMediaName(name)
              ? mediaResolver?.call(name, poster: poster)
              : null;
          if (resolved == null) return Response.notFound(null);
          return await _serveFile(request, resolved.path, resolved.mime);
        } catch (e) {
          _log(
            'media request failed: ${request.url.path}',
            error: e,
            level: 1000,
          );
          return Response.internalServerError();
        }
      }
      return _serveIndex();
    };
  }

  /// 单文件页面：直接从 rootBundle 读 index.html 字节返回。该目录只有一个 index.html
  /// （单文件构建，无运行时同级资源），故无需目录式服务；将来若变多文件再扩展。
  Future<Response> _serveIndex() async {
    final data = await rootBundle.load(_indexAssetKey);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return Response.ok(
      bytes,
      headers: const {
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
      },
    );
  }

  /// 从磁盘供给单个文件，支持单段 HTTP Range：
  /// - 无 Range → 200 全量（带 `Accept-Ranges: bytes`，浏览器据此后续发 Range）；
  /// - 合法 Range → 206 + `Content-Range` + 精确 `Content-Length`，只读对应区间；
  /// - 不可满足的 Range → 416 + `Content-Range: bytes */total`。
  Future<Response> _serveFile(Request request, String path, String mime) async {
    final file = File(path);
    if (!await file.exists()) return Response.notFound(null);
    final total = await file.length();

    final rangeHeader = request.headers[HttpHeaders.rangeHeader];
    final range = rangeHeader == null ? null : _parseRange(rangeHeader, total);

    if (rangeHeader != null && range == null) {
      return Response(
        HttpStatus.requestedRangeNotSatisfiable, // 416
        headers: {HttpHeaders.contentRangeHeader: 'bytes */$total'},
      );
    }
    if (range == null) {
      return Response.ok(
        file.openRead(),
        headers: {
          HttpHeaders.acceptRangesHeader: 'bytes',
          HttpHeaders.contentTypeHeader: mime,
          HttpHeaders.contentLengthHeader: '$total',
        },
      );
    }
    final (start, end) = range; // 闭区间
    return Response(
      HttpStatus.partialContent, // 206
      body: file.openRead(start, end + 1),
      headers: {
        HttpHeaders.acceptRangesHeader: 'bytes',
        HttpHeaders.contentTypeHeader: mime,
        HttpHeaders.contentRangeHeader: 'bytes $start-$end/$total',
        HttpHeaders.contentLengthHeader: '${end - start + 1}',
      },
    );
  }

  /// 解析单段 Range（`bytes=start-end` / `bytes=start-` / `bytes=-suffix`）为闭区间
  /// (start, end)。多段 / 语法错误 / 起点越界返回 null（调用方回 416）。
  static (int, int)? _parseRange(String header, int total) {
    if (total <= 0) return null;
    const prefix = 'bytes=';
    if (!header.startsWith(prefix)) return null;
    final spec = header.substring(prefix.length).trim();
    if (spec.isEmpty || spec.contains(',')) return null; // 多段不支持
    final dash = spec.indexOf('-');
    if (dash < 0) return null;
    final startStr = spec.substring(0, dash).trim();
    final endStr = spec.substring(dash + 1).trim();
    int start;
    int end;
    if (startStr.isEmpty) {
      // `-suffix`：末尾 N 字节。
      final suffix = int.tryParse(endStr);
      if (suffix == null || suffix <= 0) return null;
      start = suffix >= total ? 0 : total - suffix;
      end = total - 1;
    } else {
      final s = int.tryParse(startStr);
      if (s == null || s < 0) return null;
      start = s;
      if (endStr.isEmpty) {
        end = total - 1;
      } else {
        final e = int.tryParse(endStr);
        if (e == null || e < 0) return null;
        end = e;
      }
    }
    if (start >= total) return null; // 起点越界
    if (end >= total) end = total - 1;
    if (start > end) return null;
    return (start, end);
  }

  /// 媒体名必须是 `image-` / `audio-` / `video-` 前缀的裸文件名：拒绝路径分隔（含反斜杠）、
  /// 上跳与盘符，防越权读任意文件；video- 须 ≥42 字符，因海报解析（宿主侧 `substring(6, 42)`
  /// 取 uuid）依赖该长度。
  static bool _isSafeMediaName(String name) {
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      return false;
    }
    if (name.startsWith('image-')) return name.length > 'image-'.length;
    if (name.startsWith('audio-')) return name.length > 'audio-'.length;
    if (name.startsWith('video-')) return name.length >= 42;
    return false;
  }

  /// 媒体 URL 前缀（注入 boot.mediaBase，web 侧 linkBase 用它拼显示 URL）。
  /// 仅在 [ensureStarted] 完成后可用。
  String get mediaBase => 'http://localhost:$_port/$_token/media/';

  /// 编辑器页面 URL，boot 数据经 base64url 挂在 query 上。仅在 [ensureStarted] 完成后可用。
  Uri pageUri(Map<String, dynamic> boot) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(boot)));
    return Uri.parse(
      'http://localhost:$_port/index.html',
    ).replace(queryParameters: {'boot': encoded});
  }
}
