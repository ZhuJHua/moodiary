import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 从端点现拉模型列表。给自定义供应商用 —— 它们不在 models.dev 里，此前只能手打模型 id。
///
/// 三种协议的列表端点形状一致（`{"data":[{"id":…}]}`），差别只在路径与鉴权头。
class ModelCatalogRepository {
  ModelCatalogRepository(this._http);

  factory ModelCatalogRepository.get() => _instance;

  static final ModelCatalogRepository _instance = ModelCatalogRepository(
    .get(),
  );

  final IHttpClient _http;

  static const Duration _timeout = Duration(seconds: 15);

  static const String _openAiDefaultBase = 'https://api.openai.com/v1';
  static const String _anthropicDefaultBase = 'https://api.anthropic.com';

  /// 拉取并按 id 排序。列表拿不到时抛 [HttpException]（调用方负责提示并回落手填）。
  Future<List<String>> fetch({
    required AssistantProviderType protocol,
    required String baseUrl,
    required String apiKey,
  }) async {
    final res = await _http.get<dynamic>(
      _endpointFor(protocol, baseUrl),
      headers: _headersFor(protocol, apiKey),
      timeout: _timeout,
      silent: true,
    );
    final ids = _extractIds(res.data);
    if (ids.isEmpty) {
      throw const HttpException(
        HttpErrorType.decode,
        'model listing returned no usable ids',
      );
    }
    ids.sort();
    return ids;
  }

  String _endpointFor(AssistantProviderType protocol, String baseUrl) {
    final base = baseUrl.trim().isEmpty
        ? (protocol.isAnthropic ? _anthropicDefaultBase : _openAiDefaultBase)
        : baseUrl.trim();
    final trimmed = _stripTrailingSlash(base);
    if (!protocol.isAnthropic) return '$trimmed/models';
    // 与 rig 的 normalize_anthropic_base_url 保持一致：目录里的 anthropic 端点写成
    // `.../anthropic/v1`，而路径本身又带 `/v1`，不削掉就会拼出两个 v1。
    final root = trimmed.endsWith('/v1')
        ? trimmed.substring(0, trimmed.length - 3)
        : trimmed;
    return '${_stripTrailingSlash(root)}/v1/models';
  }

  Map<String, String> _headersFor(
    AssistantProviderType protocol,
    String apiKey,
  ) {
    if (protocol.isAnthropic) {
      return {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'};
    }
    return {'Authorization': 'Bearer $apiKey'};
  }

  /// 三种协议的列表端点回包形状一致：`{"data": [{"id": …}]}`。
  List<String> _extractIds(Object? body) {
    final list = switch (body) {
      final Map raw when raw['data'] is List => raw['data'] as List,
      _ => const [],
    };
    return [
      for (final item in list)
        if (item is Map && item['id'] is String)
          if ((item['id'] as String).trim() case final id when id.isNotEmpty)
            id,
    ];
  }

  static String _stripTrailingSlash(String url) {
    var s = url;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
