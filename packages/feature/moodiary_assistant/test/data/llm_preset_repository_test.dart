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

      expect(
        anthropic.models.single.protocol,
        AssistantProviderType.anthropicMessages,
      );
      expect(anthropic.models.single.baseUrl, '');
      expect(anthropic.docUrl, 'https://docs.anthropic.com/models');
      expect(anthropic.env, ['ANTHROPIC_API_KEY']);
      expect(anthropic.logoUrl, 'https://models.dev/logos/anthropic.svg');

      expect(
        deepseek.models.first.protocol,
        AssistantProviderType.openaiCompletions,
      );
      expect(deepseek.models.first.baseUrl, 'https://api.deepseek.com');
    });

    test('模型元数据解析', () {
      final list = parseModelsDevCatalog(_catalog({'anthropic': _anthropic}));
      final model = list.single.models.single;
      expect(model.id, 'claude-opus-4-5');
      expect(model.name, 'Claude Opus 4.5');
      expect(model.toolCall, isTrue);
      expect(model.reasoning, isTrue);
      expect(model.contextLimit, 200000);
      expect(model.outputLimit, 64000);
      expect(model.inputCost, 5);
      expect(model.outputCost, 25);
      expect(model.cacheReadCost, 0.5);
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
  group('模型级路由覆盖（models.*.provider）', () {
    // zenmux / opencode / ofox 就是这个形状：一家 openai-compatible 网关，
    // 底下的 Claude 走 anthropic、GPT 走 responses、其余走 chat completions。
    const gateway = {
      'id': 'gateway',
      'npm': '@ai-sdk/openai-compatible',
      'api': 'https://gw.example/api/v1',
      'name': 'Gateway',
      'doc': 'https://gw.example/docs',
      'models': {
        'claude': {
          'id': 'claude',
          'name': 'Claude',
          'tool_call': true,
          'provider': {
            'npm': '@ai-sdk/anthropic',
            'api': 'https://gw.example/api/anthropic/v1',
          },
        },
        'gpt': {
          'id': 'gpt',
          'name': 'GPT',
          'tool_call': true,
          'provider': {'npm': '@ai-sdk/openai', 'shape': 'responses'},
        },
        'plain': {'id': 'plain', 'name': 'Plain', 'tool_call': true},
        'gemini': {
          'id': 'gemini',
          'name': 'Gemini',
          'tool_call': true,
          'provider': {'npm': '@ai-sdk/google'},
        },
      },
    };

    test('协议与 baseUrl 按模型解析，而不是按供应商', () {
      final preset = parseModelsDevCatalog(_catalog({'gateway': gateway}))
          .single;
      LlmModelPreset model(String id) =>
          preset.models.firstWhere((m) => m.id == id);

      expect(model('claude').protocol, AssistantProviderType.anthropicMessages);
      expect(model('claude').baseUrl, 'https://gw.example/api/anthropic/v1');

      expect(model('gpt').protocol, AssistantProviderType.openaiResponses);
      expect(model('gpt').baseUrl, 'https://gw.example/api/v1');

      expect(model('plain').protocol, AssistantProviderType.openaiCompletions);
      expect(model('plain').baseUrl, 'https://gw.example/api/v1');
    });

    test('协议不支持的模型被剔除，不留给用户去撞墙', () {
      final preset = parseModelsDevCatalog(_catalog({'gateway': gateway}))
          .single;
      expect(preset.models.map((e) => e.id), isNot(contains('gemini')));
    });
  });

  group('白名单与 baseUrl 归一', () {
    test('openrouter / merge-gateway 在名单内（schema 允许它们带 api）', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'openrouter': {
            'id': 'openrouter',
            'npm': '@openrouter/ai-sdk-provider',
            'api': 'https://openrouter.ai/api/v1',
            'name': 'OpenRouter',
            'doc': 'https://openrouter.ai/docs',
            'models': {
              'x': {'id': 'x', 'name': 'X', 'tool_call': true},
            },
          },
        }),
      );
      expect(
        list.single.models.single.protocol,
        AssistantProviderType.openaiCompletions,
      );
      expect(list.single.models.single.baseUrl, 'https://openrouter.ai/api/v1');
    });

    test('openai-compatible 缺 api 整条丢弃，绝不能落空回退官方端点', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'noapi': {
            'id': 'noapi',
            'npm': '@ai-sdk/openai-compatible',
            'name': 'No API',
            'doc': 'https://example.com',
            'models': {
              'm': {'id': 'm', 'name': 'M', 'tool_call': true},
            },
          },
        }),
      );
      expect(list, isEmpty);
    });

    // 目录里真有这么一条（cloudflare-ai-gateway 的 Claude）：模型把 npm 覆盖成
    // anthropic 却没给 api。放过去就是把网关的 key 发去 api.anthropic.com。
    test('模型覆盖成 anthropic 但没给 api 时同样丢弃', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'gw': {
            'id': 'gw',
            'npm': 'ai-gateway-provider',
            'name': 'Gateway',
            'doc': 'https://example.com',
            'models': {
              'claude': {
                'id': 'claude',
                'name': 'Claude',
                'tool_call': true,
                'provider': {'npm': '@ai-sdk/anthropic'},
              },
            },
          },
        }),
      );
      expect(list, isEmpty);
    });

    test('baseUrl 带 \${VAR} 占位符的模型剔掉——用户没有地方替换它', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'neon': {
            'id': 'neon',
            'npm': '@ai-sdk/openai-compatible',
            'api': r'${NEON_BASE}/v1',
            'name': 'Neon',
            'doc': 'https://example.com',
            'models': {
              'm': {'id': 'm', 'name': 'M', 'tool_call': true},
            },
          },
        }),
      );
      expect(list, isEmpty);
    });

    // 反过来，覆盖块把 npm 和 api 都给全了就该放行——azure / vertex 就是这样。
    test('供应商 npm 不在名单，但模型覆盖给全了 npm + api 则放行', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'azure': {
            'id': 'azure',
            'npm': '@ai-sdk/azure',
            'name': 'Azure',
            'doc': 'https://example.com',
            'models': {
              'kimi': {
                'id': 'kimi',
                'name': 'Kimi',
                'tool_call': true,
                'provider': {
                  'npm': '@ai-sdk/openai-compatible',
                  'api': 'https://x.services.ai.azure.com/models',
                  'shape': 'completions',
                },
              },
            },
          },
        }),
      );
      final model = list.single.models.single;
      expect(model.protocol, AssistantProviderType.openaiCompletions);
      expect(model.baseUrl, 'https://x.services.ai.azure.com/models');
    });

    test('api 误写成完整端点时削掉尾巴（bailing 那种）', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'bailing': {
            'id': 'bailing',
            'npm': '@ai-sdk/openai-compatible',
            'api': 'https://api.tbox.cn/api/llm/v1/chat/completions',
            'name': 'Bailing',
            'doc': 'https://example.com',
            'models': {
              'm': {'id': 'm', 'name': 'M', 'tool_call': true},
            },
          },
        }),
      );
      expect(
        list.single.models.single.baseUrl,
        'https://api.tbox.cn/api/llm/v1',
      );
    });
  });

  group('目录字段取全', () {
    test('reasoning_options / modalities / interleaved / status 都解析出来', () {
      final list = parseModelsDevCatalog(
        _catalog({
          'p': {
            'id': 'p',
            'npm': '@ai-sdk/openai-compatible',
            'api': 'https://p.example/v1',
            'name': 'P',
            'doc': 'https://p.example',
            'models': {
              'm': {
                'id': 'm',
                'name': 'M',
                'tool_call': true,
                'reasoning': true,
                'reasoning_options': [
                  {
                    'type': 'effort',
                    'values': ['low', 'medium', 'high'],
                  },
                  {'type': 'budget_tokens', 'min': 1024},
                ],
                'modalities': {
                  'input': ['text', 'image', 'pdf'],
                  'output': ['text'],
                },
                'interleaved': {'field': 'reasoning_content'},
                'status': 'deprecated',
                'temperature': false,
                'structured_output': true,
                'limit': {'context': 200000, 'input': 180000, 'output': 32000},
                'cost': {
                  'input': 1,
                  'output': 2,
                  'cache_read': 0.1,
                  'cache_write': 1.25,
                },
              },
            },
          },
        }),
      );
      final m = list.single.models.single;
      expect(m.reasoningOptions, hasLength(2));
      expect(m.reasoningOptions!.first.type, ReasoningControlType.effort);
      expect(m.reasoningOptions!.first.values, ['low', 'medium', 'high']);
      expect(m.reasoningOptions!.last.type, ReasoningControlType.budgetTokens);
      expect(m.reasoningOptions!.last.min, 1024);
      expect(m.inputModalities, ['text', 'image', 'pdf']);
      expect(m.acceptsImage, isTrue);
      expect(m.interleavedField, 'reasoning_content');
      expect(m.deprecated, isTrue);
      expect(m.temperature, isFalse);
      expect(m.structuredOutput, isTrue);
      expect(m.inputLimit, 180000);
      expect(m.cacheWriteCost, 1.25);
    });
  });
}
