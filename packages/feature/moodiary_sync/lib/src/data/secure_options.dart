part of 'sync_data_providers.dart';

class SecureOptions {
  SecureOptions(this._key, this._storage);

  final ISecureKVStorage _storage;

  final MoodiarySecureKVs _key;

  Future<List<String>> read() async {
    final String? raw;
    try {
      raw = await _storage.get(_key.name);
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
      return List<String>.unmodifiable(jsonDecode(raw) as List);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _save(List<String> options) =>
      _storage.set(_key.name, jsonEncode(options));

  Future<void> _clear() => _storage.remove(_key.name);
}
