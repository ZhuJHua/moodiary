import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

// Category.create() 的 id 来自 uuidV7()（Rust FFI），未初始化 RustLib 的纯 Dart
// 单测无法调用；直接构造 Category 验证 color 字段，做法同
// packages/feature/moodiary_sync/test/sync/sync_test_harness.dart 的 buildCategory()。
Category _buildCategory({required String categoryName, int? color}) {
  return Category(
    id: 'test-id',
    categoryName: categoryName,
    lastModified: DateTime.timestamp(),
    color: color,
  );
}

void main() {
  test('Category holds an optional color', () {
    final c = _buildCategory(categoryName: 'work', color: 0xFF42A5F5);
    expect(c.color, 0xFF42A5F5);
  });

  test('Category color defaults to null when unset', () {
    final c = _buildCategory(categoryName: 'life');
    expect(c.color, isNull);
  });
}
