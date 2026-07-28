import 'dart:convert';

/// Quill Delta（旧 richText 的落库形态）的纯 Dart 读取助手。
///
/// 全仓已清退 flutter_quill——旧日记只读渲染改走 [QuillDeltaToTiptap] + TipTap webview，
/// 剩下的「取纯文本 / 判合法 / 包装纯文本」三件事由本类承担，无需再拖一个编辑器依赖。
class QuillDelta {
  const QuillDelta._();

  /// Delta 的 op 列表；不是合法 Delta（JSON 解析失败或顶层非数组）返回 null。
  static List<dynamic>? ops(String deltaJson) {
    try {
      final decoded = jsonDecode(deltaJson);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static bool isDelta(String deltaJson) => ops(deltaJson) != null;

  /// 纯文本镜像：拼接所有字符串 `insert`，embed（Map insert）不产出文本。
  /// 与 flutter_quill `Document.toPlainText()` 的差别仅在于不补文档末尾换行，
  /// 调用方本就 `trimRight()`。非法 Delta 返回 null，由调用方回退原文。
  static String? plainText(String deltaJson) => plainTextOf(ops(deltaJson));

  /// 同 [plainText]，但吃已解析好的 op 列表——同一篇要同时取纯文本与媒体时，
  /// 由调用方解析一次后复用，避免重复 `jsonDecode`。
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

  /// 把一段裸纯文本包成最小合法 Delta（旧 `type == 'text'` 里存的不是 Delta 时的兜底）。
  static String wrapPlainText(String text) {
    return jsonEncode([
      {'insert': text.endsWith('\n') ? text : '$text\n'},
    ]);
  }
}
