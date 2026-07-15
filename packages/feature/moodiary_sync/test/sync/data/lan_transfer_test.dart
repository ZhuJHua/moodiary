import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/lan/lan_receiver.dart';
import 'package:moodiary_sync/src/data/lan/lan_sender.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/sync.dart';
import 'package:path/path.dart' as p;

/// 纯 Dart 假加密：key = utf8('salt|pin')；密文 = key ++ 明文；解密校验 key 前缀，
/// 不匹配即抛 —— 保留「密钥错则解密失败」的认证语义。
final class FakeLanCrypto implements LanCrypto {
  @override
  Future<List<int>> deriveKey({
    required String salt,
    required String pin,
  }) async => utf8.encode('$salt|$pin');

  @override
  Future<Uint8List> encrypt(List<int> key, List<int> plain) async =>
      Uint8List.fromList([...key, ...plain]);

  @override
  Future<Uint8List> decrypt(List<int> key, List<int> cipher) async {
    if (cipher.length < key.length ||
        !listEquals(cipher.sublist(0, key.length), key)) {
      throw Exception('密钥不匹配');
    }
    return Uint8List.fromList(cipher.sublist(key.length));
  }
}

/// 测试用 [IHttpServer]：dart:io 实现，模拟生产（Rust）语义 —— 请求体超阈值落盘、
/// 进度回调、handler 异常折叠为 500。生产实现 RustHttpServer 需要原生库，
/// flutter test 环境不可用。
final class IoTestHttpServer extends IHttpServer {
  static const int _spoolThreshold = 1024;
  static int _seq = 0;

  io.HttpServer? _io;

  @override
  int get port => _io!.port;

  @override
  bool get isRunning => _io != null;

  @override
  Future<void> start({
    required HttpServerHandler handler,
    int preferredPort = 0,
    bool loopbackOnly = false,
    String? spoolDir,
    void Function(int received, int? total)? onBodyProgress,
  }) async {
    final address = loopbackOnly
        ? io.InternetAddress.loopbackIPv4
        : io.InternetAddress.anyIPv4;
    try {
      _io = await io.HttpServer.bind(address, preferredPort);
    } on io.SocketException {
      _io = await io.HttpServer.bind(address, 0);
    }
    _io!.listen((req) async {
      try {
        final total = req.contentLength > 0 ? req.contentLength : null;
        final builder = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in req) {
          builder.add(chunk);
          received += chunk.length;
          onBodyProgress?.call(received, total);
        }
        final bytes = builder.takeBytes();
        String? bodyFile;
        var inline = Uint8List(0);
        if (bytes.length > _spoolThreshold) {
          final file = io.File(
            p.join(
              spoolDir ?? io.Directory.systemTemp.path,
              'test-spool-${_seq++}.tmp',
            ),
          );
          await file.writeAsBytes(bytes);
          bodyFile = file.path;
        } else {
          inline = Uint8List.fromList(bytes);
        }
        final headers = <String, String>{};
        req.headers.forEach(
          (key, values) => headers[key.toLowerCase()] = values.join(','),
        );
        HttpServerResponse response;
        try {
          response = await handler(
            HttpServerRequest(
              method: req.method.toUpperCase(),
              path: req.uri.path,
              query: req.uri.queryParameters,
              headers: headers,
              body: inline,
              bodyFilePath: bodyFile,
            ),
          );
        } catch (e) {
          response = HttpServerResponse.text(500, e.toString());
        }
        if (bodyFile != null) {
          try {
            await io.File(bodyFile).delete();
          } catch (_) {}
        }
        req.response.statusCode = response.statusCode;
        response.headers.forEach((k, v) => req.response.headers.set(k, v));
        req.response.contentLength = response.body.length;
        req.response.add(response.body);
        await req.response.close();
      } catch (_) {
        try {
          await req.response.close();
        } catch (_) {}
      }
    });
  }

  @override
  Future<void> stop() async {
    final server = _io;
    _io = null;
    await server?.close(force: true);
  }
}

/// 测试用 [IHttpClient]：dart:io 实现 requestBytes / uploadFile（生产 RustHttpClient
/// 需要原生库）。
final class IoTestHttpClient extends IHttpClient {
  final io.HttpClient _client = io.HttpClient();

  @override
  Future<HttpResponse<T>> request<T>(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool plainText = false,
  }) => throw UnimplementedError();

  @override
  Future<HttpResponse<Uint8List>> requestBytes(
    HttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    HttpBody? body,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  }) async {
    try {
      final req = await _client.openUrl(
        method.name.toUpperCase(),
        Uri.parse(url),
      );
      headers?.forEach((k, v) {
        if (v != null) req.headers.set(k, '$v');
      });
      if (body != null) req.add(body.bytes);
      final resp = await req.close();
      return _finish(resp, throwOnStatus);
    } on io.SocketException catch (e) {
      throw HttpException(HttpErrorType.connection, e.message);
    }
  }

  @override
  Future<HttpResponse<Uint8List>> uploadFile(
    String url, {
    required String filePath,
    HttpMethod method = HttpMethod.post,
    Map<String, dynamic>? headers,
    void Function(int sent, int total)? onProgress,
    Duration? timeout,
    bool silent = false,
    bool? throwOnStatus,
  }) async {
    try {
      final req = await _client.openUrl(
        method.name.toUpperCase(),
        Uri.parse(url),
      );
      headers?.forEach((k, v) {
        if (v != null) req.headers.set(k, '$v');
      });
      final file = io.File(filePath);
      final total = await file.length();
      req.contentLength = total;
      var sent = 0;
      await req.addStream(
        file.openRead().map((chunk) {
          sent += chunk.length;
          onProgress?.call(sent, total);
          return chunk;
        }),
      );
      final resp = await req.close();
      return _finish(resp, throwOnStatus);
    } on io.SocketException catch (e) {
      throw HttpException(HttpErrorType.connection, e.message);
    }
  }

  Future<HttpResponse<Uint8List>> _finish(
    io.HttpClientResponse resp,
    bool? throwOnStatus,
  ) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in resp) {
      builder.add(chunk);
    }
    if (throwOnStatus != false &&
        (resp.statusCode < 200 || resp.statusCode >= 300)) {
      throw HttpException(
        HttpErrorType.statusCode,
        'HTTP ${resp.statusCode}',
        statusCode: resp.statusCode,
      );
    }
    return HttpResponse(
      statusCode: resp.statusCode,
      data: builder.takeBytes(),
      headers: const {},
    );
  }
}

void main() {
  late io.Directory tmp;

  setUp(() async {
    tmp = await io.Directory.systemTemp.createTemp('lan-transfer-test-');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  final receiverManifest = SyncManifest(
    version: SyncManifest.currentVersion,
    updatedAtMs: 42,
    entries: {'d:existing': const ManifestEntry(timeMs: 12345)},
  );

  LanReceiverService buildReceiver({
    required Future<SyncReport> Function(String, String) applier,
  }) => LanReceiverService(
    crypto: FakeLanCrypto(),
    server: IoTestHttpServer(),
    tempDirPath: tmp.path,
    manifestBuilder: () async => receiverManifest,
    archiveApplier: applier,
  );

  test('环回：握手 → 取清单 → 上传 → 报告', () async {
    SyncManifest? builderGotManifest;
    String? builderGotPassword;
    String? applierGotPassword;
    List<int>? applierGotBytes;
    final archiveBytes = List<int>.generate(300000, (i) => i % 251);

    final receiver = buildReceiver(
      applier: (zipPath, password) async {
        applierGotPassword = password;
        applierGotBytes = await io.File(zipPath).readAsBytes();
        return const SyncReport(
          diaryCount: 3,
          categoryCount: 1,
          elapsed: Duration.zero,
          warning: '1 个条目同步失败已跳过',
          failed: 1,
        );
      },
    );
    await receiver.start();
    addTearDown(receiver.stop);

    final sender = LanSender(
      crypto: FakeLanCrypto(),
      http: IoTestHttpClient(),
      archiveBuilder: (remote, password) async {
        builderGotManifest = remote;
        builderGotPassword = password;
        final file = io.File(p.join(tmp.path, 'delta.zip'));
        await file.writeAsBytes(archiveBytes);
        return (file.path, 4);
      },
    );

    final phases = <LanSendPhase>[];
    final result = await sender.send(
      host: '127.0.0.1',
      port: receiver.port,
      pin: receiver.pin,
      onProgress: (progress) => phases.add(progress.phase),
    );

    // 对方 manifest 原样到达发送方
    expect(builderGotManifest!.updatedAtMs, 42);
    expect(builderGotManifest!.entries['d:existing']!.timeMs, 12345);
    // 双方对同一 key 派生出同一 zip 密码
    expect(builderGotPassword, applierGotPassword);
    // 归档字节完整送达
    expect(applierGotBytes, archiveBytes);
    // 报告回传
    expect(result.entryCount, 4);
    expect(result.diaryCount, 3);
    expect(result.categoryCount, 1);
    expect(result.failed, 1);
    expect(result.warning, '1 个条目同步失败已跳过');
    expect(
      phases.toSet(),
      containsAll([
        LanSendPhase.connecting,
        LanSendPhase.packing,
        LanSendPhase.uploading,
        LanSendPhase.applying,
      ]),
    );
    // 接收端状态收敛到 done
    expect(receiver.state.value, isA<LanReceiveDone>());
  });

  test('配对码错误 → 401，明确报错，不触发导入', () async {
    var applied = false;
    final receiver = buildReceiver(
      applier: (_, _) async {
        applied = true;
        return const SyncReport(
          diaryCount: 0,
          categoryCount: 0,
          elapsed: Duration.zero,
        );
      },
    );
    await receiver.start();
    addTearDown(receiver.stop);

    final sender = LanSender(
      crypto: FakeLanCrypto(),
      http: IoTestHttpClient(),
      archiveBuilder: (_, _) async => fail('不应走到打包'),
    );
    await expectLater(
      sender.send(host: '127.0.0.1', port: receiver.port, pin: '000000'),
      throwsA(
        isA<SyncException>().having(
          (e) => e.message,
          'message',
          contains('配对码不正确'),
        ),
      ),
    );
    expect(applied, isFalse);
  });

  test('对方已是最新（条目数 0）→ 不上传', () async {
    var posted = false;
    final receiver = buildReceiver(
      applier: (_, _) async {
        posted = true;
        return const SyncReport(
          diaryCount: 0,
          categoryCount: 0,
          elapsed: Duration.zero,
        );
      },
    );
    await receiver.start();
    addTearDown(receiver.stop);

    final sender = LanSender(
      crypto: FakeLanCrypto(),
      http: IoTestHttpClient(),
      archiveBuilder: (_, _) async {
        final file = io.File(p.join(tmp.path, 'empty.zip'));
        await file.writeAsBytes(const [1, 2, 3]);
        return (file.path, 0);
      },
    );
    final result = await sender.send(
      host: '127.0.0.1',
      port: receiver.port,
      pin: receiver.pin,
    );
    expect(result.upToDate, isTrue);
    expect(posted, isFalse);
    // 空包已被发送方清理
    expect(io.File(p.join(tmp.path, 'empty.zip')).existsSync(), isFalse);
  });

  test('导入抛错 → 发送方收到 500 与错误信息，接收端进入 failed 状态', () async {
    final receiver = buildReceiver(
      applier: (_, _) async =>
          throw const SyncException('不是有效的 Moodiary 备份文件'),
    );
    await receiver.start();
    addTearDown(receiver.stop);

    final sender = LanSender(
      crypto: FakeLanCrypto(),
      http: IoTestHttpClient(),
      archiveBuilder: (_, _) async {
        final file = io.File(p.join(tmp.path, 'bad.zip'));
        await file.writeAsBytes(const [9, 9, 9]);
        return (file.path, 1);
      },
    );
    await expectLater(
      sender.send(host: '127.0.0.1', port: receiver.port, pin: receiver.pin),
      throwsA(
        isA<SyncException>().having(
          (e) => e.message,
          'message',
          contains('备份文件'),
        ),
      ),
    );
    expect(receiver.state.value, isA<LanReceiveFailed>());
  });
}
