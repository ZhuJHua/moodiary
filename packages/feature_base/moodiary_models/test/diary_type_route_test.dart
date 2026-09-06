import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';

void main() {
  group('DiaryType route-query codec', () {
    test('routeQuery encodes richText as rich-text (not the enum value)', () {
      expect(DiaryType.markdown.routeQuery, 'markdown');
      expect(DiaryType.richText.routeQuery, 'rich-text');
      expect(DiaryType.tiptap.routeQuery, 'tiptap');
      expect(DiaryType.richText.value, 'richText');
    });

    test('diaryTypeFromRouteQuery round-trips every value', () {
      for (final type in DiaryType.values) {
        expect(diaryTypeFromRouteQuery(type.routeQuery), type);
      }
    });

    test('diaryTypeFromRouteQuery returns null for null/unknown', () {
      expect(diaryTypeFromRouteQuery(null), isNull);
      expect(diaryTypeFromRouteQuery('richText'), isNull);
      expect(diaryTypeFromRouteQuery('nope'), isNull);
    });
  });
}
