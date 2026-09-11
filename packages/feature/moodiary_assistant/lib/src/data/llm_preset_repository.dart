import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

@lazySingleton
class LlmPresetRepository {
  LlmPresetRepository(this._http);

  final IHttpClient _http;

  static const String _apiUrl = 'https://models.dev/api.json';

  static const Duration _timeout = Duration(seconds: 15);

  int get cachedAt => MoodiaryKVs.llmPresetCacheAt.get() ?? 0;

  Future<List<LlmProviderPreset>> load() async {
    final cached = cachedPresets();
    if (cached.isNotEmpty) return cached;
    return refresh();
  }

  List<LlmProviderPreset> cachedPresets() {
    final cached = MoodiaryKVs.llmPresetCache.get() ?? '';
    if (cached.isEmpty) return const [];
    try {
      return _decodeCache(cached);
    } catch (_) {
      return const [];
    }
  }

  Future<List<LlmProviderPreset>>? _inFlight;

  /// 永远如实抛错；要回退旧缓存的调用方自己 catch
  Future<List<LlmProviderPreset>> refresh() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _refresh().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<List<LlmProviderPreset>> _refresh() async {
    final body = await _fetchBody();
    final normalized = await compute(_normalize, body);
    MoodiaryKVs.llmPresetCache.set(normalized);
    MoodiaryKVs.llmPresetCacheAt.set(DateTime.now().millisecondsSinceEpoch);
    return _decodeCache(normalized);
  }

  Future<String> _fetchBody() async {
    final res = await _http.get<String>(
      _apiUrl,
      timeout: _timeout,
      silent: true,
      plainText: true,
    );
    final data = res.data;
    if (data == null || data.isEmpty) {
      throw StateError('empty response from $_apiUrl');
    }
    return data;
  }

  List<LlmProviderPreset> _decodeCache(String s) {
    final list = jsonDecode(s);
    if (list is! List) throw const FormatException('invalid preset cache');
    return [
      for (final item in list)
        if (item is Map)
          LlmProviderPreset.fromJson(item.cast<String, dynamic>()),
    ];
  }
}

String _normalize(String body) {
  return jsonEncode(
    parseModelsDevCatalog(body).map((e) => e.toJson()).toList(),
  );
}

List<LlmProviderPreset> parseModelsDevCatalog(String body) {
  final root = jsonDecode(body);
  if (root is! Map) {
    throw const FormatException('invalid models.dev api.json root');
  }
  final result = <LlmProviderPreset>[];
  root.forEach((id, value) {
    if (id is String && value is Map) {
      final preset = LlmProviderPreset.fromModelsDev(
        id,
        value.cast<String, dynamic>(),
      );
      if (preset != null) result.add(preset);
    }
  });
  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}
