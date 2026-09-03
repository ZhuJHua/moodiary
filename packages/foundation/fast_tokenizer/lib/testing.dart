/// 宿主测试跑不了 FFI。用 `FastTokenizerLib.initMock` 在桥的边界处换掉整个 api，桥以上的
/// 生产代码路径原样执行。
library;

import 'package:fast_tokenizer/src/rust/api/text.dart';
import 'package:fast_tokenizer/src/rust/frb_generated.dart';

/// 只桩掉分词；其余调用一律抛错，避免测试悄悄依赖到没桩的能力。
class FakeFastTokenizerApi implements FastTokenizerLibApi {
  FakeFastTokenizerApi(this._tokenize);

  final Future<TokenizeResult> Function(String text) _tokenize;

  @override
  Future<TokenizeResult> crateApiTextTokenizerTokenize({
    required String text,
  }) => _tokenize(text);

  @override
  Future<List<TokenizeResult>> crateApiTextTokenizerTokenizeBatch({
    required List<String> texts,
  }) async => [for (final text in texts) await _tokenize(text)];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeFastTokenizerApi 未桩接 ${invocation.memberName}',
  );
}

bool _installed = false;

/// 幂等：`initMock` 不允许重复初始化。
void installFakeFastTokenizer(
  Future<TokenizeResult> Function(String text) tokenize,
) {
  if (_installed) return;
  FastTokenizerLib.initMock(api: FakeFastTokenizerApi(tokenize));
  _installed = true;
}
