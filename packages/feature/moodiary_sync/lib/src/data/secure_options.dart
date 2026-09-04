import 'dart:convert';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// 含密钥的连接配置（S3 的 secretKey、WebDAV 的密码）的 SecureKV 编解码。
/// 不做进程内镜像：用到时读，缓存与否由持有它的后端自己定。
class SecureOptions {
  SecureOptions(this._key);

  final MoodiarySecureKVs _key;

  /// 读失败（钥匙串不可用 / 设备未首次解锁）与形状不对都按「未配置」返回空表，
  /// 调用方 fail-open：同步暂不可用好过炸掉。
  Future<List<String>> read() async {
    final String? raw;
    try {
      raw = await _key.get();
    } catch (e, s) {
      logger.e(
        'sync options read failed: ${_key.name}',
        error: e,
        stackTrace: s,
      );
      return const <String>[];
    }
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> save(List<String> options) => _key.set(jsonEncode(options));

  Future<void> clear() => _key.remove();
}
