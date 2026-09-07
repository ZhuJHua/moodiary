import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary_di/moodiary_di.dart';
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

  final bool locked;

  final bool incompatible;

  const LanReceiveFailed(
    this.message, {
    this.locked = false,
    this.incompatible = false,
  });
}

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

  String version = '';
  String _salt = '';
  List<int> _key = const [];
  bool _busy = false;

  final Set<String> _usedNonces = {};

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
    final server = _server ??= getIt<IHttpServer>();
    await server.start(
      handler: _handle,
      preferredPort: lanDefaultPort,
      spoolDir: _tempDir,
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

  Future<HttpServerResponse?> _admit(HttpServerRequest request) async {
    final denied = await _checkAuth(request);
    if (denied != null) return denied;
    final peer = int.tryParse(request.headers[lanProtoHeader] ?? '');
    if (peer == lanProtoVersion) return null;
    final message = l10n.sync.errVersionMismatchDetail(
      sender: lanDisplayVersion(request.headers[lanVersionHeader]),
      receiver: lanDisplayVersion(version),
    );
    state.value = LanReceiveFailed(message, incompatible: true);
    return .text(HttpStatus.upgradeRequired, message);
  }

  Future<HttpServerResponse?> _checkAuth(HttpServerRequest request) async {
    if (_authLocked) {
      return .text(HttpStatus.unauthorized, l10n.sync.lanAuthLocked);
    }
    final header = request.headers[lanAuthHeader];
    final nonce = header == null
        ? null
        : await lanReadAuthToken(_crypto, _key, header, request.path);
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
