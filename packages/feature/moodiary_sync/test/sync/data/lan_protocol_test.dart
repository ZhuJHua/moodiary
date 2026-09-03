import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/lan/lan_protocol.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';

void main() {
  test('线上格式指纹：改了任何一项都要连 lanProtoVersion 一起 bump', () {
    final fingerprint = [
      'proto=$lanProtoVersion',
      'handshake=$lanHandshakePath',
      'manifest=$lanManifestPath',
      'archive=$lanArchivePath',
      'auth=$lanAuthHeader',
      'protoHeader=$lanProtoHeader',
      'nonce=$lanNonceBytes',
      'manifestVersion=${SyncManifest.currentVersion}',
      'cipher=${SyncCipher.magic.trim()}',
    ].join(';');
    expect(
      fingerprint,
      'proto=2;'
      'handshake=/moodiary/lan/v1/handshake;'
      'manifest=/moodiary/lan/v1/manifest;'
      'archive=/moodiary/lan/v1/archive;'
      'auth=x-moodiary-auth;'
      'protoHeader=x-moodiary-proto;'
      'nonce=16;'
      'manifestVersion=1;'
      'cipher=MD-ENC-V1',
      reason:
          '线上格式变了：先 bump lanProtoVersion（两端严格相等才能同步），再改这里的期望值。'
          '没常量可钉的改动（归档条目封装、令牌明文布局）同样要 bump，见 lan_protocol.dart 头注。',
    );
  });

  test('版本串：线上形式 2.8.1+101，展示形式 2.8.1 (101)', () {
    expect(lanDisplayVersion('2.8.1+101'), '2.8.1 (101)');
    expect(lanDisplayVersion('2.8.1'), '2.8.1');
    expect(lanDisplayVersion(null), 'unknown');
    expect(lanDisplayVersion(''), 'unknown');
    expect(lanTxtRecord('2.8.1+101'), {'proto': '2', 'ver': '2.8.1+101'});
  });
}
