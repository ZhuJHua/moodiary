import 'package:injectable/injectable.dart';
import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_models/moodiary_models.dart';

@lazySingleton
class ModelCatalogRepository {
  ModelCatalogRepository(this._http);

  final IHttpClient _http;

  static const Duration _timeout = Duration(seconds: 15);

  static const String _openAiDefaultBase = 'https://api.openai.com/v1';
  static const String _anthropicDefaultBase = 'https://api.anthropic.com';

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
    // 需先削掉末尾的 /v1，否则与路径自带的 /v1 拼出两个 v1
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
