import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// slang 两份配置都是 `base_locale: zh` + `fallback_strategy: base_locale`，
/// 所以**en 缺一个键不会报错、不会失败，直接把中文渲染给英文用户**。
/// 这条闸门就是替代那份编译期检查的（`4534e368` 修的正是同一类问题）。
void main() {
  final dir = Directory('lib/i18n');

  // 复数节点**到此为止，不再下钻**：分类（one / other / …）本来就按语种不同 ——
  // 中文侧只有 other，因为 slang 内置的复数规则表里没有 zh。可翻译的单位是这个
  // 节点本身，不是它底下的分类。
  bool isPlural(String key) =>
      key.contains('(plural') ||
      key.contains('(cardinal') ||
      key.contains('(ordinal');

  Set<String> flatten(Object? node, [String prefix = '']) {
    if (node is! Map) return {prefix};
    final out = <String>{};
    for (final entry in node.entries) {
      final name = '${entry.key}';
      final key = prefix.isEmpty ? name : '$prefix.$name';
      out.addAll(isPlural(name) ? {key} : flatten(entry.value, key));
    }
    return out;
  }

  test('每个 namespace 的 zh / en 键集完全一致', () {
    expect(dir.existsSync(), isTrue, reason: '${dir.absolute.path} 不存在');

    final namespaces =
        dir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_zh.i18n.json'))
            .map(
              (name) => name.substring(0, name.length - '_zh.i18n.json'.length),
            )
            .toList()
          ..sort();

    expect(namespaces, isNotEmpty, reason: '一个 namespace 都没扫到，路径大概是错的');

    for (final namespace in namespaces) {
      final zh = File('${dir.path}/${namespace}_zh.i18n.json');
      final en = File('${dir.path}/${namespace}_en.i18n.json');
      expect(en.existsSync(), isTrue, reason: '$namespace 缺英文文件');

      final zhKeys = flatten(jsonDecode(zh.readAsStringSync()));
      final enKeys = flatten(jsonDecode(en.readAsStringSync()));

      expect(
        zhKeys.difference(enKeys),
        isEmpty,
        reason: '$namespace: 这些键只有中文，英文用户会看到中文',
      );
      expect(
        enKeys.difference(zhKeys),
        isEmpty,
        reason: '$namespace: 这些键只有英文（多半是删中文时漏了）',
      );
    }
  });
}
