import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_models/moodiary_models.dart';

String _catalog(Map<String, dynamic> providers) => jsonEncode(providers);

const _anthropic = {
  'id': 'anthropic',
  'npm': '@ai-sdk/anthropic',
  'name': 'Anthropic',
  'doc': 'https://docs.anthropic.com/models',
  'env': ['ANTHROPIC_API_KEY'],
  'models': {
    'claude-opus-4-5': {
      'id': 'claude-opus-4-5',
      'name': 'Claude Opus 4.5',
      'tool_call': true,
      'reasoning': true,
      'attachment': true,
      'release_date': '2025-11-24',
      'limit': {'context': 200000, 'output': 64000},
      'cost': {'input': 5, 'output': 25, 'cache_read': 0.5},
    },
  },
};

const _deepseek = {
  'id': 'deepseek',
  'npm': '@ai-sdk/openai-compatible',
  'api': 'https://api.deepseek.com',
  'name': 'DeepSeek',
  'doc': 'https://api-docs.deepseek.com/pricing',
  'env': ['DEEPSEEK_API_KEY'],
  'models': {
    'deepseek-base': {
      'id': 'deepseek-base',
      'name': 'DeepSeek Base',
      'tool_call': false,
    },
    'deepseek-chat': {
      'id': 'deepseek-chat',
      'name': 'DeepSeek Chat',
      'tool_call': true,
      'limit': {'context': 128000},
      'cost': {'input': 0.14, 'output': 0.28},
    },
  },
};

const _google = {
  'id': 'google',
  'npm': '@ai-sdk/google',
  'name': 'Google',
  'models': {
    'gemini-2.5-pro': {'id': 'gemini-2.5-pro', 'tool_call': true},
  },
};

const _aggregator = {
  'id': 'requesty',
  'npm': '@ai-sdk/openai-compatible',
  'api': 'https://router.requesty.ai/v1',
  'name': 'Requesty',
  'models': {
    'grok-4': {'id': 'grok-4', 'name': 'Grok 4', 'tool_call': true},
  },
};

const _brokenNoModels = {
  'id': 'broken',
  'npm': '@ai-sdk/openai-compatible',
  'name': 'Broken',
  'models': <String, dynamic>{},
};

void main() {
  group('parseModelsDevCatalog', () {
    test('过滤：仅剔除不支持协议/无模型，其余全保留并按名称排序', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'deepseek': _deepseek,
          'anthropic': _anthropic,
          'google': _google,
          'requesty': _aggregator,
          'broken': _brokenNoModels,
        }),
      );
      expect(list.map((e) => e.id), ['anthropic', 'deepseek', 'requesty']);
    });

    test('协议映射与 baseUrl 官方端点回退', () {
      final list = parseModelsDevCatalog(
        _catalog({'anthropic': _anthropic, 'deepseek': _deepseek}),
      );
      final anthropic = list.firstWhere((e) => e.id == 'anthropic');
      final deepseek = list.firstWhere((e) => e.id == 'deepseek');

      expect(anthropic.protocol, AssistantProviderType.anthropic);
      expect(anthropic.baseUrl, '');
      expect(anthropic.docUrl, 'https://docs.anthropic.com/models');
      expect(anthropic.env, ['ANTHROPIC_API_KEY']);
      expect(anthropic.logoUrl, 'https://models.dev/logos/anthropic.svg');

      expect(deepseek.protocol, AssistantProviderType.openai);
      expect(deepseek.baseUrl, 'https://api.deepseek.com');
    });

    test('模型元数据解析', () {
      final list = parseModelsDevCatalog(_catalog({'anthropic': _anthropic}));
      final model = list.single.models.single;
      expect(model.id, 'claude-opus-4-5');
      expect(model.name, 'Claude Opus 4.5');
      expect(model.toolCall, isTrue);
      expect(model.reasoning, isTrue);
      expect(model.attachment, isTrue);
      expect(model.contextLimit, 200000);
      expect(model.outputLimit, 64000);
      expect(model.inputCost, 5);
      expect(model.outputCost, 25);
      expect(model.releaseDate, '2025-11-24');
    });

    test('模型按 tool_call 优先排序', () {
      final list = parseModelsDevCatalog(_catalog({'deepseek': _deepseek}));
      final models = list.single.models;
      expect(models.map((e) => e.id), ['deepseek-chat', 'deepseek-base']);
    });
  });

  group('缓存序列化往返', () {
    test('LlmProviderPreset toJson -> fromJson 相等', () {
      final original = parseModelsDevCatalog(
        _catalog({'anthropic': _anthropic, 'deepseek': _deepseek}),
      );
      final encoded = jsonEncode(original.map((e) => e.toJson()).toList());
      final decoded = (jsonDecode(encoded) as List)
          .map((e) => LlmProviderPreset.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(decoded, original);
    });
  });
}
