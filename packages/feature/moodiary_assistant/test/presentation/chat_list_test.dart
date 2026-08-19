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

/// 记录 initState 的探针：条目状态在换 sliver / 换分支时该原地保留，
/// initState 重跑一次就是丢过一次状态。
class _Probe extends StatefulWidget {
  const _Probe({required this.id, required this.height, required this.log});

  final String id;
  final double height;
  final List<String> log;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.log.add(widget.id);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ValueKey<String>('box-${widget.id}'),
    height: widget.height,
    width: 200,
  );
}

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

  Widget host({
    double viewportHeight = 600,
    double bottomPadding = 80,
    List<String>? probeLog,
    ValueNotifier<double>? liveHeight,
  }) {
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
                if (probeLog != null) {
                  return _Probe(
                    id: item.id,
                    height: _heightOf(text),
                    log: probeLog,
                  );
                }
                // 「活高度」条目：绕过 controller 的通知就地改高，
                // 模拟思考块收起那类纯渲染侧的尺寸变化。
                if (liveHeight != null && item.id == 'live') {
                  return ValueListenableBuilder<double>(
                    valueListenable: liveHeight,
                    builder: (context, height, _) => SizedBox(
                      key: const ValueKey<String>('box-live'),
                      height: height,
                      width: 200,
                    ),
                  );
                }
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

  testWidgets('贴底时流式长高，位置在同一帧跟到新底部（不慢一帧再抽回）', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 流式那条留在正向组，长高走的是 max 变大那条路 —— 物理必须同帧跟上。
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'x'),
    );
    await tester.pumpAndSettle();

    final position = scroll.position;
    expect(
      position.maxScrollExtent - position.pixels,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '前提：开局就精确贴底',
    );

    // **只 pump 一帧**——物理是在布局里生效的，事后追的做法要等到下一帧才补，
    // 那一帧的差值就是肉眼看到的抖。
    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'x' * 10),
    );
    await tester.pump();

    expect(
      position.maxScrollExtent - position.pixels,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '长高的那一帧就该已经在新底部',
    );
  });

  testWidgets('已经滑走时，流式长高不把人拽回底部', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'x'),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 260));
    await tester.pumpAndSettle();
    final away = scroll.position.pixels;
    expect(
      scroll.position.maxScrollExtent - away,
      greaterThan(1),
      reason: '前提：确实已经离开底部',
    );

    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'x' * 10),
    );
    await tester.pump();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(away, epsilon: 0.5),
      reason: '翻历史的人不该被新 token 拽走',
    );
  });

  // 这条守的是「在底部展开思考块会闪」那个 bug：思考块补偿位置时会先
  // releaseFollow()，物理必须随之停手，否则同一帧里两边对着拉。
  testWidgets('releaseFollow 之后流式长高不再贴底', (tester) async {
    controller.setAll([
      for (var i = 0; i < 12; i++)
        _turn('m$i', fromUser: i.isEven, text: 'x' * 3),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'x'),
    );
    await tester.pumpAndSettle();

    final position = scroll.position;
    listKey.currentState!.releaseFollow();
    final held = position.pixels;

    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'x' * 10),
    );
    await tester.pump();

    expect(
      position.pixels,
      moreOrLessEquals(held, epsilon: 0.5),
      reason: '放弃跟随之后，长高不该再把位置拽到新底部',
    );
  });

  testWidgets('isInForwardGroup 认得中心线两侧', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 中心项 = 最新一条已定稿（m29）。放弃跟随之后来的新消息不前移中心，
    // 落在正向组。
    listKey.currentState!.releaseFollow();
    controller.add(_turn('m30', fromUser: true, text: 'x' * 2));
    await tester.pumpAndSettle();

    final state = listKey.currentState!;
    BuildContext ctxOf(String id) =>
        tester.element(find.byKey(ValueKey<String>('box-$id')));

    expect(state.isInForwardGroup(ctxOf('m30')), isTrue, reason: '比中心新');
    expect(state.isInForwardGroup(ctxOf('m29')), isFalse, reason: '中心项本身');
    expect(state.isInForwardGroup(ctxOf('m25')), isFalse, reason: '比中心旧');
  });

  // ── 顶部对齐（不足一屏走 shrinkWrap 分支）────────────────────────
  // 参考 IMChatList：内容不足一屏时是**不可滚动**的顶对齐列表，超过一屏才换成
  // 中心 sliver 双向布局，post-frame 量真实高度切换。

  testWidgets('内容不足一屏时从顶部往下排，且不可滚动', (tester) async {
    seed(3);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 最旧的一条紧贴顶部留白，其余按 40 + 12 的行距往下走。
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, 'm1'), moreOrLessEquals(60, epsilon: 0.5));
    expect(topInList(tester, 'm2'), moreOrLessEquals(112, epsilon: 0.5));
    expect(listKey.currentState!.contentFitsViewport, isTrue);
    // 没有可滚动的范围 —— 这条分支整个不可滚。
    expect(scroll.position.maxScrollExtent, moreOrLessEquals(0, epsilon: 0.5));
  });

  // Bug 回归：空列表 / 短列表拖一把，曾经能把「回到底部」按钮拖出来。
  testWidgets('空列表与短列表拖动不出回到底部按钮', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(AssistantChatList), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);

    seed(3);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AssistantChatList), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);
  });

  // Bug 回归：短会话里用户消息在顶部时，流式回复曾吊在视口底边、
  // 中间隔着一段空白，定稿后又跳回顶部。现在它紧跟在用户消息下面往下长。
  testWidgets('短会话流式：回复紧跟用户消息往下长，定稿不跳', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pump();
    final streamingId = controller.items.last.id;

    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, streamingId), moreOrLessEquals(60, epsilon: 0.5));

    // 流式长高：上沿不动，往下长。
    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'aaa'),
    );
    await tester.pump();
    expect(topInList(tester, streamingId), moreOrLessEquals(60, epsilon: 0.5));

    // 定稿：不换组、不跳。
    controller.batch(() {
      controller.replace((controller.items.last as AssistantTurn).settled);
      controller.endStreaming();
    });
    await tester.pumpAndSettle();
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, streamingId), moreOrLessEquals(60, epsilon: 0.5));
  });

  testWidgets('内容超过一屏时照旧贴底', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 中心线在 600 - 80(底部留白) = 520，最新一条占 [468, 508]，行距留在下面。
    expect(topInList(tester, 'm29'), moreOrLessEquals(468, epsilon: 0.5));
    expect(listKey.currentState!.contentFitsViewport, isFalse);
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
    expect(scroll.position.minScrollExtent, lessThan(0));
  });

  // 流式长高也能把内容顶过一屏 —— 它不重建列表，切换靠尺寸变化通知自己报信。
  testWidgets('流式长高越过一屏后切到贴底', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isTrue);

    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'x' * 15),
    );
    await tester.pumpAndSettle();

    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
  });

  testWidgets('缩回一屏之内交还顶部对齐', (tester) async {
    seed(20);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isFalse);

    controller.removeWhere((item) => item.id != 'm0' && item.id != 'm1');
    await tester.pumpAndSettle();

    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, 'm1'), moreOrLessEquals(60, epsilon: 0.5));
  });

  // ── 中心项前移 ───────────────────────────────────────────────────
  // 双向分支刚挂载时负向组还差一段 bottomPadding 才够一屏，anchor:1 的下界
  // min(0, 视口高 − 负向组高) 拦不住正的「顶边贴顶」位置 —— 贴底时把中心项
  // 跟着最新一条走，窗口在下一两条消息内闭合。

  testWidgets('空会话聊长之后，滑到顶不留空档', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      controller.add(_turn('m$i', fromUser: i.isEven));
      await tester.pumpAndSettle();
    }

    expect(scroll.position.minScrollExtent, lessThan(0), reason: '负向组已经够高');

    // 程序性 jumpTo 不改跟随状态（那是用户滚动的专利），先显式放弃。
    listKey.currentState!.releaseFollow();
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();

    // 滑到头 = 最旧一条紧贴顶部留白，上面不该再有空白。
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('贴底时挪中心项，画面不动', (tester) async {
    // 10 条正好把内容顶过一屏（8 + 520 + 80 = 608 > 600），双向分支刚挂载，
    // 负向组 528 还不够一屏 —— 下界暂时是 0。
    seed(10);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(scroll.position.minScrollExtent, 0, reason: '前提：还在窗口期');

    final before = topOf(tester, 'm9');
    controller.add(_turn('m10', fromUser: true));
    await tester.pump();

    // 新消息把可见内容顶上去正好一行（40 + 12），中心项整段前移不额外贡献位移。
    expect(topOf(tester, 'm9'), moreOrLessEquals(before - 52, epsilon: 0.5));

    controller.add(_turn('m11', fromUser: false));
    await tester.pumpAndSettle();
    expect(scroll.position.minScrollExtent, lessThan(0), reason: '窗口已闭合');

    listKey.currentState!.releaseFollow();
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('滑在历史里时不挪中心项', (tester) async {
    seed(10);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(scroll.position.minScrollExtent, 0, reason: '前提：还在窗口期');

    listKey.currentState!.releaseFollow();
    controller.batch(() {
      for (var i = 10; i < 15; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
    await tester.pumpAndSettle();
    expect(scroll.position.minScrollExtent, 0, reason: '没贴底就一次都别动中心项');

    // 回到底部之后，下一条消息把中心项补上。
    listKey.currentState!.pinToBottom();
    await tester.pumpAndSettle();
    controller.add(_turn('m15', fromUser: true));
    await tester.pumpAndSettle();
    expect(scroll.position.minScrollExtent, lessThan(0));
  });

  // 流式那条正在长个儿：换组会让它的思考块改走另一套补偿。它得留在正向组，
  // 等定稿再被收进去。
  testWidgets('流式那条不会被挪成中心项', (tester) async {
    seed(30);
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
      controller.replace((controller.items.last as AssistantTurn).settled);
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

  // ── 形态切换的连续性 ─────────────────────────────────────────────
  // 两个形态共用同一个 CustomScrollView（同一个 GlobalKey、同一个物理实例），
  // ScrollPosition 跨切换存活，切换那一帧物理直接落位 —— 没有错位帧。

  testWidgets('流式跨过一屏时逐帧连续，没有错位帧', (tester) async {
    controller.setAll([_turn('m0', fromUser: true)]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'x'),
    );
    await tester.pumpAndSettle();
    final id = controller.items.last.id;

    double bottomOf() =>
        tester.getBottomLeft(find.byKey(ValueKey<String>('box-$id'))).dy -
        tester.getTopLeft(find.byType(AssistantChatList)).dy;

    // 顶对齐阶段流式气泡的下沿从 60+h 往下走，够到 508（= 600 − 80 底部留白
    // − 12 行距）之后就钉在那里 —— 跨形态的那两帧也必须如此。
    for (final len in [8, 10, 11, 12, 13, 15]) {
      controller.updateStreaming(
        (controller.items.last as AssistantTurn).copyWith(text: 'x' * len),
      );
      for (var frame = 0; frame < 2; frame++) {
        await tester.pump();
        final expected = (60.0 + 40.0 * len).clamp(0.0, 508.0);
        expect(
          bottomOf(),
          moreOrLessEquals(expected, epsilon: 1),
          reason: 'len=$len 的第 $frame 帧错位了',
        );
      }
    }
    expect(listKey.currentState!.contentFitsViewport, isFalse);
  });

  testWidgets('长会话切到短会话，第一帧就顶对齐', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.setAll([
      _turn('a', fromUser: true),
      _turn('b', fromUser: false),
    ]);
    await tester.pump();

    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(topInList(tester, 'a'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, 'b'), moreOrLessEquals(60, epsilon: 0.5));
  });

  testWidgets('切到另一个长会话，第一帧就在底部', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.setAll([
      for (var i = 0; i < 40; i++) _turn('n$i', fromUser: i.isEven),
    ]);
    await tester.pump();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    expect(find.byKey(const ValueKey<String>('box-n39')), findsOneWidget);
  });

  testWidgets('清空会话立即回到顶对齐空态', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.setAll(const []);
    await tester.pump();

    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);
  });

  // 思考块在短会话里展开、内容长过一屏的场景：releaseFollow 必须挺过形态切换，
  // 否则贴底物理会在切换后接管，把用户刚点开的块一路顶出屏幕。
  testWidgets('releaseFollow 之后长过一屏：落到底但不再跟随', (tester) async {
    controller.setAll([
      _turn('m0', fromUser: true),
      _turn('m1', fromUser: false),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    listKey.currentState!.releaseFollow();
    controller.replace(_turn('m1', fromUser: false, text: 'x' * 15));
    await tester.pumpAndSettle();

    expect(listKey.currentState!.contentFitsViewport, isFalse);
    // 切换那一帧落在新坐标系的底部（与切换前贴底的画面连续）……
    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    // ……但跟随没有被重新打开：released 状态挺过了切换，按钮照常出现。
    expect(find.byKey(const ValueKey('to-bottom')), findsOneWidget);

    // 此后长高不再拽人。
    final held = scroll.position.pixels;
    controller.replace(_turn('m1', fromUser: false, text: 'x' * 18));
    await tester.pump();
    expect(scroll.position.pixels, moreOrLessEquals(held, epsilon: 0.5));
  });

  // 遗留 bug 回归：贴底容差内的慢速拖动刚开始时来了尾部消息（流式占位、工具
  // 提示都会撞上），补跳的 jumpTo 会把正在进行的手势连根拔掉、列表弹回底部。
  testWidgets('拖动中来了尾部消息，不夺走手势不跳底', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 4));
    await tester.pump();
    final mid = scroll.position.pixels;

    controller.add(_turn('new', fromUser: false, text: '0123456789'));
    await tester.pump();
    await tester.pump();
    expect(
      scroll.position.pixels,
      moreOrLessEquals(mid, epsilon: 0.5),
      reason: '拖动中不能被钉回底部',
    );

    // 手势还活着：继续拖有效。
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(scroll.position.pixels, lessThan(mid - 50), reason: '手势被补跳杀掉了');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  // 入口窗口期（负向组还不够一屏）min 被 0 夹着、max 又没动 —— 就地变矮连
  // ScrollMetricsNotification 都不发，形态检查没有触发点。思考块收起的收尾
  // 会调 syncFollowFromPosition，它得顺手把形态量回来。
  testWidgets('就地变矮不发通知时，syncFollowFromPosition 能把形态量回来', (tester) async {
    final liveHeight = ValueNotifier<double>(100);
    addTearDown(liveHeight.dispose);
    controller.batch(() {
      for (var i = 0; i < 9; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
      controller.add(_turn('live', fromUser: false));
    });
    await tester.pumpWidget(host(liveHeight: liveHeight));
    await tester.pumpAndSettle();
    // 8 + 9×52 + (100+12) + 80 = 668 > 600：双向形态，且还在入口窗口期。
    expect(listKey.currentState!.contentFitsViewport, isFalse);
    expect(scroll.position.minScrollExtent, 0);

    // 就地缩回一屏之内（668 → 588），没有任何通知。
    liveHeight.value = 20;
    await tester.pump();
    expect(
      listKey.currentState!.contentFitsViewport,
      isFalse,
      reason: '前提：静默变矮确实没触发形态检查',
    );

    listKey.currentState!.syncFollowFromPosition();
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  // 条目用全局 key：换形态、挪中心项都要换 sliver，元素得连同状态
  // 原地重挂 —— 不然展开着的思考块会在切换那一刻悄悄收起来。
  testWidgets('换分支与挪中心项不重建还在视口里的条目', (tester) async {
    final log = <String>[];
    seed(3);
    await tester.pumpWidget(host(probeLog: log));
    await tester.pumpAndSettle();
    expect(log, ['m2', 'm1', 'm0'], reason: '顶对齐分支把三条都建出来');

    // 长过一屏：切到双向分支。
    controller.batch(() {
      for (var i = 3; i < 20; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
    await tester.pumpAndSettle();
    expect(
      log.where((id) => id == 'm19').length,
      1,
      reason: '切分支时还在视口里的条目不该重跑 initState',
    );

    // 贴底时来一条新消息：中心项前移，m19 换了 sliver 但没换元素。
    controller.add(_turn('m20', fromUser: true));
    await tester.pumpAndSettle();
    expect(log.where((id) => id == 'm19').length, 1);
    expect(log.where((id) => id == 'm20').length, 1);
  });
}
