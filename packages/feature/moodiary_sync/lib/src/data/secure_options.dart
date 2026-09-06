import 'dart:convert';

import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

class SecureOptions {
  SecureOptions(this._key);

  final MoodiarySecureKVs _key;

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
