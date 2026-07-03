import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary/app/router/router.dart';

void main() {
  group('route tree config', () {
    testWidgets('mobile tree builds a valid GoRouter', (tester) async {
      expect(
        () => GoRouter(routes: buildMobileRoutes(), initialLocation: '/'),
        returnsNormally,
      );
    });
  });

  group('location encoding contract', () {
    test('DiaryRoute', () {
      expect(
        DiaryRoute(
          type: DiaryType.markdown.routeQuery,
          diaryId: 'abc',
        ).location,
        '/diary/abc?type=markdown',
      );
      expect(
        DiaryRoute(
          type: DiaryType.richText.routeQuery,
          diaryId: 'x',
          edit: true,
        ).location,
        '/diary/x?type=rich-text&edit=true',
      );
    });

    test('NewDiaryRoute', () {
      expect(
        NewDiaryRoute(type: DiaryType.tiptap.routeQuery).location,
        '/diary-new?type=tiptap',
      );
      expect(
        NewDiaryRoute(type: DiaryType.markdown.routeQuery).location,
        '/diary-new?type=markdown',
      );
    });

    test('ShareRoute', () {
      expect(const ShareRoute().location, '/share');
      expect(const ShareRoute(diaryId: 'd2').location, '/share?diary-id=d2');
    });

    test('LockRoute', () {
      expect(const LockRoute().location, '/lock');
      expect(
        const LockRoute(lockType: 'pause').location,
        '/lock?lock-type=pause',
      );
    });

    test('WebViewRoute round-trips url and omits empty title', () {
      expect(const WebViewRoute(url: 'u').location, '/web_view?url=u');
      final uri = Uri.parse(
        const WebViewRoute(url: 'https://a.com/x?q=1', title: 'T').location,
      );
      expect(uri.path, '/web_view');
      expect(uri.queryParameters['url'], 'https://a.com/x?q=1');
      expect(uri.queryParameters['title'], 'T');
    });

    test('no-param routes expose their path as location', () {
      expect(const DiaryHomeRoute().location, '/');
      expect(const RecycleRoute().location, '/recycle');
      expect(const DiarySearchRoute().location, '/search');
      expect(const FontRoute().location, '/setting/font');
    });

    test('AssistantConversationRoute', () {
      expect(
        const AssistantConversationRoute().location,
        '/assistant/conversation',
      );
      expect(
        const AssistantConversationRoute(sessionId: 's1').location,
        '/assistant/conversation?session-id=s1',
      );
    });
  });
}
