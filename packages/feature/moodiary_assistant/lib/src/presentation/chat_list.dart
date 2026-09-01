import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
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

/// 贴底判定的容差（[_StickToBottomScrollPhysics] 用）。**必须比 [_kBottomSlack] 紧得多**：
/// 跟随时的位置是 `jumpTo(max)` 来的、精确等于 max，而思考块展开的第一帧就会
/// 把位置往回推几十像素 —— 容差一松，物理就会把那次补偿又拽回底部。
const double _kStickEpsilon = 0.5;

/// 初始分支按条数猜：超过这个数就直接从双向分支开局。
///
/// shrinkWrap 会把全部条目一帧建完，载入长会话时那一帧要重跑几百遍 Markdown
/// 解析。阈值按「单条最矮 ≈ 42（一行提示 30 + 行距 12）× 手机竖屏视口」取；
/// 猜错方向（大平板上这么多条其实装得下）也只是首帧走错分支，post-frame
/// 量完真高度就换回来。
const int _kShrinkWrapProbe = 24;

/// 列表的滚动物理。**整个生命周期只有这一个实例**：换了实例（哪怕换成
/// `NeverScrollableScrollPhysics`）Scrollable 就会重建 ScrollPosition，
/// 分支切换那一帧位置得靠 absorb 转世 —— 行为全挂在几个回调上，
/// 实例不变，position 就跨分支存活，切换帧的位置修正在同一帧里生效。
///
/// 三个回调：
///
/// - [allowUserScrolling]：顶对齐分支不可滚动 —— 挡的是**手势**，不挡 `jumpTo`，
///   也不影响条目上的点击。
/// - [snapToBottomNow]：分支切换的那一帧无条件落到新的 `max`。切换前后两套
///   坐标系没有可比性，「原本贴不贴底」说明不了什么 —— 切换前的可见画面就是
///   贴底的（顶对齐分支盖过一屏的那一帧是反向列表，pixels 0 恰好露出最新一条）。
/// - [shouldStick]：内容长高时**在同一帧里**把位置带到新的底部。
///
/// 不这么做就只能事后追：流式每长高一次发一条 `ScrollMetricsNotification`，
/// 监听里 `await endOfFrame` 再 `jumpTo` —— 补偿永远慢一帧，于是每个 token 都是
/// 「先露出半行、下一帧再抽回去」。逐 token 累积起来就是肉眼的抖动。
/// `adjustPositionForNewDimensions` 是布局阶段的钩子（`applyContentDimensions`
/// 里调），返回值直接就是这一帧的 pixels，没有中间态可看，所以是平滑的。
class _StickToBottomScrollPhysics extends AlwaysScrollableScrollPhysics {
  /// 是否还在跟随底部。**必须接到列表的跟随状态上**，不能只看「离底够近」——
  /// 思考块展开的第一帧位置还贴着底，那时若只看距离，物理会把它刚做的补偿
  /// 又拽回底部，两边对着拉就是肉眼的一闪。`releaseFollow()` 关掉跟随，这里
  /// 随之停手。
  final ValueGetter<bool> shouldStick;

  final ValueGetter<bool> userScrollingEnabled;
  final ValueGetter<bool> snapToBottomNow;

  const _StickToBottomScrollPhysics({
    required this.shouldStick,
    required this.userScrollingEnabled,
    required this.snapToBottomNow,
    super.parent,
  });

  @override
  _StickToBottomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _StickToBottomScrollPhysics(
      shouldStick: shouldStick,
      userScrollingEnabled: userScrollingEnabled,
      snapToBottomNow: snapToBottomNow,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool get allowUserScrolling => userScrollingEnabled();

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (snapToBottomNow()) return newPosition.maxScrollExtent;
    // 顶对齐形态：位置只有 0 一个合法去处（从双向形态带过来的 pixels 在这里
    // 越界）。**当帧夹死**，不能留给弹道去「滑」回来 —— 那是一段肉眼可见的动画。
    if (!userScrollingEnabled()) {
      return adjusted.clamp(
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
    }
    // 手指在上面、或者还有惯性时一律不插手 —— 那时位置归手势管。
    if (isScrolling || velocity != 0) return adjusted;
    if (!shouldStick()) return adjusted;
    if (!oldPosition.hasPixels || !oldPosition.hasContentDimensions) {
      return adjusted;
    }
    // 只有原本就精确贴着底的才跟。滑走看历史的人不该被新 token 拽回来。
    if (oldPosition.maxScrollExtent - oldPosition.pixels > _kStickEpsilon) {
      return adjusted;
    }
    return newPosition.maxScrollExtent;
  }
}

/// 条目的 key。全局、按（列表实例, id）等值 ——
///
/// - **全局**：条目会在两个 sliver 之间搬家（中心项前移）、也会随分支切换换
///   sliver。GlobalKey 让元素连同状态（展开着的思考块）原地重挂，ValueKey 做不到。
/// - **按 id 等值**：`GlobalObjectKey` 是 `identical` 比较，copyWith 之外换了个
///   字符串实例就丢状态。
/// - **掺上列表实例**：消息 id 在会话内是稳定的，只按 id 的话「pop 会话页的退场
///   动画还没放完就再点开同一个会话」会让两棵活着的列表撞出同一个 GlobalKey。
class _ItemKey extends GlobalKey<State<StatefulWidget>> {
  const _ItemKey(this.list, this.id) : super.constructor();

  final AssistantChatListState list;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is _ItemKey && identical(other.list, list) && other.id == id;

  @override
  int get hashCode => Object.hash(identityHashCode(list), id);
}

/// 自建聊天列表，形状参考 heybox 的 `IMChatList`：**按内容够不够一屏分两个形态**，
/// post-frame 量真实高度切换。
///
/// **不足一屏**：`shrinkWrap + reverse` 且**不可滚动**的列表，整块顶对齐。
/// 短会话从顶往下长，流式回复紧跟在用户消息下面，定稿也不挪窝；没有可滚动
/// 范围，「回到底部」按钮永远不出现。外面那层 `SingleChildScrollView` 只为了
/// iOS 的回弹手感（0.001 的可滚区）。`reverse` 在这里没有正向列表的毛病 ——
/// 列表根本不滚，不存在「最新一条长高推走 scroll offset」的问题；它只负责让
/// 高度盖过一屏的那一帧仍然贴着底显示，切换形态时画面不跳。
///
/// **超过一屏**：**双向布局** —— 一段稳定的「中心项」把内容劈成两半，比它新的
/// 落在正向（中心线下方）、比它旧的落在负向（中心线上方），`anchor: 1` 再把
/// 中心线摆在视口底部。这个形状买到三样东西：
///
/// 1. **开局就在底部，不需要从顶部跳下来。** 普通正向列表载入已有会话时必须
///    `jumpTo(maxScrollExtent)`，而那个 max 是外推估计值 —— 实测 120 条消息要
///    迭代 4 次才收敛（11408 → 44232 → 52506 → 51008），用户看得见它在稳。
/// 2. **滑走看历史时，新消息与流式增长都不动画面。** 它们全在正向那一组，
///    负向那一组的布局偏移一个字节都不变。
/// 3. **往表头补历史不跳。** 更早的消息加进负向那组只会让 `minScrollExtent` 更负，
///    `pixels` 不受影响。
///
/// 两个形态是**同一个** `CustomScrollView`（同一个 GlobalKey、同一个物理实例、
/// 同一个 controller），切的只是 reverse / shrinkWrap / center / slivers ——
/// 于是 ScrollPosition 跨形态存活，切换那一帧物理直接把位置落到新坐标系的底部，
/// 没有「先画一帧错位再补跳」。
///
/// 双向形态**只在内容超过一屏后才启用**，启用时中心项取最新一条已定稿消息，
/// 负向组因此天然不低于一屏 —— 「滑到顶上方一片空白」（`anchor: 1` 的下界是
/// `min(0, 视口高 − 负向组高)`，恒 ≤ 0，拦不住正的「顶边贴顶」位置）只剩
/// 刚切换那一两条消息的窗口期，[_advanceCenter] 在贴底时把中心项跟上最新一条，
/// 窗口随下一条消息闭合。
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
  /// 那一个 `CustomScrollView`。顶对齐形态拿它量真实高度。
  final _listKey = GlobalKey();

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

  /// 当前在不可滚动的顶对齐形态。真源是 post-frame 的实测高度
  /// （[_scheduleBranchCheck]），条数只用来猜初始值。
  bool _isShrinkWrap = true;

  double _viewportMainExtent = 0;
  bool _branchCheckScheduled = false;

  /// 刚切完形态的那一帧：物理无条件把位置落到新坐标系的 `max`。
  bool _flipSnapPending = false;

  /// 是否跟随底部。列表本身不因它重建 —— 只有那颗按钮听它。
  final ValueNotifier<bool> _following = ValueNotifier(true);

  /// 在飞的补跳的代次。用户抓住列表、或来了新一轮发送，都靠它作废旧循环。
  int _pinGeneration = 0;

  /// 补跳进行中：期间所有滚动通知都是我们自己造的，不能拿去改跟随状态。
  bool _pinning = false;

  /// 手指正按在列表上（含随后的惯性滑行）。
  ///
  /// **期间一律不补跳、不换形态。** 内容尺寸会随着老消息 materialize 不断被重估，
  /// 于是拖动的每一帧都伴随一条 `ScrollMetricsNotification`；如果那时
  /// `_following` 还没翻成 false（从底部开始的头几像素就是如此），补跳循环就会
  /// 启动、把 `_pinning` 置真，而 `_pinning` 又会让后续的拖动更新被忽略 ——
  /// `_following` 从此翻不过来，列表被连着拽回底部十来帧。
  /// 症状就是「慢慢滑滑不动、用力甩几次才行」。
  bool _userDragging = false;

  int _lastTailRevision = -1;

  /// 内容还不足一屏。思考块拿它决定「展开要不要补偿视口」——
  /// 顶部对齐时块本来就是往下长的，补偿反而会把它自己推走。
  bool get contentFitsViewport => _isShrinkWrap;

  late final _physics = _StickToBottomScrollPhysics(
    shouldStick: () => !_isShrinkWrap && _following.value,
    userScrollingEnabled: () => !_isShrinkWrap,
    snapToBottomNow: () => _flipSnapPending,
  );

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _rebuildIndex();
    _isShrinkWrap = _newestFirst.length <= _kShrinkWrapProbe;
    _centerId = _pickCenter();
    _lastTailRevision = widget.controller.tailRevision;
    widget.controller.addListener(_onItemsChanged);
    // 后台期间 framesEnabled 为假，endOfFrame 会一直挂着；而回到前台时既没有
    // 列表变化也没有流式变化，两个常规触发点都不会响。所以补一个。
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_following.value) _pinToBottom();
      },
    );
    // 开局的 position 是全新的（没有旧尺寸可比），物理钩子不会响 ——
    // 只能事后跳。这一跳只有 bottomPadding 那么远，且在第一帧。
    if (!_isShrinkWrap) _pinToBottom();
  }

  @override
  void didUpdateWidget(covariant AssistantChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onItemsChanged);
      widget.controller.addListener(_onItemsChanged);
      _lastTailRevision = widget.controller.tailRevision;
      _rebuildIndex();
      _isShrinkWrap = _newestFirst.length <= _kShrinkWrapProbe;
      _centerId = _pickCenter();
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

  /// 双向形态的中心项：最新一条**已定稿**的消息。
  ///
  /// 流式那条正在长个儿，钉它当中心会让它的思考块换一套补偿算法；
  /// 只有它一条时才退而钉它。
  String? _pickCenter() {
    for (final item in _newestFirst) {
      if (item is AssistantTurn && item.streaming) continue;
      return item.id;
    }
    return _newestFirst.isEmpty ? null : _newestFirst.first.id;
  }

  /// 切进双向形态。调用方负责 setState。
  ///
  /// [snapToBottomNow] 让切换那一帧直接落到新坐标系的 `max`；post-frame 再兜一跳，
  /// 防的是「这一帧尺寸恰好没变、物理钩子没被问到」的万一。
  void _enterBidirectional() {
    _isShrinkWrap = false;
    _centerId = _pickCenter();
    _flipSnapPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flipSnapPending = false;
      if (!mounted || _isShrinkWrap) return;
      final position = _position;
      if (position == null || !position.hasContentDimensions) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    });
  }

  /// 切进顶对齐形态。调用方负责 setState。底部本来就看得见了：
  /// 作废在飞的补跳、跟随置回真（按钮由形态一起决定，见 build）。
  void _enterShrinkWrap() {
    _isShrinkWrap = true;
    _pinGeneration++;
    _pinning = false;
    _following.value = true;
  }

  void _onItemsChanged() {
    final previous = _newestFirst;
    _rebuildIndex();
    // 整表换血（切会话的 setAll）：老的中心项、老的形态都作废，按新会话重来。
    // 不等 post-frame 量高度 —— 长会话不能让 shrinkWrap 把几百条一帧建完，
    // 短会话也不该先画一帧贴底再跳成顶对齐。any 在正常更新里第一条就命中。
    final wholesale =
        previous.isNotEmpty &&
        !previous.any((e) => _indexById.containsKey(e.id));
    if (wholesale) {
      if (_newestFirst.length <= _kShrinkWrapProbe) {
        _enterShrinkWrap();
      } else {
        _enterBidirectional();
        _following.value = true;
      }
    } else if (_isShrinkWrap) {
      // 同会话涨过条数上限（恢复历史等）也直接换，理由同上。
      if (_newestFirst.length > _kShrinkWrapProbe) _enterBidirectional();
    } else {
      _syncCenter(previous);
      _advanceCenter();
    }

    final tail = widget.controller.tailRevision;
    final tailChanged = tail != _lastTailRevision;
    _lastTailRevision = tail;
    if (mounted) setState(() {});
    // 只有尾部变化才重新钉底。中插（压缩提示 chip 落在水位消息之后）不算 ——
    // 它恰好在一轮结束时触发，正是用户翻历史的时刻。拖动中也不钉：
    // jumpTo 会把正在进行的手势连根拔掉。
    if (tailChanged && _following.value && !_userDragging) _pinToBottom();
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
    _centerId = _pickCenter();
  }

  /// 贴底时把中心项挪到最新一条已定稿的消息上。
  ///
  /// **为什么要挪。** 双向形态启用那一刻内容才刚过一屏，负向组（含 [_kTopPadding]）
  /// 还差一段 `bottomPadding` 才够一屏 —— `anchor: 1` 给出的滚动下界是
  /// `min(0, 视口高 − 负向组高)`，恒 ≤ 0，而「对话顶边正好贴住视口顶」对应的是个
  /// 正偏移，中间那段没人拦：滑到对话开头之后还能继续拖出一片空白，松手也不回弹
  /// （那是合法位置，不是 overscroll）。中心项一直跟着最新一条走，负向组就随
  /// 会话一起长，窗口在下一两条消息内闭合，此后 `min` 恒为负。
  ///
  /// **为什么挪得动。** 只在**精确贴底**时挪。把 k 条从正向搬进负向，`max` 正好
  /// 少掉这 k 条的高度，而 `pixels` 本来就等于 `max` —— 同一趟布局里
  /// `applyContentDimensions` 会把它夹到新的 `max`（贴底物理也给同一个答案），
  /// 位移自相抵，画面一动不动。滑在历史里的用户一次都碰不到这条路径，
  /// [_syncCenter] 那句「中心项一变，负向组的布局偏移会整体重算」因此不受影响。
  ///
  /// 流式那条跳过，理由同 [_pickCenter]；等它定稿，收尾那次通知自然会把它收进来。
  void _advanceCenter() {
    if (!_following.value || _userDragging) return;
    final position = _position;
    if (position == null || !position.hasContentDimensions) return;
    if (position.maxScrollExtent - position.pixels > _kStickEpsilon) return;
    final target = _pickCenter();
    if (target != null && target != _centerId) _centerId = target;
  }

  /// 主动放弃跟随底部。
  ///
  /// 给那些用 `correctPixels` 静默改位置的子组件用 —— 那种改动不发滚动通知，
  /// 列表自己看不见，下一条 metrics 通知就会把人拽回底部。顶对齐形态里同样要放：
  /// 展开的块可能把内容顶过一屏，切进双向形态之后贴底物理只认这里的状态。
  ///
  /// **改完位置、布局落定之后要配一次 [syncFollowFromPosition]**，否则跟随状态
  /// 会一直卡在 false：收起思考块明明已经回到底部了，「回到底部」按钮还挂着。
  void releaseFollow() {
    _pinGeneration++;
    _pinning = false;
    _following.value = false;
  }

  /// [itemContext] 那一条是不是落在中心线**下方**（正向组）。
  ///
  /// 正向组是往下长的：长高只把它下面的内容顶远，视口里已有的东西一动不动，
  /// 所以不需要（也不该）补偿。负向组才是往上长、需要把视口跟着推。
  ///
  /// 不走 id 而是问渲染树：中心那个 sliver 是不是自己的祖先。这样思考块不必
  /// 知道自己属于哪条消息，中间那两层气泡组件也不用替它传。
  bool isInForwardGroup(BuildContext itemContext) {
    final center = _centerKey.currentContext?.findRenderObject();
    if (center == null) return false;
    RenderObject? node = itemContext.findRenderObject();
    while (node != null) {
      if (identical(node, center)) return true;
      node = node.parent;
    }
    return false;
  }

  /// 按当前真实位置重新判断跟随状态。
  ///
  /// 同样是给静默改位置的路径用的 —— 它们不发 `ScrollUpdateNotification`，
  /// 常规那条「拖动时重新判断」的路走不到。顺手排一次形态检查：
  /// 收起思考块把内容缩回一屏之内时，min 被 0 夹着、max 又没动，
  /// 连 `ScrollMetricsNotification` 都不会发 —— 这里是唯一的触发点。
  void syncFollowFromPosition() {
    _scheduleBranchCheck();
    if (_isShrinkWrap) {
      _following.value = true;
      return;
    }
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
    if (_isShrinkWrap) return;
    final generation = ++_pinGeneration;
    _pinning = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _pinGeneration) return;
      if (_isShrinkWrap || _userDragging) return;
      final position = _position;
      if (position == null) return;
      if ((position.maxScrollExtent - position.pixels).abs() < 1) return;
      position.jumpTo(position.maxScrollExtent);
    } finally {
      if (generation == _pinGeneration) _pinning = false;
    }
  }

  // ── 形态切换 ─────────────────────────────────────────────────

  /// post-frame 量真实高度，该换形态就换。参考 IMChatList 的
  /// `_scheduleShrinkWrapCheck`：**两个形态量的是同一份内容**（消息 + 上下留白），
  /// 阈值不会在两边打架来回震荡。
  void _scheduleBranchCheck() {
    if (_branchCheckScheduled) return;
    _branchCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _branchCheckScheduled = false;
      if (!mounted) return;
      // 手指按着时不换形态 —— 换树会把正在进行的手势连根拔掉。松手的
      // ScrollEndNotification 会再排一次。
      if (_userDragging) return;
      final exceeds = _contentExceedsViewport();
      if (exceeds == null || exceeds != _isShrinkWrap) return;
      setState(() {
        if (exceeds) {
          _enterBidirectional();
        } else {
          _enterShrinkWrap();
        }
      });
    });
    // post-frame 回调自己不请求帧。从帧外排进来（metrics 微任务、收起动画的
    // 收尾回调）时若没人再画下一帧，检查就一直挂着 —— 踢一脚。帧内调用不踢，
    // 不然每帧排检查会让引擎永远闲不下来。
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool? _contentExceedsViewport() {
    if (_viewportMainExtent <= 0) return null;
    if (_isShrinkWrap) {
      final box = _listKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return null;
      // 列表被 maxHeight + 0.001 封了顶，够到顶就说明内容盖过了一屏。
      return box.size.height >= _viewportMainExtent + 0.0005;
    }
    final total = _totalSliverExtent();
    if (total == null) return null;
    return total > _viewportMainExtent;
  }

  double? _totalSliverExtent() {
    RenderObject? node = _centerKey.currentContext?.findRenderObject();
    while (node != null && node is! RenderViewport) {
      node = node.parent;
    }
    if (node is! RenderViewport) return null;
    var total = 0.0;
    for (
      var sliver = node.firstChild;
      sliver != null;
      sliver = node.childAfter(sliver)
    ) {
      final geometry = sliver.geometry;
      if (geometry == null) return null;
      total += geometry.scrollExtent;
    }
    return total;
  }

  bool _onScrollNotification(Notification notification) {
    // 拖动的起止两个形态都要记：顶对齐形态的外层回弹也是手势，
    // 期间照样不能换形态。跟随状态只在双向形态里有意义。
    if (notification is ScrollStartNotification) {
      // dragDetails 非空 == 用户真的把手指按在了列表上。只有 DragScrollActivity
      // 会填它，我们自己的 jumpTo / 弹道 / driven 一律为 null，所以这是干净的分界。
      if (notification.dragDetails != null) {
        _userDragging = true;
        // 作废在飞的补跳，手势归手指。
        _pinGeneration++;
        _pinning = false;
        if (!_isShrinkWrap) {
          _following.value = (_distanceToBottom ?? 0) <= _kBottomSlack;
        }
      }
      return false;
    }

    if (notification is ScrollEndNotification) {
      final wasUserScroll = _userDragging;
      _userDragging = false;
      // 只有**用户驱动**的滚动结束才重推跟随状态。形态切换落位、夹取回弹这类
      // 程序性活动也发同一种通知，若拿它们的落点（往往恰好是底部）重推，
      // releaseFollow 刚放弃的跟随会被原地复活，贴底物理跟着把思考块的补偿
      // 拽回去 —— 两边对着拉。
      if (!_isShrinkWrap && wasUserScroll) {
        final distance = _distanceToBottom;
        if (distance != null) _following.value = distance <= _kBottomSlack;
      }
      _scheduleBranchCheck();
      return false;
    }

    // 顶对齐形态不可滚动，剩下的通知不携带任何信息 —— 尤其不能拿去翻跟随
    // 状态，那会让「回到底部」按钮凭空冒出来。
    if (_isShrinkWrap) return false;

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
      _scheduleBranchCheck();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      // 同 ScrollEnd：只认用户驱动的滚动（拖动与随后的惯性），程序性的
      // jumpTo / 落位修正不算数。
      if (_pinning || !_userDragging) return false;
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
      key: _ItemKey(this, item.id),
      child: Padding(
        padding: const .fromLTRB(16, 0, 16, _kItemGap),
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

  int? _findShrink(Key key) => _indexById[(key as _ItemKey).id];

  int? _findBeforeCenter(Key key) {
    final index = _indexById[(key as _ItemKey).id];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= center ? index - center : null;
  }

  int? _findCenter(Key key) {
    final index = _indexById[(key as _ItemKey).id];
    if (index == null) return null;
    final center = _centerIndex;
    return index >= 0 && index < center ? center - index - 1 : null;
  }

  /// 那一个 `CustomScrollView`，按形态给不同的参数。
  ///
  /// 顶对齐形态：`reverse + shrinkWrap` 的列表整块顶对齐、不可滚动（挡在物理的
  /// `allowUserScrolling`，不用 `NeverScrollableScrollPhysics` —— 换物理实例
  /// 会重建 ScrollPosition，切形态那一帧就没法在同一帧落位）。高度封在
  /// `maxHeight + 0.001`：内容装得下时列表收缩成内容高、贴着顶；内容盖过一屏的
  /// 那一帧（形态还没来得及切）反向列表恰好反过来贴着底 —— pixels 为 0 露出的
  /// 就是最新一条，于是切换前后画面是连续的。
  ///
  /// **包裹结构在两个形态下一个字都不变**（外层 `SingleChildScrollView` 到
  /// `SizeChangedLayoutNotifier` 恒在），只换 CustomScrollView 的参数。变了就是
  /// GlobalKey 重挂，重挂触发 Scrollable 的 `didChangeDependencies` →
  /// `_updatePosition()` 重建 position —— 而 `absorb` 不带 `haveDimensions`，
  /// 新 position 的第一次 `applyContentDimensions` 会跳过物理修正，切换那一帧
  /// 就会以旧偏移画出一帧错位。外层 SCSV 在双向形态里只多出 0.001 的可滚区，
  /// 手势竞技场里输给里层，等于不存在；顶对齐形态里层不收手势，它才接住回弹。
  Widget _buildList(BoxConstraints constraints) {
    final center = _centerIndex;
    final total = _newestFirst.length;
    return SingleChildScrollView(
      primary: false,
      child: Container(
        alignment: .topCenter,
        height: constraints.maxHeight + 0.001,
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            // 流式长高、思考块展开都不重建列表本身，得靠尺寸变化自己报信。
            _scheduleBranchCheck();
            return true;
          },
          child: SizeChangedLayoutNotifier(
            child: CustomScrollView(
              key: _listKey,
              controller: widget.scrollController,
              physics: _physics,
              reverse: _isShrinkWrap,
              shrinkWrap: _isShrinkWrap,
              center: _isShrinkWrap ? null : _centerKey,
              anchor: _isShrinkWrap ? 0 : 1,
              slivers: _isShrinkWrap
                  ? [
                      // reverse 布局：列在越前面的离视觉底部越近。
                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.bottomPadding),
                      ),
                      SliverList.builder(
                        itemCount: total,
                        findChildIndexCallback: _findShrink,
                        itemBuilder: _buildItem,
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kTopPadding),
                      ),
                    ]
                  : [
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportMainExtent = constraints.maxHeight;
                    _scheduleBranchCheck();
                    return _buildList(constraints);
                  },
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _following,
            // 顶对齐形态永不显示按钮：底部本来就看得见。
            builder: (context, following, _) => widget.scrollToBottomBuilder(
              context,
              !following && !_isShrinkWrap,
              pinToBottom,
            ),
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
