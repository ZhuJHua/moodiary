import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_sync/src/data/impl/local_archive.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:path/path.dart' as p;

sealed class LanReceiveState {
  const LanReceiveState();
}

class LanReceiveWaiting extends LanReceiveState {
  const LanReceiveWaiting();
}

class LanReceiveReceiving extends LanReceiveState {
  final int received;
  final int? total;

  const LanReceiveReceiving({required this.received, this.total});
}

class LanReceiveImporting extends LanReceiveState {
  const LanReceiveImporting();
}

class LanReceiveDone extends LanReceiveState {
  final SyncReport report;

  const LanReceiveDone(this.report);
}

class LanReceiveFailed extends LanReceiveState {
  final String message;

  const LanReceiveFailed(this.message);
}

/// 局域网接收端：[IHttpServer] 上的一次性会话（PIN / 盐 / challenge 随 [start]
/// 生成，[stop] 即作废）。三个端点：
/// - `GET  handshake` → 明文 `{app, proto, salt, challenge}`；
/// - `GET  manifest`  → 会话密钥加密的本机 manifest 投影（发送方据此算增量）；
/// - `POST archive`   → 加密 zip（服务器层已流式落盘）→ 解压导入（engine.pull，
///   LWW 与云同步一致）→ 回加密报告。一次只处理一个归档（并发 409）。
class LanReceiverService {
  LanReceiverService({
    this._crypto = const RustLanCrypto(),
    this._server,
    Future<SyncManifest> Function()? manifestBuilder,
    Future<SyncReport> Function(String zipPath, String zipPassword)?
    archiveApplier,
    this._tempDirPath,
  }) : _manifestBuilder = manifestBuilder ?? LocalArchive.buildLocalManifest,
       _archiveApplier = archiveApplier ?? _applyArchive;

  static Future<SyncReport> _applyArchive(String zipPath, String zipPassword) =>
      LocalArchive.import(zipPath, password: zipPassword);

  final LanCrypto _crypto;
  final Future<SyncManifest> Function() _manifestBuilder;
  final Future<SyncReport> Function(String, String) _archiveApplier;
  final String? _tempDirPath;

  final ValueNotifier<LanReceiveState> state = ValueNotifier(
    const LanReceiveWaiting(),
  );

  IHttpServer? _server;
  late String pin;
  String _salt = '';
  List<int> _challenge = const [];
  List<int> _key = const [];
  bool _busy = false;

  String get _tempDir =>
      _tempDirPath ?? PlatformService.get().applicationCachePath;

  int get port => _server!.port;

  bool get isRunning => _server?.isRunning ?? false;

  Future<void> start() async {
    pin = lanGeneratePin();
    _salt = lanRandomHex(16);
    _challenge = hexToBytes(lanRandomHex(16));
    _key = await _crypto.deriveKey(salt: _salt, pin: pin);
    final server = _server ??= IHttpServer.create();
    await server.start(
      handler: _handle,
      preferredPort: lanDefaultPort,
      spoolDir: _tempDir,
      // 只有归档上传带请求体，控制面请求不产生进度事件。
      onBodyProgress: (received, total) {
        state.value = LanReceiveReceiving(received: received, total: total);
      },
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
  }

  Future<HttpServerResponse> _handle(HttpServerRequest request) async {
    return switch ((request.method, request.path)) {
      ('GET', lanHandshakePath) => _handshake(),
      ('GET', lanManifestPath) => await _manifest(request),
      ('POST', lanArchivePath) => await _archive(request),
      _ => HttpServerResponse.text(HttpStatus.notFound, '未知端点'),
    };
  }

  HttpServerResponse _handshake() => .json({
    'app': 'moodiary',
    'proto': lanProtoVersion,
    'salt': _salt,
    'challenge': bytesToHex(_challenge),
  });

  /// 校验请求头里的 challenge 回声；通过返回 null，否则返回 401 响应。
  Future<HttpServerResponse?> _checkAuth(HttpServerRequest request) async {
    final header = request.headers[lanAuthHeader];
    if (header != null) {
      try {
        final plain = await _crypto.decrypt(_key, base64Decode(header));
        if (listEquals(plain, _challenge)) return null;
      } catch (_) {}
    }
    return .text(HttpStatus.unauthorized, '配对码不正确');
  }

  Future<HttpServerResponse> _manifest(HttpServerRequest request) async {
    final denied = await _checkAuth(request);
    if (denied != null) return denied;
    final manifest = await _manifestBuilder();
    final body = await _crypto.encrypt(
      _key,
      utf8.encode(jsonEncode(manifest.toJson())),
    );
    return .ok(body, contentType: 'application/octet-stream');
  }

  Future<HttpServerResponse> _archive(HttpServerRequest request) async {
    final denied = await _checkAuth(request);
    if (denied != null) return denied;
    if (_busy) {
      return .text(HttpStatus.conflict, '对方正忙，请稍后再试');
    }
    _busy = true;
    File? inlineSpool;
    try {
      state.value = const LanReceiveImporting();
      // 大归档已由服务器层流式落盘；极小归档内联到内存，这里补落一份。
      String zipPath;
      if (request.bodyFilePath != null) {
        zipPath = request.bodyFilePath!;
      } else {
        inlineSpool = File(
          p.join(_tempDir, 'lan-recv-inline-${lanRandomHex(8)}.zip'),
        );
        await inlineSpool.writeAsBytes(request.body);
        zipPath = inlineSpool.path;
      }
      final report = await _archiveApplier(zipPath, lanZipPassword(_key));
      state.value = LanReceiveDone(report);
      final body = await _crypto.encrypt(
        _key,
        utf8.encode(
          jsonEncode({
            'diaryCount': report.diaryCount,
            'categoryCount': report.categoryCount,
            'failed': report.failed,
            'warning': ?report.warning,
          }),
        ),
      );
      return .ok(body, contentType: 'application/octet-stream');
    } catch (e) {
      state.value = LanReceiveFailed(e.toString());
      // 服务器适配层把异常折叠为 500 + 错误信息，发送方据此展示。
      rethrow;
    } finally {
      _busy = false;
      if (inlineSpool != null) {
        try {
          await inlineSpool.delete();
        } catch (_) {}
      }
    }
  }
}
