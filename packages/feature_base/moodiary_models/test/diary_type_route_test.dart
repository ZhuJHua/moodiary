import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('DiaryType route-query codec', () {
    test('routeQuery encodes richText as rich-text (not the enum value)', () {
      expect(DiaryType.markdown.routeQuery, 'markdown');
      expect(DiaryType.richText.routeQuery, 'rich-text');
      expect(DiaryType.tiptap.routeQuery, 'tiptap');
      // 守住路由编码与 DiaryType.value 的分歧：value 是 'richText'，路由串是 'rich-text'。
      expect(DiaryType.richText.value, 'richText');
    });

    test('diaryTypeFromRouteQuery round-trips every value', () {
      for (final type in DiaryType.values) {
        expect(diaryTypeFromRouteQuery(type.routeQuery), type);
      }
    });

    test('diaryTypeFromRouteQuery returns null for null/unknown', () {
      expect(diaryTypeFromRouteQuery(null), isNull);
      expect(diaryTypeFromRouteQuery('richText'), isNull); // 枚举原值不是路由串
      expect(diaryTypeFromRouteQuery('nope'), isNull);
    });
  });
}
