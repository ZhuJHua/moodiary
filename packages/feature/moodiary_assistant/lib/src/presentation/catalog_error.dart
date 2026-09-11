import 'package:moodiary_http/moodiary_http.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

String assistantNetworkErrorText(Object error, Translations l10n) {
  // 端点答了 200 但结构不对（选错协议最常见）走这两条，不是 HttpException
  if (error is FormatException || error is StateError) {
    return l10n.assistant.netDecode;
  }
  if (error is! HttpException) return l10n.assistant.netUnknown;
  return switch (error.type) {
    .timeout => l10n.assistant.netTimeout,
    .connection => l10n.assistant.netUnreachable,
    .statusCode => l10n.assistant.netStatus(code: error.statusCode ?? 0),
    .decode => l10n.assistant.netDecode,
    .request || .redirect || .unknown => l10n.assistant.netUnknown,
  };
}
