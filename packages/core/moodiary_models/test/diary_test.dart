import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  // Diary.empty() calls uuidV7()（Rust FFI）；未初始化 RustLib 的纯 Dart 单测
  // 会在到达 mood 断言前先在 id 生成处抛出（同 category_test.dart 记录的限制）。
  // 保留此测试并显式 skip，而非绕过 uuidV7 直接构造 Diary（那样只是把字面量
  // 0.5 抄一遍到测试里，验证不了 Diary.empty 本身，是空测试）。
  test(
    'Diary.empty defaults mood to neutral 0.5',
    () {
      final d = Diary.empty(type: DiaryType.tiptap);
      expect(d.mood, 0.5);
    },
    skip:
        'Diary.empty() calls uuidV7() (Rust FFI) which requires RustLib.init(); '
        'not available in host-only unit tests for this package.',
  );
}
