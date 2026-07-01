import 'dart:convert';

import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 远端预设供应商仓储：聚合 `index.json` 优先 GitHub raw、回退 Gitee，缓存到 KV（缓存优先 + 手动刷新）。
class LlmPresetRepository {
  LlmPresetRepository(this._http);

  factory LlmPresetRepository.get() => _instance;

  static final LlmPresetRepository _instance = LlmPresetRepository(
    IHttpClient.get(),
  );

  final IHttpClient _http;

  static const String _githubUrl =
      'https://raw.githubusercontent.com/ZhuJHua/moodiary-llm-provider/main/index.json';

  static const String _giteeUrl =
      'https://gitee.com/ZhuJHua/moodiary-llm-provider/raw/main/index.json';

  static const Duration _timeout = Duration(seconds: 6);

  int get cachedAt => MoodiaryKVs.llmPresetCacheAt.get() ?? 0;

  Future<List<LlmProviderPreset>> fetchRemote() async {
    return _parse(await _fetchObject());
  }

  Future<List<LlmProviderPreset>> load() async {
    final cached = MoodiaryKVs.llmPresetCache.get() ?? '';
    if (cached.isNotEmpty) {
      try {
        return _parse(jsonDecode(cached));
      } catch (_) {
        // 缓存损坏，落到拉取。
      }
    }
    return refresh();
  }

  /// 强制拉取并写缓存；失败时回退既有缓存，无缓存则抛出。
  Future<List<LlmProviderPreset>> refresh() async {
    try {
      final obj = await _fetchObject();
      final list = _parse(obj);
      await MoodiaryKVs.llmPresetCache.set(jsonEncode(obj));
      await MoodiaryKVs.llmPresetCacheAt.set(
        DateTime.now().millisecondsSinceEpoch,
      );
      return list;
    } catch (e) {
      final cached = MoodiaryKVs.llmPresetCache.get() ?? '';
      if (cached.isNotEmpty) {
        try {
          return _parse(jsonDecode(cached));
        } catch (_) {
          // 忽略，抛原始错误。
        }
      }
      rethrow;
    }
  }

  Future<Object?> _fetchObject() async {
    Object? lastError;
    for (final url in const [_githubUrl, _giteeUrl]) {
      try {
        final res = await _http.get(url, timeout: _timeout, silent: true);
        final data = res.data;
        final obj = data is String ? jsonDecode(data) : data;
        if (obj == null) {
          lastError = StateError('empty response from $url');
          continue;
        }
        return obj;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('failed to fetch presets');
  }

  List<LlmProviderPreset> _parse(Object? obj) {
    if (obj is! Map) throw const FormatException('invalid index.json root');
    final providers = obj['providers'];
    if (providers is! List) return const [];
    final result = <LlmProviderPreset>[];
    for (final item in providers) {
      if (item is Map) {
        final preset = LlmProviderPreset.fromJson(
          item.cast<String, dynamic>(),
        );
        if (preset != null) result.add(preset);
      }
    }
    return result;
  }
}
