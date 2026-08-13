import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_sync/src/data/impl/local_archive.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';

enum LanSendPhase {
  /// 握手 + 拉取对方 manifest。
  connecting,

  /// 引擎锁内构建增量归档。
  packing,

  /// 上传归档（带字节进度）。
  uploading,

  /// 对方解压导入中（等待报告）。
  applying,
}

class LanSendProgress {
  final LanSendPhase phase;
  final int sent;
  final int? total;

  const LanSendProgress(this.phase, {this.sent = 0, this.total});
}

class LanSendResult {
  /// 发出的 manifest 条目数；0 = 对方已是最新，未发生上传。
  final int entryCount;
  final int diaryCount;
  final int categoryCount;
  final int failed;
  final String? warning;

  const LanSendResult({
    required this.entryCount,
    this.diaryCount = 0,
    this.categoryCount = 0,
    this.failed = 0,
    this.warning,
  });

  bool get upToDate => entryCount == 0;

  String describe() {
    if (upToDate) return '对方已是最新，无需发送';
    if (diaryCount == 0 && categoryCount == 0 && failed == 0) {
      return '发送完成，对方已是最新';
    }
    final base = '发送完成：日记 $diaryCount 条 · 分类 $categoryCount 条';
    final extra = [
      if (failed > 0) l10n.sync.warnFailedCount(count: failed),
      ?warning,
    ].join('；');
    return extra.isEmpty ? base : '$base（$extra）';
  }
}

/// 局域网发送端：握手 → 取对方 manifest → 增量打包（加密 zip）→ 流式上传 →
/// 解密对方导入报告。请求全部经统一 [IHttpClient]；一次性会话，无持久状态。
class LanSender {
  LanSender({
    this._crypto = const RustLanCrypto(),
    this._http,
    Future<(String, int)> Function(SyncManifest remote, String zipPassword)?
    archiveBuilder,
  }) : _archiveBuilder = archiveBuilder ?? _buildArchive;

  static Future<(String, int)> _buildArchive(
    SyncManifest remote,
    String zipPassword,
  ) => LocalArchive.exportDelta(remote: remote, zipPassword: zipPassword);

  final LanCrypto _crypto;
  final Future<(String, int)> Function(SyncManifest, String) _archiveBuilder;

  IHttpClient? _http;

  IHttpClient get _client => _http ??= IHttpClient.get();

  static const Duration _controlTimeout = Duration(seconds: 10);

  Future<LanSendResult> send({
    required String host,
    int port = lanDefaultPort,
    required String pin,
    void Function(LanSendProgress progress)? onProgress,
  }) async {
    final base = 'http://$host:$port';
    String? zipPath;
    var uploading = false;
    try {
      onProgress?.call(const LanSendProgress(.connecting));
      final handshake = _decodeHandshake(await _get('$base$lanHandshakePath'));
      final key = await _crypto.deriveKey(
        salt: handshake['salt'] as String,
        pin: pin,
      );
      final auth = base64Encode(
        await _crypto.encrypt(
          key,
          hexToBytes(handshake['challenge'] as String),
        ),
      );

      final manifestCipher = await _get('$base$lanManifestPath', auth: auth);
      final manifest = SyncManifest.fromJson(
        jsonDecode(utf8.decode(await _crypto.decrypt(key, manifestCipher)))
            as Map<String, dynamic>,
      );

      onProgress?.call(const LanSendProgress(.packing));
      final (path, count) = await _archiveBuilder(
        manifest,
        lanZipPassword(key),
      );
      zipPath = path;
      if (count == 0) return const LanSendResult(entryCount: 0);

      uploading = true;
      // 不设超时：对方解压 + 导入大库可能要几分钟。
      final resp = await _client.uploadFile(
        '$base$lanArchivePath',
        filePath: zipPath,
        headers: {
          lanAuthHeader: auth,
          'content-type': 'application/octet-stream',
        },
        onProgress: (sent, total) {
          onProgress?.call(
            sent >= total
                ? const LanSendProgress(.applying)
                : LanSendProgress(.uploading, sent: sent, total: total),
          );
        },
        silent: true,
        throwOnStatus: false,
      );
      _ensureOk(resp.statusCode, resp.data);
      final report = jsonDecode(
        utf8.decode(await _crypto.decrypt(key, resp.data!)),
      ) as Map<String, dynamic>;
      return LanSendResult(
        entryCount: count,
        diaryCount: report['diaryCount'] is int
            ? report['diaryCount'] as int
            : 0,
        categoryCount: report['categoryCount'] is int
            ? report['categoryCount'] as int
            : 0,
        failed: report['failed'] is int ? report['failed'] as int : 0,
        warning: report['warning'] as String?,
      );
    } on HttpException catch (e) {
      throw SyncException(_friendly(e, host, port, uploading: uploading));
    } finally {
      if (zipPath != null) {
        try {
          await File(zipPath).delete();
        } catch (_) {}
      }
    }
  }

  Future<Uint8List> _get(String url, {String? auth}) async {
    final resp = await _client.requestBytes(
      .get,
      url,
      headers: auth == null ? null : {lanAuthHeader: auth},
      timeout: _controlTimeout,
      silent: true,
      throwOnStatus: false,
    );
    _ensureOk(resp.statusCode, resp.data);
    return resp.data!;
  }

  Map<String, dynamic> _decodeHandshake(Uint8List body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } catch (_) {
      throw SyncException(l10n.sync.errNotReceiver);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'moodiary' ||
        decoded['salt'] is! String ||
        decoded['challenge'] is! String) {
      throw SyncException(l10n.sync.errReceiverOffline);
    }
    if (decoded['proto'] != lanProtoVersion) {
      throw SyncException(l10n.sync.errVersionMismatch);
    }
    return decoded;
  }

  void _ensureOk(int? statusCode, List<int>? body) {
    if (statusCode == 200) return;
    final detail = body == null ? '' : utf8.decode(body, allowMalformed: true);
    throw SyncException(switch (statusCode) {
      401 => '配对码不正确',
      409 => '对方正忙，请稍后再试',
      _ => detail.isEmpty ? '对方处理失败（$statusCode）' : '对方处理失败：$detail',
    });
  }

  String _friendly(
    HttpException e,
    String host,
    int port, {
    required bool uploading,
  }) {
    // 上传途中对方断开（掉线 / 关闭接收页）与「根本连不上」是两种情况，分开提示。
    if (uploading) {
      return '传输中断，请确认对方仍停留在接收页后重试';
    }
    return switch (e.type) {
      .timeout => '连接超时，请检查地址和网络',
      .connection => '无法连接对方设备，请确认两台设备连接同一 Wi-Fi',
      _ => '网络异常：${e.message}',
    };
  }
}
