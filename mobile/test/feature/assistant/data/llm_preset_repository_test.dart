import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/assistant/data/llm_preset_repository.dart';

/// 按调用顺序返回/抛出预编排行为的 fake，用于验证 GitHub→Gitee 回退。
class _QueueHttpClient implements IHttpClient {
  _QueueHttpClient(this._behaviors);

  final List<Object? Function()> _behaviors;
  int _index = 0;
  final List<String> calledUrls = [];

  @override
  Future<HttpResponse<T>> get<T>(
    String url, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? headers,
    Duration? timeout,
    bool silent = false,
  }) async {
    calledUrls.add(url);
    final data = _behaviors[_index++](); // 可能抛出
    return HttpResponse<T>(statusCode: 200, data: data as T?);
  }
}

Map<String, dynamic> _index(List<Map<String, dynamic>> providers) => {
  'schemaVersion': 1,
  'providers': providers,
};

const _deepseek = {
  'id': 'deepseek',
  'protocol': 'openai',
  'name': {'default': 'DeepSeek', 'zh': '深度求索'},
  'baseUrl': 'https://api.deepseek.com',
  'models': ['deepseek-chat', 'deepseek-reasoner'],
};

void main() {
  group('LlmPresetRepository.fetchRemote', () {
    test('GitHub 成功：只请求一次，解析正确', () async {
      final http = _QueueHttpClient([() => _index([_deepseek])]);
      final list = await LlmPresetRepository(http).fetchRemote();

      expect(http.calledUrls, hasLength(1));
      expect(http.calledUrls.first, contains('raw.githubusercontent.com'));
      expect(list, hasLength(1));
      expect(list.first.id, 'deepseek');
      expect(list.first.protocol, AssistantProviderType.openai);
      expect(list.first.localizedName('zh'), '深度求索');
      expect(list.first.localizedName('en'), 'DeepSeek'); // 回退 default
    });

    test('GitHub 失败 → 回退 Gitee', () async {
      final http = _QueueHttpClient([
        () => throw Exception('github timeout'),
        () => _index([_deepseek]),
      ]);
      final list = await LlmPresetRepository(http).fetchRemote();

      expect(http.calledUrls, hasLength(2));
      expect(http.calledUrls[0], contains('raw.githubusercontent.com'));
      expect(http.calledUrls[1], contains('gitee.com'));
      expect(list.single.id, 'deepseek');
    });

    test('两源都失败 → 抛出', () async {
      final http = _QueueHttpClient([
        () => throw Exception('github down'),
        () => throw Exception('gitee down'),
      ]);
      expect(
        LlmPresetRepository(http).fetchRemote(),
        throwsA(isA<Exception>()),
      );
    });

    test('解析容错：跳过缺 models 的非法项', () async {
      final http = _QueueHttpClient([
        () => _index([
          _deepseek,
          {'id': 'broken', 'protocol': 'openai', 'name': {'default': 'X'}},
        ]),
      ]);
      final list = await LlmPresetRepository(http).fetchRemote();
      expect(list, hasLength(1));
      expect(list.single.id, 'deepseek');
    });
  });
}
