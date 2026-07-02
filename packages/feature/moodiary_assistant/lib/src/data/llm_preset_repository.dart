import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

class LlmPresetRepository {
  LlmPresetRepository(this._http);

  factory LlmPresetRepository.get() => _instance;

  static final LlmPresetRepository _instance = LlmPresetRepository(
    IHttpClient.get(),
  );

  final IHttpClient _http;

  static const String _apiUrl = 'https://models.dev/api.json';

  static const Duration _timeout = Duration(seconds: 15);

  int get cachedAt => MoodiaryKVs.llmPresetCacheAt.get() ?? 0;

  Future<List<LlmProviderPreset>> load() async {
    final cached = MoodiaryKVs.llmPresetCache.get() ?? '';
    if (cached.isNotEmpty) {
      try {
        return _decodeCache(cached);
      } catch (_) {}
    }
    return refresh();
  }

  Future<List<LlmProviderPreset>> refresh() async {
    try {
      final body = await _fetchBody();
      final normalized = await compute(_normalize, body);
      await MoodiaryKVs.llmPresetCache.set(normalized);
      await MoodiaryKVs.llmPresetCacheAt.set(
        DateTime.now().millisecondsSinceEpoch,
      );
      return _decodeCache(normalized);
    } catch (e) {
      final cached = MoodiaryKVs.llmPresetCache.get() ?? '';
      if (cached.isNotEmpty) {
        try {
          return _decodeCache(cached);
        } catch (_) {}
      }
      rethrow;
    }
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
