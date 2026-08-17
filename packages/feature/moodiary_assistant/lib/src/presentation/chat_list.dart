import 'package:moodiary_assistant/src/application/chat_controller.dart';
import 'package:moodiary_assistant/src/application/chat_items.dart';
import 'package:mui/mui.dart';

typedef AssistantItemBuilder = Widget Function(
  BuildContext context,
  AssistantChatItem item,
  int index,
);

/// 判定「已在底部」的容差。**刻意很小**：它只用于重新获得跟随，不用于分类。
///
/// 拿距离当主判据会出事 —— 用户往上拖 40px 想重读上一句，一个几十像素的阈值会
/// 判成「还在底部」，下一个 token 就把他拽回去。掉跟随只认用户驱动的滚动。
const double _kBottomSlack = 8;

const double _kItemGap = 12;
const double _kTopPadding = 8;

/// 自建聊天列表。**双向布局**：一段稳定的「中心项」把内容劈成两半，
/// 比它新的落在正向（中心线下方）、比它旧的落在负向（中心线上方），
/// `anchor: 1` 再把中心线摆在视口底部。
///
/// 这个形状同时买到三样东西，缺一不可：
///
/// 1. **开局就在底部，不需要从顶部跳下来。** 普通正向列表载入已有会话时必须
///    `jumpTo(maxScrollExtent)`，而那个 max 是外推估计值 —— 实测 120 条消息要
///    迭代 4 次才收敛（11408 → 44232 → 52506 → 51008），用户看得见它在稳。
/// 2. **滑走看历史时，新消息与流式增长都不动画面。** 它们全在正向那一组，
///    负向那一组的布局偏移一个字节都不变。这一点与正向列表持平。
/// 3. **往表头补历史不跳。** 更早的消息加进负向那组只会让 `minScrollExtent` 更负，
///    `pixels` 不受影响 —— 分页要的就是这个。正向列表做不到：表头插入会把整个
///    可见区推走。
///
/// **注意不是 `reverse: true`。** 裸反向列表只满足第 1 条：它的 scrollOffset 原点
/// 钉在 index 0 的边上，最新一条长高会把后面每一条的 scroll offset 整体推走 ——
/// 实测最新项 +60px，可见的旧消息就上跑 60px；+400px 时整个可见窗口被换掉。
class AssistantChatList extends StatefulWidget {
  /// 时间序（最旧在前）。列表内部自己翻成最新在前。
  final AssistantChatController controller;

  final AssistantItemBuilder itemBuilder;
  final ScrollController scrollController;

  /// 悬浮输入面板留出的底部空间。
  final double bottomPadding;

  /// 「回到底部」按钮，由外部提供外观；[visible] 为假时应当自行隐藏。
  final Widget Function(BuildContext context, bool visible, VoidCallback onTap)
  scrollToBottomBuilder;

  /// 手指落在**消息区**上（收键盘 / 收工具面板）。
  ///
  /// 刻意由列表自己挂，而不是让调用方在外面包一层 `Listener`：
  /// `behavior: translucent` 的命中测试无论子节点吃没吃掉事件都会把自己算进去，
  /// 所以包在外面会连输入面板上的点击一起截胡 —— 按下「+」时先把面板设成 none、
  /// 抬手时 `_toggleToolPanel` 看到 none 又打开，工具面板就再也关不掉了。
  final VoidCallback? onPointerDown;

  /// 子树里拿到列表状态。授权卡、思考块这类深处的组件要主动放弃「跟随底部」时用。
  static AssistantChatListState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChatListScope>()?.state;

  const AssistantChatList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.scrollController,
    required this.scrollToBottomBuilder,
    this.bottomPadding = 8,
    this.onPointerDown,
  });

  @override
  State<AssistantChatList> createState() => AssistantChatListState();
}

class AssistantChatListState extends State<AssistantChatList> {
  /// 中心线**上方**那一组：中心项自己，以及比它更旧的。
  final _beforeCenterKey = GlobalKey();

  /// 中心线**下方**那一组：比中心项更新的。新消息与流式增长都长在这里。
  final _centerKey = GlobalKey();

  /// 最新在前。
  List<AssistantChatItem> _newestFirst = const [];
  Map<String, int> _indexById = const {};
  String? _centerId;

  int get _centerIndex {
    final id = _centerId;
    if (id == null) return 0;
    return _indexById[id] ?? 0;
  }

  /// 是否跟随底部。列表本身不因它重建 —— 只有那颗按钮听它。
  final ValueNotifier<bool> _following = ValueNotifier(true);

  /// 在飞的补跳的代次。用户抓住列表、或来了新一轮发送，都靠它作废旧循环。
  int _pinGeneration = 0;

  /// 补跳进行中：期间所有滚动通知都是我们自己造的，不能拿去改跟随状态。
  bool _pinning = false;

  /// 手指正按在列表上（含随后的惯性滑行）。
  ///
  /// **期间一律不补跳。** 内容尺寸会随着老消息 materialize 不断被重估，
  /// 于是拖动的每一帧都伴随一条 `ScrollMetricsNotification`；如果那时
  /// `_following` 还没翻成 false（从底部开始的头几像素就是如此），补跳循环就会
  /// 启动、把 `_pinning` 置真，而 `_pinning` 又会让后续的拖动更新被忽略 ——
  /// `_following` 从此翻不过来，列表被连着拽回底部十来帧。
  /// 症状就是「慢慢滑滑不动、用力甩几次才行」。
  bool _userDragging = false;

  int _lastTailRevision = -1;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
    _centerId = _newestFirst.isEmpty ? null : _newestFirst.first.id;
    _lastTailRevision = widget.controller.tailRevision;
    widget.controller.addListener(_onItemsChanged);
    // 后台期间 framesEnabled 为假，endOfFrame 会一直挂着；而回到前台时既没有
    // 列表变化也没有流式变化，两个常规触发点都不会响。所以补一个。
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_following.value) _pinToBottom();
      },
    );
    // 底部那条留白 sliver 落在正向组里，所以开局 max 等于它的高度。
    // 这一跳只有 bottomPadding 那么远（而不是整段历史那么远），且在第一帧。
    _pinToBottom();
  }

  @override
  void didUpdateWidget(covariant AssistantChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onItemsChanged);
      widget.controller.addListener(_onItemsChanged);
      _lastTailRevision = widget.controller.tailRevision;
      _rebuildIndex();
      _centerId = _newestFirst.isEmpty ? null : _newestFirst.first.id;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onItemsChanged);
    _lifecycle.dispose();
    _following.dispose();
    super.dispose();
  }

  void _rebuildIndex() {
    _newestFirst = widget.controller.items.reversed.toList(growable: false);
    _indexById = {
      for (var i = 0; i < _newestFirst.length; i++) _newestFirst[i].id: i,
    };
  }

  ScrollPosition? get _position => widget.scrollController.hasClients
      ? widget.scrollController.position
      : null;

  double? get _distanceToBottom {
    final position = _position;
    if (position == null) return null;
    return position.maxScrollExtent - position.pixels;
  }

  void _onItemsChanged() {
    final previous = _newestFirst;
    _rebuildIndex();
    _syncCenter(previous);

    final tail = widget.controller.tailRevision;
    final tailChanged = tail != _lastTailRevision;
    _lastTailRevision = tail;
    if (mounted) setState(() {});
    // 只有尾部变化才重新钉底。中插（压缩提示 chip 落在水位消息之后）不算 ——
    // 它恰好在一轮结束时触发，正是用户翻历史的时刻。
    if (tailChanged && _following.value) _pinToBottom();
  }

  /// 维护中心项。
  ///
  /// 中心项还活着就一个字节都别动 —— 它一变，两组的划分就变，负向那组的布局
  /// 偏移会整体重算，滑在历史里的用户会看见画面跳。
  ///
  /// 它被删掉时（「重新回答」删的正是最新的那几条，中心项常在其中），改钉到最近的、
  /// 还活着的**更旧**的一条：负向那组因此原样保留，视口只少掉真正消失的那段高度。
  void _syncCenter(List<AssistantChatItem> previous) {
    if (_newestFirst.isEmpty) {
      _centerId = null;
      return;
    }
    final id = _centerId;
    if (id != null && _indexById.containsKey(id)) return;
    if (id != null) {
      final was = previous.indexWhere((e) => e.id == id);
      if (was >= 0) {
        for (var i = was + 1; i < previous.length; i++) {
          final candidate = previous[i].id;
          if (_indexById.containsKey(candidate)) {
            _centerId = candidate;
            return;
          }
        }
      }
    }
    _centerId = _newestFirst.first.id;
  }

  /// 主动放弃跟随底部。
  ///
  /// 给那些用 `correctPixels` 静默改位置的子组件用 —— 那种改动不发滚动通知，
  /// 列表自己看不见，下一条 metrics 通知就会把人拽回底部。
  ///
  /// **改完位置、布局落定之后要配一次 [syncFollowFromPosition]**，否则跟随状态
  /// 会一直卡在 false：收起思考块明明已经回到底部了，「回到底部」按钮还挂着。
  void releaseFollow() {
    _pinGeneration++;
    _pinning = false;
    _following.value = false;
  }

  /// 按当前真实位置重新判断跟随状态。
  ///
  /// 同样是给静默改位置的路径用的 —— 它们不发 `ScrollUpdateNotification`，
  /// 常规那条「拖动时重新判断」的路走不到。
  void syncFollowFromPosition() {
    final distance = _distanceToBottom;
    if (distance != null) _following.value = distance <= _kBottomSlack;
  }

  /// 无条件回到底部并重新开始跟随。发送、载入会话、点「回到底部」都走它。
  void pinToBottom() {
    _following.value = true;
    _pinToBottom();
  }

  /// 等这一帧布局落定后跳到底。`jumpTo` 不 animate。
  ///
  /// **只跳一次，不迭代。** 迭代收敛是正向列表才需要的：那种布局载入会话时要从顶部
  /// 跳到底，而 `maxScrollExtent` 在末项没 materialize 时只是「已布局子项平均高 ×
  /// 剩余条数」的外推值，实测 120 条消息要跳四次才稳。中心 sliver 布局下我们永远从
  /// 底部附近出发、末项一直是活的，`max` 就是真值。
  ///
  /// 代次守卫仍然要：这一跳排在下一帧，期间用户可能已经把手指按上来了。
  Future<void> _pinToBottom() async {
    final generation = ++_pinGeneration;
    _pinning = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _pinGeneration) return;
      final position = _position;
      if (position == null) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    } finally {
      if (generation == _pinGeneration) _pinning = false;
    }
  }

  bool _onScrollNotification(Notification notification) {
    if (notification is ScrollStartNotification) {
      // dragDetails 非空 == 用户真的把手指按在了列表上。只有 DragScrollActivity
      // 会填它，我们自己的 jumpTo / 弹道 / driven 一律为 null，所以这是干净的分界。
      if (notification.dragDetails != null) {
        _userDragging = true;
        // 作废在飞的补跳，手势归手指。
        _pinGeneration++;
        _pinning = false;
        _following.value = (_distanceToBottom ?? 0) <= _kBottomSlack;
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      _userDragging = false;
      final distance = _distanceToBottom;
      if (distance != null) _following.value = distance <= _kBottomSlack;
      return false;
    }

    if (notification is ScrollMetricsNotification) {
      // 手指在上面时绝不插手 —— 见 [_userDragging]。
      if (_userDragging) return false;
      // 视口或内容尺寸变了：流式长高、尾部插入、键盘弹起、工具面板展开、
      // 输入框长到多行、横幅出现、旋转。
      //
      // 这些**都不会**触发 ScrollController 的监听（pixels 没变），而视口变矮会让
      // max 变大、pixels 不动 —— 「在底部」就这么被静默丢掉。而且键盘不是一次
      // 事件而是一段 200ms 的 AnimatedSize 斜坡，所以要每一帧都补，不能只补一次。
      if (_following.value && !_pinning) _pinToBottom();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      if (_pinning) return false;
      final distance = _distanceToBottom;
      if (distance != null) _following.value = distance <= _kBottomSlack;
    }
    return false;
  }

  /// 两组共用的条目构建。[index] 是**最新在前**的下标。
  Widget _buildItem(BuildContext context, int index) {
    final item = _newestFirst[index];
    // 时间序下标交给调用方，它那边的「是不是最后一条」还是按时间序想的。
    final chronological = _newestFirst.length - 1 - index;
    return KeyedSubtree(
      key: ValueKey<String>(item.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, _kItemGap),
        child: item is AssistantTurn && item.streaming
            // 流式那一条单独订阅：一个 token 只重建这一个气泡，
            // 而不是让每个可见气泡都重跑一遍 Markdown 解析。
            ? ValueListenableBuilder<AssistantTurn?>(
                valueListenable: widget.controller.streaming,
                builder: (context, live, _) => _align(
                  context,
                  live != null && live.id == item.id ? live : item,
                  chronological,
                ),
              )
            : _align(context, item, chronological),
      ),
    );
  }

  /// 左右对齐与「气泡最宽 82%」都靠这一层。
  ///
  /// **不能省**：sliver 子项拿到的是**紧**的横向约束，`BoxConstraints.enforce`
  /// 会把子级的 `maxWidth` 静默丢掉。文本气泡因为自己 Column 设了
  /// crossAxisAlignment 而侥幸不出事，授权卡和压缩 chip 会直接拉满全宽。
  Widget _align(BuildContext context, AssistantChatItem item, int index) {
    final fromUser = item is AssistantTurn && item.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: widget.itemBuilder(context, item, index),
    );
  }

  int? _findBeforeCenter(Key key) {
    final index = _indexById[(key as ValueKey<String>).value];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= center ? index - center : null;
  }

  int? _findCenter(Key key) {
    final index = _indexById[(key as ValueKey<String>).value];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= 0 && index < center ? center - index - 1 : null;
  }

  @override
  Widget build(BuildContext context) {
    final center = _centerIndex;
    final total = _newestFirst.length;
    return _ChatListScope(
      state: this,
      child: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => widget.onPointerDown?.call(),
              child: NotificationListener<Notification>(
                onNotification: _onScrollNotification,
                child: CustomScrollView(
                  controller: widget.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // 中心线摆在视口底部，最新一条的下边缘就落在那里 —— 开局即底部。
                  center: _centerKey,
                  anchor: 1,
                  slivers: [
                    // 负向组：列在越前面的离中心线越远（也就是越靠上）。
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _kTopPadding),
                    ),
                    SliverList.builder(
                      key: _beforeCenterKey,
                      itemCount: (total - center).clamp(0, total),
                      findChildIndexCallback: _findBeforeCenter,
                      itemBuilder: (context, i) =>
                          _buildItem(context, center + i),
                    ),
                    // ↓ 中心线 ↓ 正向组：比中心项更新的，越靠后越新。
                    SliverList.builder(
                      key: _centerKey,
                      itemCount: center,
                      findChildIndexCallback: _findCenter,
                      itemBuilder: (context, i) =>
                          _buildItem(context, center - i - 1),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: widget.bottomPadding),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _following,
            builder: (context, following, _) =>
                widget.scrollToBottomBuilder(context, !following, pinToBottom),
          ),
        ],
      ),
    );
  }
}

class _ChatListScope extends InheritedWidget {
  const _ChatListScope({required this.state, required super.child});

  final AssistantChatListState state;

  @override
  bool updateShouldNotify(_ChatListScope oldWidget) =>
      !identical(state, oldWidget.state);
}
