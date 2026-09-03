import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
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

  /// 会话因认证连续失败被锁死：配对码已作废，「对方可直接重试」这类提示不适用。
  final bool locked;

  /// 对方协议版本不同：配对码仍有效，但对方升级之前重试没有意义。
  final bool incompatible;

  const LanReceiveFailed(
    this.message, {
    this.locked = false,
    this.incompatible = false,
  });
}

/// 局域网接收端：[IHttpServer] 上的一次性会话（PIN / 盐随 [start] 生成，[stop]
/// 即作废）。三个端点：
/// - `GET  handshake` → 明文 `{app, proto, ver, salt}`；
/// - `GET  manifest`  → 会话密钥加密的本机 manifest 投影（发送方据此算增量）；
/// - `POST archive`   → 加密 zip（服务器层已流式落盘）→ 解压导入（engine.pull，
///   LWW 与云同步一致）→ 回加密报告。一次只处理一个归档（并发 409）。
///
/// 带令牌的两个端点先验令牌再验 [lanProtoHeader]：协议不同回 426，且只有持会话密钥的
/// 对端才改得动本页状态。
class LanReceiverService {
  LanReceiverService({
    this._crypto = const RustLanCrypto(),
    this._server,
    Future<SyncManifest> Function()? manifestBuilder,
    Future<SyncReport> Function(String zipPath, String zipPassword)?
    archiveApplier,
    this._tempDirPath,
    Future<String> Function()? appVersion,
  }) : _manifestBuilder = manifestBuilder ?? LocalArchive.buildLocalManifest,
       _archiveApplier = archiveApplier ?? _applyArchive,
       _appVersion = appVersion ?? lanLocalAppVersion;

  static Future<SyncReport> _applyArchive(String zipPath, String zipPassword) =>
      LocalArchive.import(zipPath, password: zipPassword);

  final LanCrypto _crypto;
  final Future<SyncManifest> Function() _manifestBuilder;
  final Future<SyncReport> Function(String, String) _archiveApplier;
  final String? _tempDirPath;
  final Future<String> Function() _appVersion;

  final ValueNotifier<LanReceiveState> state = ValueNotifier(
    const LanReceiveWaiting(),
  );

  IHttpServer? _server;
  late String pin;

  /// 本机 App 版本（线上形式），[start] 后有效；握手与 mDNS TXT 都带它。
  String version = '';
  String _salt = '';
  List<int> _key = const [];
  bool _busy = false;

  /// 已用过的令牌 nonce。只有解得开的令牌才会进来（造得出就等于持有会话密钥），
  /// 所以外人塞不满它。
  final Set<String> _usedNonces = {};

  /// 连续认证失败计数。达到 [lanMaxAuthFailures] 即锁死本次会话——否则 6 位 PIN
  /// 在同网段里是个不限次数的在线预言机。
  int _authFailures = 0;
  bool _authLocked = false;

  String get _tempDir =>
      _tempDirPath ?? PlatformService.get().applicationCachePath;

  int get port => _server!.port;

  bool get isRunning => _server?.isRunning ?? false;

  Future<void> start() async {
    version = await _appVersion();
    pin = lanGeneratePin();
    _salt = lanRandomHex(16);
    _key = await _crypto.deriveKey(salt: _salt, pin: pin);
    _usedNonces.clear();
    _authFailures = 0;
    _authLocked = false;
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
    'ver': version,
    'salt': _salt,
  });

  /// 令牌通过后再比协议版本：不等回 426。头缺失 = 协议 2 的发送端（那一版还没有这个
  /// 头），按 2 放行；[lanProtoVersion] 一旦离开 2，这条宽容要跟着删。
  Future<HttpServerResponse?> _admit(HttpServerRequest request) async {
    final denied = await _checkAuth(request);
    if (denied != null) return denied;
    final peer = int.tryParse(request.headers[lanProtoHeader] ?? '') ?? 2;
    if (peer == lanProtoVersion) return null;
    final message = l10n.sync.errVersionMismatchDetail(
      sender: lanDisplayVersion(request.headers[lanVersionHeader]),
      receiver: lanDisplayVersion(version),
    );
    state.value = LanReceiveFailed(message, incompatible: true);
    return .text(HttpStatus.upgradeRequired, message);
  }

  /// 校验一次性令牌：解得开（= 持有会话密钥）、绑定的 path 与本请求一致、nonce 没
  /// 用过。通过返回 null，否则返回 401。
  Future<HttpServerResponse?> _checkAuth(HttpServerRequest request) async {
    if (_authLocked) {
      return .text(HttpStatus.unauthorized, l10n.sync.lanAuthLocked);
    }
    final header = request.headers[lanAuthHeader];
    final nonce = header == null
        ? null
        : await lanReadAuthToken(_crypto, _key, header, request.path);
    // 令牌重放（nonce 用过）与密钥不对同等处理：都不是合法发送端会做的事。
    if (nonce != null && _usedNonces.add(nonce)) {
      _authFailures = 0;
      return null;
    }
    if (++_authFailures >= lanMaxAuthFailures) {
      _authLocked = true;
      state.value = LanReceiveFailed(l10n.sync.lanAuthLocked, locked: true);
      return .text(HttpStatus.unauthorized, l10n.sync.lanAuthLocked);
    }
    return .text(HttpStatus.unauthorized, '配对码不正确');
  }

  Future<HttpServerResponse> _manifest(HttpServerRequest request) async {
    final denied = await _admit(request);
    if (denied != null) return denied;
    final manifest = await _manifestBuilder();
    final body = await _crypto.encrypt(
      _key,
      utf8.encode(jsonEncode(manifest.toJson())),
    );
    return .ok(body, contentType: 'application/octet-stream');
  }

  Future<HttpServerResponse> _archive(HttpServerRequest request) async {
    final denied = await _admit(request);
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
