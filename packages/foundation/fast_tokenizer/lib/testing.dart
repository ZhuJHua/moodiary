library;

import 'package:fast_tokenizer/src/rust/api/text.dart';
import 'package:fast_tokenizer/src/rust/frb_generated.dart';

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

void installFakeFastTokenizer(
  Future<TokenizeResult> Function(String text) tokenize,
) {
  if (_installed) return;
  FastTokenizerLib.initMock(api: FakeFastTokenizerApi(tokenize));
  _installed = true;
}
