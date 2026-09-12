import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/presentation/assistant_notice.dart';
import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

AssistantTurn _turn(String id, {required bool fromUser}) => AssistantTurn(
  id: id,
  fromUser: fromUser,
  text: 'x',
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late AssistantChatController controller;
  late ScrollController scroll;
  late GlobalKey<AssistantChatListState> listKey;

  setUp(() {
    controller = AssistantChatController();
    scroll = ScrollController();
    listKey = GlobalKey<AssistantChatListState>();
  });

  tearDown(() {
    controller.dispose();
    scroll.dispose();
  });

  Widget host({
    required double detailHeight,
    bool themedDetail = false,
    bool keyByText = false,
    ValueNotifier<double>? width,
  }) {
    final data = buildMuiTheme(brightness: Brightness.light);
    return TranslationProvider(
      child: MuiTheme(
        data: data,
        child: MaterialApp(
          theme: data,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: width ?? ValueNotifier(400),
                builder: (context, w, child) =>
                    SizedBox(width: w, height: 600, child: child),
                child: AssistantChatList(
                  key: listKey,
                  controller: controller,
                  scrollController: scroll,
                  bottomPadding: 80,
                  itemBuilder: (context, item, index) {
                    if (item.id == 'pair') {
                      return Column(
                        crossAxisAlignment: .start,
                        children: [
                          for (final k in const ['a', 'b'])
                            AssistantNotice(
                              stateKey: k,
                              icon: LucideIcons.brain,
                              kind: '块 $k',
                              detail: (context) => SizedBox(
                                key: ValueKey<String>('detail-$k'),
                                height: detailHeight,
                                width: 200,
                              ),
                            ),
                        ],
                      );
                    }
                    if (item.id.startsWith('notice')) {
                      return AssistantNotice(
                        key: keyByText
                            ? ValueKey((item as AssistantTurn).text)
                            : null,
                        stateKey: 'thinking',
                        icon: LucideIcons.brain,
                        kind: item.id == 'notice' ? '已思考 6 秒' : '块 ${item.id}',
                        summary: '摘要',
                        detail: themedDetail
                            ? (context) => Text(
                                List.filled(40, '思考过程的一行文字').join('\n'),
                                key: ValueKey<String>('detail-${item.id}'),
                                style: context
                                    .theme
                                    .typography
                                    .bodySmall
                                    .onSurfaceVariant,
                              )
                            : (context) => SizedBox(
                                key: ValueKey<String>('detail-${item.id}'),
                                height: detailHeight,
                                width: 200,
                              ),
                      );
                    }
                    return SizedBox(
                      key: ValueKey<String>('box-${item.id}'),
                      height: 60,
                      width: 200,
                    );
                  },
                  scrollToBottomBuilder: (context, visible, onTap) => visible
                      ? const SizedBox(key: ValueKey('to-bottom'))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> jumpToEdge(WidgetTester tester, {required bool top}) async {
    for (var i = 0; i < 8; i++) {
      final position = scroll.position;
      final target = top ? position.minScrollExtent : position.maxScrollExtent;
      if ((position.pixels - target).abs() <= 0.5 && i > 0) return;
      scroll.jumpTo(target);
      await tester.pumpAndSettle();
    }
  }

  double? topOfFirst(WidgetTester tester) {
    final finder = find.byKey(const ValueKey<String>('box-m0'));
    if (finder.evaluate().isEmpty) return null;
    return tester.getTopLeft(finder).dy -
        tester.getTopLeft(find.byType(AssistantChatList)).dy;
  }

  testWidgets('展开的思考块滚出缓存区被回收，滚回来仍是展开的', (tester) async {
    controller.setAll([
      AssistantTurn(
        id: 'notice',
        fromUser: false,
        text: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      for (var i = 0; i < 30; i++) _turn('m$i', fromUser: i.isEven),
    ]);
    await tester.pumpWidget(host(detailHeight: 200));
    await tester.pumpAndSettle();
    expect(find.text('已思考 6 秒'), findsNothing);

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 300));
    await tester.pumpAndSettle();
    await jumpToEdge(tester, top: true);
    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );

    await jumpToEdge(tester, top: false);
    expect(find.text('已思考 6 秒'), findsNothing, reason: '要真的被回收过');

    await jumpToEdge(tester, top: true);
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
      reason: '重建的第一帧就该是展开的，不走动画',
    );
  });

  testWidgets('流式结束后块被重建，展开状态与位置都不变', (tester) async {
    AssistantTurn notice(String text) => AssistantTurn(
      id: 'notice',
      fromUser: false,
      text: text,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    controller.setAll([_turn('m0', fromUser: true), notice('')]);
    await tester.pumpWidget(host(detailHeight: 200, keyByText: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('已思考 6 秒')).dy;
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );

    controller.setAll([_turn('m0', fromUser: true), notice('done')]);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );
    expect(tester.getTopLeft(find.text('已思考 6 秒')).dy, top);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );
  });

  testWidgets('顶对齐时展开思考块跨过一屏，上方消息逐帧不跳', (tester) async {
    controller.setAll([
      _turn('m0', fromUser: true),
      AssistantTurn(
        id: 'notice',
        fromUser: false,
        text: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(host(detailHeight: 700));
    await tester.pumpAndSettle();

    expect(listKey.currentState!.contentFitsViewport, isTrue);
    final before = topOfFirst(tester);
    expect(before, moreOrLessEquals(8, epsilon: 0.5));

    await tester.tap(find.text('已思考 6 秒'));

    final seen = <double?>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(topOfFirst(tester));
    }
    await tester.pumpAndSettle();
    seen.add(topOfFirst(tester));

    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(
      seen.every((top) => top != null && top >= -0.5),
      isTrue,
      reason: '展开的是 m0 下面那条，m0 不该被推出视口顶部：$seen',
    );
  });

  testWidgets('展开跨屏后再收起，上方消息与思考块都不跳', (tester) async {
    controller.setAll([
      _turn('m0', fromUser: true),
      AssistantTurn(
        id: 'notice',
        fromUser: false,
        text: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    await tester.pumpWidget(host(detailHeight: 0, themedDetail: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(topOfFirst(tester), moreOrLessEquals(8, epsilon: 1));

    final noticeTop = tester.getTopLeft(find.text('已思考 6 秒')).dy;
    await tester.tap(find.text('已思考 6 秒'));

    final seenM0 = <double?>[];
    final seenNotice = <double>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seenM0.add(topOfFirst(tester));
      seenNotice.add(tester.getTopLeft(find.text('已思考 6 秒')).dy);
    }
    await tester.pumpAndSettle();
    seenM0.add(topOfFirst(tester));
    seenNotice.add(tester.getTopLeft(find.text('已思考 6 秒')).dy);

    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(
      seenM0.every((top) => top != null && (top - 8).abs() <= 1),
      isTrue,
      reason: 'm0 应始终停在 8：$seenM0',
    );
    expect(
      seenNotice.every((top) => (top - noticeTop).abs() <= 1),
      isTrue,
      reason: '思考块顶部应始终停在 $noticeTop：$seenNotice',
    );
  });

  AssistantTurn noticeTurn(String id) => AssistantTurn(
    id: id,
    fromUser: false,
    text: '',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<List<(double?, double, double)>> frames(
    WidgetTester tester,
    String upper,
    String lower,
  ) async {
    final upperText = find.text(upper, skipOffstage: false);
    final lowerText = find.text(lower, skipOffstage: false);
    final seen = <(double?, double, double)>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seen.add((
        topOfFirst(tester),
        tester.getTopLeft(upperText).dy,
        tester.getTopLeft(lowerText).dy,
      ));
    }
    await tester.pumpAndSettle();
    return seen;
  }

  testWidgets('先展开下面那块，动画中再展开上面那块：上面那块顶部不动', (tester) async {
    controller.setAll([
      _turn('m0', fromUser: true),
      noticeTurn('noticeA'),
      _turn('m1', fromUser: true),
      noticeTurn('noticeB'),
    ]);
    await tester.pumpWidget(host(detailHeight: 400));
    await tester.pumpAndSettle();
    final upperTop = tester.getTopLeft(find.text('块 noticeA')).dy;

    await tester.tap(find.text('块 noticeB'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('块 noticeA'));
    final seen = await frames(tester, '块 noticeA', '块 noticeB');

    expect(
      seen.every((f) => f.$1 != null && (f.$1! - 8).abs() <= 1),
      isTrue,
      reason: 'm0 应始终停在 8：$seen',
    );
    expect(
      seen.every((f) => (f.$2 - upperTop).abs() <= 1),
      isTrue,
      reason: '上面那块顶部应停在 $upperTop：$seen',
    );
    expect(
      tester.getTopLeft(find.text('块 noticeB', skipOffstage: false)).dy,
      greaterThan(upperTop + 400),
      reason: '下面那块该被上面展开的 400 推下去',
    );
  });

  testWidgets('同一条里两个块同时展开：hold 按计数释放，都停在原位', (tester) async {
    controller.setAll([_turn('m0', fromUser: true), noticeTurn('pair')]);
    await tester.pumpWidget(host(detailHeight: 400));
    await tester.pumpAndSettle();
    final upperTop = tester.getTopLeft(find.text('块 a')).dy;

    await tester.tap(find.text('块 a'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('块 b'));
    final seen = await frames(tester, '块 a', '块 b');

    expect(
      seen.every((f) => f.$1 != null && (f.$1! - 8).abs() <= 1),
      isTrue,
      reason: 'm0 应始终停在 8：$seen',
    );
    expect(
      seen.every((f) => (f.$2 - upperTop).abs() <= 1),
      isTrue,
      reason: '块 a 顶部应停在 $upperTop：$seen',
    );
    expect(tester.getSize(find.byKey(const ValueKey('detail-a'))).height, 400);
    expect(tester.getSize(find.byKey(const ValueKey('detail-b'))).height, 400);
    expect(listKey.currentState!.contentFitsViewport, isFalse);
  });

  testWidgets('宽度变了整表重量：离屏量到的是展开后的高度', (tester) async {
    final width = ValueNotifier<double>(400);
    addTearDown(width.dispose);
    controller.setAll([
      AssistantTurn(
        id: 'notice',
        fromUser: false,
        text: '',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      for (var i = 0; i < 30; i++) _turn('m$i', fromUser: i.isEven),
    ]);
    await tester.pumpWidget(host(detailHeight: 200, width: width));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 300));
    await tester.pumpAndSettle();
    await jumpToEdge(tester, top: true);
    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    await jumpToEdge(tester, top: false);
    expect(find.text('已思考 6 秒'), findsNothing);

    width.value = 380;
    await tester.pumpAndSettle();

    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('已思考 6 秒')).dy -
          tester.getTopLeft(find.byType(AssistantChatList)).dy,
      lessThan(30),
      reason: '边界若按收起高度算，思考块会被顶出视口 200px',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );
  });

  testWidgets('动画中途再点一次：hold 不泄漏，列表之后还会重估中心', (tester) async {
    controller.setAll([_turn('m0', fromUser: true), noticeTurn('notice')]);
    await tester.pumpWidget(host(detailHeight: 200));
    await tester.pumpAndSettle();
    final state = listKey.currentState!;

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(state.holdCount, 1);
    await tester.tap(find.text('已思考 6 秒'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(state.holdCount, 1, reason: '掉头不再要第二份');
    await tester.pumpAndSettle();
    expect(state.holdCount, 0);
    expect(find.byKey(const ValueKey('detail-notice')), findsNothing);

    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    expect(state.holdCount, 0);
    expect(
      tester.getSize(find.byKey(const ValueKey('detail-notice'))).height,
      200,
    );
  });

  testWidgets('贴底时收起尾部的大块：底部逐帧贴着视口底，不露空白也不整会话重建', (tester) async {
    controller.setAll([
      for (var i = 0; i < 40; i++) _turn('m$i', fromUser: i.isEven),
      noticeTurn('notice'),
    ]);
    await tester.pumpWidget(host(detailHeight: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已思考 6 秒'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AssistantChatList), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(listKey.currentState!.following, isTrue);
    final state = listKey.currentState!;
    double noticeBottom() =>
        tester
            .getBottomLeft(find.byType(AssistantNotice, skipOffstage: false))
            .dy -
        tester.getTopLeft(find.byType(AssistantChatList)).dy;
    // 600 - 80 底部留白 - 12 条目间距
    expect(noticeBottom(), moreOrLessEquals(508, epsilon: 0.5));
    final centerBefore = state.centerIndex;

    await tester.tap(find.text('已思考 6 秒'));
    final seen = <double>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      seen.add(noticeBottom());
    }
    await tester.pumpAndSettle();
    seen.add(noticeBottom());

    final pretty = seen.map((e) => e.toStringAsFixed(1)).toList();
    expect(
      seen.every((b) => b <= 508.5 && b >= 508 - 50),
      isTrue,
      reason: '收起过程底部抬升要有界：$pretty',
    );
    expect(
      seen.last,
      moreOrLessEquals(508, epsilon: 1),
      reason: '收起完贴着底：$pretty',
    );
    expect(find.byKey(const ValueKey<String>('box-m0')), findsNothing);
    expect(find.byKey(const ValueKey('detail-notice')), findsNothing);
    expect(
      state.centerIndex,
      lessThan(centerBefore + 12),
      reason: '不该把中心退到最老一条',
    );
  });

  testWidgets('展开动画中就把它甩出缓存区：作废旧高度，离屏重量到展开后的高度', (tester) async {
    controller.setAll([
      noticeTurn('notice'),
      for (var i = 0; i < 30; i++) _turn('m$i', fromUser: i.isEven),
    ]);
    await tester.pumpWidget(host(detailHeight: 200));
    await tester.pumpAndSettle();
    final minCollapsed = scroll.position.minScrollExtent;

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 300));
    await tester.pumpAndSettle();
    await jumpToEdge(tester, top: true);
    await tester.tap(find.text('已思考 6 秒'));
    await tester.pump(const Duration(milliseconds: 40));
    await jumpToEdge(tester, top: false);
    await tester.pumpAndSettle();
    expect(find.text('已思考 6 秒'), findsNothing);

    expect(
      scroll.position.minScrollExtent,
      moreOrLessEquals(minCollapsed - 207, epsilon: 0.5),
    );
  });
}
