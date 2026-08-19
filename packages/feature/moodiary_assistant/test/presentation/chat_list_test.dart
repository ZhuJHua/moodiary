import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:mui/mui.dart';

/// 每条消息渲染成一个固定高度的方块，高度由正文长度推出来 ——
/// 这样「流式增长」在测试里就是「把正文改长」。
const double _kUnitHeight = 40;

double _heightOf(String text) => _kUnitHeight * (text.length.clamp(1, 20));

AssistantTurn _turn(String id, {required bool fromUser, String text = 'x'}) =>
    AssistantTurn(
      id: id,
      fromUser: fromUser,
      text: text,
      createdAt: DateTime.utc(2026, 8, 17),
    );

void main() {
  late AssistantChatController controller;
  late ScrollController scroll;
  late GlobalKey<AssistantChatListState> listKey;

  /// 每个 id 被 itemBuilder 调用了多少次。
  late Map<String, int> builds;

  setUp(() {
    controller = AssistantChatController();
    scroll = ScrollController();
    listKey = GlobalKey<AssistantChatListState>();
    builds = {};
  });

  tearDown(() {
    controller.dispose();
    scroll.dispose();
  });

  Widget host({double viewportHeight = 600, double bottomPadding = 80}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: viewportHeight,
            child: AssistantChatList(
              key: listKey,
              controller: controller,
              scrollController: scroll,
              bottomPadding: bottomPadding,
              itemBuilder: (context, item, index) {
                builds[item.id] = (builds[item.id] ?? 0) + 1;
                final text = item is AssistantTurn ? item.text : item.id;
                return SizedBox(
                  key: ValueKey<String>('box-${item.id}'),
                  height: _heightOf(text),
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
    );
  }

  void seed(int count) {
    controller.batch(() {
      for (var i = 0; i < count; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
  }

  double topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey<String>('box-$id'))).dy;

  /// 相对列表上沿的纵坐标 —— host 把列表居中放着，全局坐标带着一段偏移。
  double topInList(WidgetTester tester, String id) =>
      topOf(tester, id) - tester.getTopLeft(find.byType(AssistantChatList)).dy;

  // 这是选中心 sliver 布局的头号理由：普通正向列表载入已有会话必须从顶部跳到底部，
  // 而 maxScrollExtent 是外推估计值，那个跳要迭代好几次才收敛、看得见。
  testWidgets('载入长会话时开局就在底部，最新一条可见', (tester) async {
    seed(40);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    expect(find.byKey(const ValueKey<String>('box-m39')), findsOneWidget);
    // 最旧的那条在几十屏之外，不该被建出来。
    expect(find.byKey(const ValueKey<String>('box-m0')), findsNothing);
  });

  // 需求原文：用户向上滑离开底部之后，即使 agent 还在输出，滚动位置也不能变。
  testWidgets('滑走看历史时，末条长高不移动画面', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();

    final anchorId =
        find.byKey(const ValueKey<String>('box-m20')).evaluate().isNotEmpty
        ? 'm20'
        : 'm25';
    final before = topOf(tester, anchorId);
    final pixelsBefore = scroll.position.pixels;

    // 末条流式长高（40 → 400）。
    controller.replace(_turn('m29', fromUser: false, text: '0123456789'));
    await tester.pumpAndSettle();

    expect(topOf(tester, anchorId), moreOrLessEquals(before, epsilon: 0.5));
    expect(
      scroll.position.pixels,
      moreOrLessEquals(pixelsBefore, epsilon: 0.5),
    );
  });

  // 前插历史是分页要的性质：加更早的消息只让 minScrollExtent 更负，画面不动。
  testWidgets('往表头补历史不移动画面', (tester) async {
    seed(20);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    final before = topOf(tester, 'm15');
    final pixelsBefore = scroll.position.pixels;

    controller.batch(() {
      for (var i = 0; i < 10; i++) {
        controller.insertAt(0, _turn('older$i', fromUser: true));
      }
    });
    await tester.pumpAndSettle();

    expect(topOf(tester, 'm15'), moreOrLessEquals(before, epsilon: 0.5));
    expect(
      scroll.position.pixels,
      moreOrLessEquals(pixelsBefore, epsilon: 0.5),
    );
  });

  // 视口变矮（键盘弹起）会让 max 变大而 pixels 不动，且**零通知** ——
  // 不显式补跳的话「在底部」就被静默丢掉，最后一条藏到键盘后面。
  testWidgets('跟随中视口变矮会重新钉底', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );

    await tester.pumpWidget(host(viewportHeight: 300));
    await tester.pumpAndSettle();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
  });

  testWidgets('尾部新消息在跟随时把列表带到底', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.add(_turn('new', fromUser: true, text: '012345'));
    await tester.pumpAndSettle();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    expect(find.byKey(const ValueKey<String>('box-new')), findsOneWidget);
  });

  testWidgets('滑走之后尾部新消息不打扰用户', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await tester.pumpAndSettle();
    final before = topOf(tester, 'm20');
    final pixelsBefore = scroll.position.pixels;

    controller.add(_turn('new', fromUser: false, text: '0123456789'));
    await tester.pumpAndSettle();

    expect(topOf(tester, 'm20'), moreOrLessEquals(before, epsilon: 0.5));
    expect(
      scroll.position.pixels,
      moreOrLessEquals(pixelsBefore, epsilon: 0.5),
    );
  });

  // ── 性能 ────────────────────────────────────────────────────────
  // 流式一个 token 只该重建那一条气泡。整列表重建意味着每个可见气泡都重跑一遍
  // GptMarkdown 解析，每秒几十次。
  testWidgets('流式增量只重建流式那一条', (tester) async {
    seed(6);
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final streamingId = controller.items.last.id;
    final baseline = Map<String, int>.of(builds);

    for (final text in ['ab', 'abc', 'abcd']) {
      controller.updateStreaming(
        (controller.items.last as AssistantTurn).copyWith(text: text),
      );
      await tester.pump();
    }

    for (final entry in baseline.entries) {
      if (entry.key == streamingId) continue;
      expect(
        builds[entry.key],
        entry.value,
        reason: '${entry.key} 在流式期间被重建了 —— 整列表重建的信号',
      );
    }
    expect(builds[streamingId], greaterThan(baseline[streamingId]!));
  });

  testWidgets('流式期间不发列表通知', (tester) async {
    seed(4);
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'ab'),
    );
    await tester.pump();

    expect(notifications, 0);
  });

  // 回归：从会话恢复（此时正钉在底部）后，用手指**慢慢**往下滑看历史。
  //
  // 曾经的死锁：内容尺寸随老消息 materialize 每帧重估，于是拖动的每一帧都带一条
  // ScrollMetricsNotification；头几像素内 _following 还是 true，补跳循环因此启动
  // 并置起 _pinning，而 _pinning 又让后续拖动更新被忽略 —— 列表被连着拽回底部。
  testWidgets('恢复会话后慢速下滑能真的滑动，不被弹回底部', (tester) async {
    // 高度必须参差：等高列表的外推估计正好准，滑动时不重估，也就不发 metrics 通知。
    controller.batch(() {
      for (var i = 0; i < 40; i++) {
        controller.add(
          _turn('m$i', fromUser: i.isEven, text: 'x' * (i % 7 == 0 ? 12 : 1)),
        );
      }
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final start = scroll.position.pixels;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    // 先吃掉 touch slop，再一小段一小段地挪 —— 每步位移都小于「已在底部」的容差，
    // 这正是慢速滑动的样子。
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final draggedTo = scroll.position.pixels;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(draggedTo, lessThan(start - 20), reason: '拖动过程中就被拽回去了');
    expect(scroll.position.pixels, lessThan(start - 20), reason: '松手后又被弹回底部');
  });

  // 松手之后（惯性阶段结束、真的停在半路）才允许恢复补跳判断。
  testWidgets('滑到半路松手后不跟随，新消息不打扰', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final resting = scroll.position.pixels;
    controller.add(_turn('new', fromUser: false, text: '0123456789'));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, moreOrLessEquals(resting, epsilon: 0.5));
  });

  // 用 correctPixels 静默改位置的路径（思考块展开 / 收起）不发滚动通知，
  // 常规那条「拖动时重新判断」的路走不到 —— 不显式同步的话跟随状态会卡住，
  // 收起后明明已经回到底部，「回到底部」按钮还挂着。
  testWidgets('静默改位置后 syncFollowFromPosition 能把跟随状态判回来', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = listKey.currentState!;
    final position = scroll.position;

    // 模拟「展开」：放弃跟随 + 静默往上挪。
    state.releaseFollow();
    position.correctPixels(position.pixels - 300);
    await tester.pump();
    state.syncFollowFromPosition();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('to-bottom')),
      findsOneWidget,
      reason: '离开底部之后该出现回到底部按钮',
    );

    // 模拟「收起」：静默挪回底部。
    position.correctPixels(position.maxScrollExtent);
    await tester.pump();
    state.syncFollowFromPosition();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('to-bottom')),
      findsNothing,
      reason: '回到底部之后按钮必须收起来',
    );
  });

  // 静默补偿如果**精确**落在底部，同步跟随之后不该再有任何位移 ——
  // 补跳是空操作。差几像素的话，补跳会在下一帧把它补掉，那一跳是看得见的，
  // 也就是「展开收起闪一下」的由来。
  testWidgets('精确落回底部后，同步跟随不产生第二次位移', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final state = listKey.currentState!;
    final position = scroll.position;

    state.releaseFollow();
    position.correctPixels(position.pixels - 300);
    await tester.pump();

    // 精确回到底部（这正是收起时那个 clamp 要保证的落点）。
    position.correctPixels(position.maxScrollExtent);
    await tester.pump();
    state.syncFollowFromPosition();
    final settled = position.pixels;

    await tester.pumpAndSettle();
    expect(
      position.pixels,
      moreOrLessEquals(settled, epsilon: 0.5),
      reason: '落点精确时不该再被补跳挪一次',
    );
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);
  });

  testWidgets('贴底时内容长高，位置在同一帧跟到新底部（不慢一帧再抽回）', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = scroll.position;
    expect(
      position.maxScrollExtent - position.pixels,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '前提：开局就精确贴底',
    );

    // 模拟流式：把最后一条改长。**只 pump 一帧**——物理是在布局里生效的，
    // 事后追的做法要等到下一帧才补，那一帧的差值就是肉眼看到的抖。
    controller.replace(_turn('m11', fromUser: false, text: 'x' * 10));
    await tester.pump();

    expect(
      position.maxScrollExtent - position.pixels,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '长高的那一帧就该已经在新底部',
    );
  });

  testWidgets('已经滑走时，内容长高不把人拽回底部', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 260));
    await tester.pumpAndSettle();
    final away = scroll.position.pixels;
    expect(
      scroll.position.maxScrollExtent - away,
      greaterThan(1),
      reason: '前提：确实已经离开底部',
    );

    controller.replace(_turn('m11', fromUser: false, text: 'x' * 10));
    await tester.pump();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(away, epsilon: 0.5),
      reason: '翻历史的人不该被新 token 拽走',
    );
  });

  // 这条守的是「在底部展开思考块会闪」那个 bug：思考块补偿位置时会先
  // releaseFollow()，物理必须随之停手，否则同一帧里两边对着拉。
  testWidgets('releaseFollow 之后内容长高不再贴底', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final position = scroll.position;
    listKey.currentState!.releaseFollow();
    final held = position.pixels;

    controller.replace(_turn('m11', fromUser: false, text: 'x' * 10));
    await tester.pump();

    expect(
      position.pixels,
      moreOrLessEquals(held, epsilon: 0.5),
      reason: '放弃跟随之后，长高不该再把位置拽到新底部',
    );
  });

  testWidgets('isInForwardGroup 认得中心线两侧', (tester) async {
    // 负向组必须先超过一屏（8 x 92 = 736 > 600）：不然贴底时中心项会被
    // _advanceCenterIfShallow 一路挪到最新一条，新消息也就不落在正向组了。
    controller.setAll([
      for (var i = 0; i < 8; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 2),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 中心项是载入时最新的那条（m7）。之后来的新消息落在正向组。
    controller.add(_turn('m8', fromUser: true, text: 'x' * 2));
    await tester.pumpAndSettle();

    final state = listKey.currentState!;
    BuildContext ctxOf(String id) =>
        tester.element(find.byKey(ValueKey<String>('box-$id')));

    expect(state.isInForwardGroup(ctxOf('m8')), isTrue, reason: '比中心新');
    expect(state.isInForwardGroup(ctxOf('m7')), isFalse, reason: '中心项本身');
    expect(state.isInForwardGroup(ctxOf('m4')), isFalse, reason: '比中心旧');
  });

  // ── 顶部对齐 ────────────────────────────────────────────────────
  // 中心 sliver 是从中心线（视口底边）往上累加的，不补差额的话短会话整段吊在底边。

  testWidgets('内容不足一屏时从顶部往下排', (tester) async {
    seed(3);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 最旧的一条紧贴顶部留白，其余按 40 + 12 的行距往下走。
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, 'm1'), moreOrLessEquals(60, epsilon: 0.5));
    expect(topInList(tester, 'm2'), moreOrLessEquals(112, epsilon: 0.5));
    expect(listKey.currentState!.contentFitsViewport, isTrue);
  });

  testWidgets('内容超过一屏时照旧贴底', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 中心线在 600 - 80(底部留白) = 520，最新一条占 [468, 508]，行距留在下面。
    expect(topInList(tester, 'm29'), moreOrLessEquals(468, epsilon: 0.5));
    expect(listKey.currentState!.contentFitsViewport, isFalse);
  });

  // 差额必须在布局里算出来。放到 post-frame 去 setState 的话，每次长高都会先跳一下
  // 再回来 —— 流式每换一行都看得见。**只 pump 一帧**就是在守这条。
  testWidgets('短会话里正向组长高，顶部不位移', (tester) async {
    seed(2);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    // 比中心项新，落在正向组。
    controller.add(_turn('m2', fromUser: false));
    await tester.pumpAndSettle();

    final before = topInList(tester, 'm0');
    expect(before, moreOrLessEquals(8, epsilon: 0.5), reason: '前提：已经顶部对齐');

    controller.replace(_turn('m2', fromUser: false, text: 'xx'));
    await tester.pump();

    expect(topInList(tester, 'm0'), moreOrLessEquals(before, epsilon: 0.5));
  });

  // 思考块展开的等价物：负向组里某一条长高。差额同帧收窄，块因此是往下长的。
  testWidgets('短会话里负向组长高，顶部不位移', (tester) async {
    seed(3);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final before = topInList(tester, 'm0');

    controller.replace(_turn('m2', fromUser: false, text: 'xx'));
    await tester.pump();

    expect(topInList(tester, 'm0'), moreOrLessEquals(before, epsilon: 0.5));
    expect(topInList(tester, 'm2'), moreOrLessEquals(112, epsilon: 0.5));
  });

  testWidgets('长过一屏之后交回贴底，不留顶部空档', (tester) async {
    seed(3);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isTrue);

    controller.batch(() {
      for (var i = 3; i < 20; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
    await tester.pumpAndSettle();

    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(topInList(tester, 'm19'), moreOrLessEquals(468, epsilon: 0.5));
  });


  // ── 中心项前移 ───────────────────────────────────────────────────
  // anchor:1 给出的下界恒 <= 0，而「顶边贴住视口顶」在负向组比视口矮时是个正数 ——
  // 中间那段没人拦。空会话一句句聊起来最容易踩到：中心项钉死在第一条上，
  // 负向组永远只有它。

  testWidgets('空会话聊长之后，滑到顶不留空档', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      controller.add(_turn('m$i', fromUser: i.isEven));
      await tester.pumpAndSettle();
    }

    expect(scroll.position.minScrollExtent, lessThan(0), reason: '负向组已经够高');

    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();

    // 滑到头 = 最旧一条紧贴顶部留白，上面不该再有空白。
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('贴底时挪中心项，画面不动', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 先攒出那个深坑：放弃跟随之后新消息不触发前移，负向组一直只有 m0。
    listKey.currentState!.releaseFollow();
    controller.batch(() {
      for (var i = 1; i < 20; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
    await tester.pumpAndSettle();
    listKey.currentState!.pinToBottom();
    await tester.pumpAndSettle();
    expect(scroll.position.minScrollExtent, 0, reason: '前提：下界还是错的');

    final before = topOf(tester, 'm19');
    controller.add(_turn('m20', fromUser: true));
    await tester.pump();

    // 新消息把可见内容顶上去正好一行（40 + 12），中心项整段前移不额外贡献位移。
    expect(topOf(tester, 'm19'), moreOrLessEquals(before - 52, epsilon: 0.5));
    expect(scroll.position.minScrollExtent, lessThan(0), reason: '下界已经修好');
  });

  testWidgets('滑在历史里时不挪中心项', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    listKey.currentState!.releaseFollow();
    controller.batch(() {
      for (var i = 1; i < 20; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final before = topOf(tester, 'm10');

    controller.add(_turn('m20', fromUser: true));
    await tester.pumpAndSettle();

    expect(topOf(tester, 'm10'), moreOrLessEquals(before, epsilon: 0.5));
    expect(scroll.position.minScrollExtent, 0, reason: '没贴底就一次都别动中心项');
  });


  // 流式那条正在长个儿：换组会让它的思考块改走另一套补偿，也会让
  // 「一个 token 只重建一条」失效。它得留在正向组，等定稿再被收进去。
  testWidgets('流式那条不会被挪成中心项', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpAndSettle();

    final streamingId = controller.items.last.id;
    final state = listKey.currentState!;
    expect(
      state.isInForwardGroup(
        tester.element(find.byKey(ValueKey<String>('box-$streamingId'))),
      ),
      isTrue,
    );

    // 定稿之后才收进负向组。
    controller.batch(() {
      controller.replace(
        (controller.items.last as AssistantTurn).settled,
      );
      controller.endStreaming();
    });
    await tester.pumpAndSettle();
    expect(
      state.isInForwardGroup(
        tester.element(find.byKey(ValueKey<String>('box-$streamingId'))),
      ),
      isFalse,
    );
  });

}
