import 'dart:convert';

class QuillDelta {
  const QuillDelta._();

  static List<dynamic>? ops(String deltaJson) {
    try {
      final decoded = jsonDecode(deltaJson);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static bool isDelta(String deltaJson) {
    final parsed = ops(deltaJson);
    if (parsed == null) return false;
    return parsed.isEmpty ||
        parsed.any((op) => op is Map && op.containsKey('insert'));
  }

  static String? plainText(String deltaJson) => plainTextOf(ops(deltaJson));

  static String? plainTextOf(List<dynamic>? ops) {
    if (ops == null) return null;
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is String) buffer.write(insert);
    }
    return buffer.toString();
  }

  static String wrapPlainText(String text) {
    return jsonEncode([
      {'insert': text.endsWith('\n') ? text : '$text\n'},
    ]);
  }
}
