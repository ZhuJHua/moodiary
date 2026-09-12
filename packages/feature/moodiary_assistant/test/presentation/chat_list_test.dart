import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:mui/mui.dart';

const double _kUnitHeight = 40;

double _heightOf(String text) => _kUnitHeight * (text.length.clamp(1, 20));

AssistantTurn _turn(String id, {required bool fromUser, String text = 'x'}) =>
    AssistantTurn(
      id: id,
      fromUser: fromUser,
      text: text,
      createdAt: DateTime.utc(2026, 8, 17),
    );

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
    bool nestedScroller = false,
    ValueNotifier<double>? viewport,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: viewport ?? ValueNotifier(viewportHeight),
            builder: (context, height, child) =>
                SizedBox(width: 400, height: height, child: child),
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
                final box = SizedBox(
                  key: ValueKey<String>('box-${item.id}'),
                  height: _heightOf(text),
                  width: 200,
                );
                if (!nestedScroller) return box;
                return SingleChildScrollView(
                  key: ValueKey<String>('code-${item.id}'),
                  scrollDirection: .horizontal,
                  child: SizedBox(width: 900, child: box),
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

  double bottomInList(WidgetTester tester, String id) =>
      tester.getBottomLeft(find.byKey(ValueKey<String>('box-$id'))).dy -
      tester.getTopLeft(find.byType(AssistantChatList)).dy;

  void seed(int count) {
    controller.batch(() {
      for (var i = 0; i < count; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
    });
  }

  double topOf(WidgetTester tester, String id) =>
      tester.getTopLeft(find.byKey(ValueKey<String>('box-$id'))).dy;

  double topInList(WidgetTester tester, String id) =>
      topOf(tester, id) - tester.getTopLeft(find.byType(AssistantChatList)).dy;

  testWidgets('载入长会话时开局就在底部，最新一条可见', (tester) async {
    seed(40);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    expect(find.byKey(const ValueKey<String>('box-m39')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('box-m0')), findsNothing);
  });

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

    controller.replace(_turn('m29', fromUser: false, text: '0123456789'));
    await tester.pumpAndSettle();

    expect(topOf(tester, anchorId), moreOrLessEquals(before, epsilon: 0.5));
  });

  testWidgets('往表头补历史不移动画面', (tester) async {
    seed(20);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();

    final anchorId = ['m15', 'm12', 'm10', 'm8'].firstWhere(
      (id) => find.byKey(ValueKey<String>('box-$id')).evaluate().isNotEmpty,
    );
    final before = topOf(tester, anchorId);

    controller.batch(() {
      for (var i = 0; i < 10; i++) {
        controller.insertAt(0, _turn('older$i', fromUser: true));
      }
    });
    await tester.pumpAndSettle();

    expect(topOf(tester, anchorId), moreOrLessEquals(before, epsilon: 0.5));
  });

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

  testWidgets('恢复会话后慢速下滑能真的滑动，不被弹回底部', (tester) async {
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

  testWidgets('贴底时流式长高，位置在同一帧跟到新底部（不慢一帧再抽回）', (tester) async {
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
    expect(
      position.maxScrollExtent - position.pixels,
      moreOrLessEquals(0, epsilon: 0.5),
      reason: '前提：开局就精确贴底',
    );

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

  testWidgets('内容不足一屏时从顶部往下排，且不可滚动', (tester) async {
    seed(3);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(topInList(tester, 'm1'), moreOrLessEquals(60, epsilon: 0.5));
    expect(topInList(tester, 'm2'), moreOrLessEquals(112, epsilon: 0.5));
    expect(listKey.currentState!.contentFitsViewport, isTrue);
    expect(scroll.position.maxScrollExtent, moreOrLessEquals(0, epsilon: 0.5));
  });

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

    controller.updateStreaming(
      (controller.items.last as AssistantTurn).copyWith(text: 'aaa'),
    );
    await tester.pump();
    expect(topInList(tester, streamingId), moreOrLessEquals(60, epsilon: 0.5));

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

  testWidgets('空会话聊长之后，滑到顶不留空档', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    for (var i = 0; i < 20; i++) {
      controller.add(_turn('m$i', fromUser: i.isEven));
      await tester.pumpAndSettle();
    }

    expect(scroll.position.maxScrollExtent, greaterThan(0), reason: '已经超过一屏');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 100));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();

    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('贴底时挪中心项，画面不动', (tester) async {
    seed(10);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isFalse);

    final before = topOf(tester, 'm9');
    controller.add(_turn('m10', fromUser: true));
    await tester.pump();

    expect(topOf(tester, 'm9'), moreOrLessEquals(before - 52, epsilon: 0.5));
    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );

    controller.add(_turn('m11', fromUser: false));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 100));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
  });

  testWidgets('流式那条不会被挪成中心项', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpAndSettle();
    final state = listKey.currentState!;
    expect(state.centerIndex, greaterThanOrEqualTo(1));

    controller.batch(() {
      controller.replace((controller.items.last as AssistantTurn).settled);
      controller.endStreaming();
    });
    await tester.pumpAndSettle();
    expect(state.centerIndex, greaterThanOrEqualTo(1));
  });

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

    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    expect(scroll.position.pixels, lessThan(mid - 50), reason: '手势被补跳杀掉了');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('换分支与挪中心项不重建还在视口里的条目', (tester) async {
    final log = <String>[];
    seed(3);
    await tester.pumpWidget(host(probeLog: log));
    await tester.pumpAndSettle();
    expect(log, ['m0', 'm1', 'm2'], reason: '不足一屏时从最老一条往下建');

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

    controller.add(_turn('m20', fromUser: true));
    await tester.pumpAndSettle();
    expect(log.where((id) => id == 'm19').length, 1);
    expect(log.where((id) => id == 'm20').length, 1);
  });

  testWidgets('滑动余波里点回到底部仍然生效', (tester) async {
    seed(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 500),
      900,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(scroll.position.activity!.isScrolling, isTrue, reason: '还在惯性里');

    listKey.currentState!.pinToBottom();
    await tester.pumpAndSettle();

    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 1),
    );
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);
  });

  testWidgets('横滑代码块不冻结形态重估', (tester) async {
    final live = ValueNotifier<double>(40);
    addTearDown(live.dispose);
    controller.setAll([
      _turn('m0', fromUser: true),
      _turn('live', fromUser: false),
    ]);
    await tester.pumpWidget(host(liveHeight: live, nestedScroller: true));
    await tester.pumpAndSettle();
    expect(listKey.currentState!.contentFitsViewport, isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('code-m0'))),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();

    live.value = 640;
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      listKey.currentState!.contentFitsViewport,
      isFalse,
      reason: '横滑代码块不该冻结整个列表的形态重估',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  String variedText(int i) => 'x' * (1 + (i * 7) % 10);

  void seedVaried(int count) {
    controller.batch(() {
      for (var i = 0; i < count; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven, text: variedText(i)));
      }
    });
  }

  testWidgets('边界精确后跳到顶部一步落在第一条上沿', (tester) async {
    seedVaried(40);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 200));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.minScrollExtent);
    await tester.pump();

    expect(topInList(tester, 'm0'), moreOrLessEquals(8, epsilon: 0.5));
    expect(scroll.position.pixels, scroll.position.minScrollExtent);
  });

  testWidgets('中心那条被删掉，视口里的幸存者都不动', (tester) async {
    seedVaried(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();

    final state = listKey.currentState!;
    final centerId = 'm${29 - state.centerIndex}';
    final before = <String, double>{
      for (var i = 0; i < 30; i++)
        if ('m$i' != centerId &&
            find.byKey(ValueKey<String>('box-m$i')).evaluate().isNotEmpty)
          'm$i': topOf(tester, 'm$i'),
    };
    expect(before, isNotEmpty);

    controller.removeWhere((e) => e.id == centerId);
    await tester.pump();

    for (final entry in before.entries) {
      final finder = find.byKey(ValueKey<String>('box-${entry.key}'));
      if (finder.evaluate().isEmpty) continue;
      expect(
        topOf(tester, entry.key),
        moreOrLessEquals(entry.value, epsilon: 0.5),
        reason: '${entry.key} 被删中心项带着跳了',
      );
    }
  });

  testWidgets('贴底跟随时 forward 组不会无限攒', (tester) async {
    seed(5);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    for (var i = 5; i < 70; i++) {
      controller.add(_turn('m$i', fromUser: i.isEven));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(listKey.currentState!.centerIndex, lessThan(45));
    expect(
      scroll.position.pixels,
      moreOrLessEquals(scroll.position.maxScrollExtent, epsilon: 0.5),
    );
    expect(find.byKey(const ValueKey<String>('box-m69')), findsOneWidget);
  });

  testWidgets('停在会话开头附近：第一条已 build 但在视口顶之上，松手不跳', (tester) async {
    seedVaried(30);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(listKey.currentState!.following, isFalse);
    final centerBefore = listKey.currentState!.centerIndex;
    expect(centerBefore, isNot(29));

    double topAny(String id) =>
        tester
            .getTopLeft(
              find.byKey(ValueKey<String>('box-$id'), skipOffstage: false),
            )
            .dy -
        tester.getTopLeft(find.byType(AssistantChatList)).dy;

    scroll.jumpTo(scroll.position.minScrollExtent + 20);
    await tester.pump();
    expect(topAny('m0'), moreOrLessEquals(-12, epsilon: 0.5));
    final m1Before = topAny('m1');

    await tester.pumpAndSettle();
    expect(listKey.currentState!.centerIndex, 29, reason: '中心该退到最老一条');
    expect(scroll.position.minScrollExtent, 0);
    expect(topAny('m1'), moreOrLessEquals(m1Before, epsilon: 0.5));
    expect(topAny('m0'), moreOrLessEquals(-12, epsilon: 0.5));
  });

  testWidgets('重新生成删掉撑满视口的中心项：一帧都不露空白，也不整会话重建', (tester) async {
    controller.batch(() {
      for (var i = 0; i < 60; i++) {
        controller.add(_turn('m$i', fromUser: i.isEven));
      }
      controller.add(_turn('tall', fromUser: false, text: 'x' * 20));
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(bottomInList(tester, 'tall'), moreOrLessEquals(508, epsilon: 0.5));
    expect(listKey.currentState!.centerIndex, 0, reason: '长回复自己就是中心项');
    final baseline = Map<String, int>.of(builds);

    controller.remove(_turn('tall', fromUser: false));
    await tester.pump();

    // 600 - 80 底部留白 - 12 条目间距
    expect(
      bottomInList(tester, 'm59'),
      moreOrLessEquals(508, epsilon: 0.5),
      reason: '删掉之后底部仍然贴着视口底',
    );
    final rebuilt = builds.entries
        .where((e) => e.value > (baseline[e.key] ?? 0))
        .length;
    expect(rebuilt, lessThan(20), reason: '只该建视口+缓存那一段，不是整会话 60 条');
    await tester.pumpAndSettle();
    expect(bottomInList(tester, 'm59'), moreOrLessEquals(508, epsilon: 0.5));
    expect(find.byKey(const ValueKey<String>('box-m0')), findsNothing);
  });

  testWidgets('键盘收起视口变高：forward 组撑不满时把上方内容拉下来，不露空白', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final viewport = ValueNotifier<double>(600);
    addTearDown(viewport.dispose);
    seed(30);
    await tester.pumpWidget(host(viewport: viewport));
    await tester.pumpAndSettle();
    expect(bottomInList(tester, 'm29'), moreOrLessEquals(508, epsilon: 0.5));

    viewport.value = 900;
    await tester.pump();
    expect(
      bottomInList(tester, 'm29'),
      moreOrLessEquals(808, epsilon: 0.5),
      reason: '视口变高的那一帧底部就该贴着',
    );
    await tester.pumpAndSettle();
    expect(bottomInList(tester, 'm29'), moreOrLessEquals(808, epsilon: 0.5));
    expect(listKey.currentState!.following, isTrue);
    expect(find.byKey(const ValueKey('to-bottom')), findsNothing);
  });

  testWidgets('流式期间不离屏量高度，定稿后再补', (tester) async {
    seedVaried(40);
    controller.beginStreaming(
      AssistantTurn.assistant('', streaming: true).copyWith(text: 'a'),
    );
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    final state = listKey.currentState!;
    final duringStream = state.measuredCount;
    expect(duringStream, lessThan(40));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(state.measuredCount, duringStream, reason: '流式中只记屏上的，不离屏量');

    final live = controller.streaming.value!;
    controller.replace(live.copyWith(streaming: false, text: 'done'));
    controller.endStreaming();
    await tester.pumpAndSettle();
    expect(state.measuredCount, 41);
  });
}
