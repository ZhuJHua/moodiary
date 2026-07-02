import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/app/router/router.dart';

void main() {
  group('route tree config', () {
    // GoRouter 构造时会做配置校验（path 唯一性、shell/branch navigatorKey 合法性
    // 等），路由树能正常构造即代表结构有效。不 pump，不触发页面 build。
    testWidgets('mobile tree builds a valid GoRouter', (tester) async {
      expect(
        () => GoRouter(
          routes: buildMobileRoutes(),
          initialLocation: '/',
        ),
        returnsNormally,
      );
    });
  });

  // 这些断言锁定旧 go_router_builder 的 location 编码契约（kebab query key、
  // DiaryType→markdown/rich-text、可选项省略规则），保证深链/参数行为不变。
  group('location encoding contract', () {
    test('DiaryRoute', () {
      expect(
        const DiaryRoute(type: DiaryType.markdown, diaryId: 'abc').location,
        '/diary/abc?type=markdown',
      );
      // edit 默认 false 时省略；为 true 才写入 edit=true（统一页进入编辑态）。
      expect(
        const DiaryRoute(
          type: DiaryType.richText,
          diaryId: 'x',
          edit: true,
        ).location,
        '/diary/x?type=rich-text&edit=true',
      );
    });

    test('NewDiaryRoute', () {
      expect(
        const NewDiaryRoute(type: DiaryType.tiptap).location,
        '/diary-new?type=tiptap',
      );
      expect(
        const NewDiaryRoute(type: DiaryType.markdown).location,
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
      // 无 sessionId = 新对话，省略 query。
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
