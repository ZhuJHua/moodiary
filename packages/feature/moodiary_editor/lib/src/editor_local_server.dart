import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:moodiary_core/moodiary_core.dart';

import 'media.dart';

/// 编辑器页面与本地媒体服务，基于统一 [IHttpServer]（127.0.0.1 回环，进程内懒启动
/// 单例，与 webview 插件解耦，四端同一管线）。
///
/// 编辑器单文件页面（index.html，无运行时同级资源）由 [_serveIndex] 从 Flutter assets
/// （rootBundle，键 [_indexAssetKey]）直接读出；磁盘媒体经 handler 拦截
/// `/<token>/media/<name>` 按文件路径响应（视频取缩略图，见 [MediaResolver]）——
/// 文件流式发送与 HTTP Range（WKWebView 的 `<video>` 必须有 206 才能播放）由
/// 服务器层统一处理。boot 数据经 base64url 挂在页面 URL 的 `?boot=` 上（web 侧
/// readBoot 同步解析）。
///
/// 端口：`preferredPort: 0` 让 OS 分配空闲端口，再用 [IHttpServer.port] 读回实际值。
/// token 为每次启动随机生成的 128 位十六进制，拼进媒体 URL 路径并在 handler 校验：
/// 防同机其它进程读日记媒体。
class EditorLocalServer {
  EditorLocalServer._();

  static final EditorLocalServer instance = EditorLocalServer._();

  static const _indexAssetKey =
      'packages/moodiary_editor/assets/editor/index.html';

  final String _token = _randomToken();
  IHttpServer? _server;
  int _port = 0;
  Future<void>? _starting;

  /// 媒体名 → 磁盘路径 + MIME 的解析器（由宿主 app 注入）。未设置时媒体请求一律 404。
  /// 无头转换（仅 markdown→JSON，不加载媒体）可不设。
  MediaResolver? mediaResolver;

  /// 当前自定义字体 → 家族名 + 磁盘路径的解析器（由宿主 app 注入）。返回 null（或未设置）
  /// 表示系统字体，字体请求一律 404。web 侧用 @font-face 加载该文件，使编辑器正文与 App 同字体。
  /// 每次请求都实时调用，故切换字体后无需重启服务。
  ({String family, String path})? Function()? fontResolver;

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
    final server = IHttpServer.create();
    await server.start(handler: _handle, loopbackOnly: true);
    _server = server;
    _port = server.port;
  }

  /// 路由：`/<token>/media/<name>`（可带 `?poster=1` 取视频海报）与 `/<token>/font`
  /// 以文件路径响应（流式 + Range 由服务器层处理，文件不存在时服务器回 404）；
  /// 其余请求（页面）回单文件 index.html。
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
            ? mediaResolver?.call(name, poster: poster)
            : null;
        if (resolved == null) return HttpServerResponse.notFound();
        return HttpServerResponse.file(
          resolved.path,
          contentType: resolved.mime,
        );
      } catch (e) {
        _log('media request failed: ${request.path}', error: e, level: 1000);
        return HttpServerResponse.text(500, 'media request failed');
      }
    }
    // `/<token>/font`：供当前激活的自定义字体文件（web 侧 @font-face 的 src，查询串
    // `?v=<family>` 仅用于换字体时破缓存，服务端忽略）。系统字体时 resolver 回 null → 404。
    if (seg.length == 2 && seg[0] == _token && seg[1] == 'font') {
      try {
        final font = fontResolver?.call();
        if (font == null) return HttpServerResponse.notFound();
        return HttpServerResponse.file(
          font.path,
          contentType: _fontMime(font.path),
        );
      } catch (e) {
        _log('font request failed: ${request.path}', error: e, level: 1000);
        return HttpServerResponse.text(500, 'font request failed');
      }
    }
    return _serveIndex();
  }

  /// 单文件页面：直接从 rootBundle 读 index.html 字节返回。该目录只有一个 index.html
  /// （单文件构建，无运行时同级资源），故无需目录式服务；将来若变多文件再扩展。
  Future<HttpServerResponse> _serveIndex() async {
    final data = await rootBundle.load(_indexAssetKey);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return HttpServerResponse.ok(
      bytes,
      contentType: 'text/html; charset=utf-8',
    );
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

  /// 按后缀推断字体 MIME（web 侧 @font-face 加载据此选解析器）。
  static String _fontMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.otf')) return 'font/otf';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.woff')) return 'font/woff';
    return 'font/ttf';
  }

  /// 媒体 URL 前缀（注入 boot.mediaBase，web 侧 linkBase 用它拼显示 URL）。
  /// 仅在 [ensureStarted] 完成后可用。
  String get mediaBase => 'http://localhost:$_port/$_token/media/';

  /// 字体文件 URL（注入 boot.fontBase，web 侧用它作 @font-face 的 src）。
  /// 仅在 [ensureStarted] 完成后可用。
  String get fontBase => 'http://localhost:$_port/$_token/font';

  /// 编辑器页面 URL，boot 数据经 base64url 挂在 query 上。仅在 [ensureStarted] 完成后可用。
  Uri pageUri(Map<String, dynamic> boot) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(boot)));
    return Uri.parse(
      'http://localhost:$_port/index.html',
    ).replace(queryParameters: {'boot': encoded});
  }
}
