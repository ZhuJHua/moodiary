/// 助手对话里的**过程提示**：思考、工具调用、上下文压缩……全部走这一个组件。
///
/// 形状是一行：`图标 · 类型 · 一行摘要 · 箭头`。**没有容器**——助手正文已经不带
/// 气泡了，过程信息再套个盒子，视觉重量反而压过结论。分层靠颜色：正文是
/// `onSurface`，这里一律 `onSurfaceVariant`。
///
/// 尾部箭头是可展开性的唯一凭据：
///
/// - `⌄` 向下 —— 就地展开（[detail] 非空）
/// - `›` 向右 —— 去别处（[onTap] 非空，比如压缩提示打开弹窗）
/// - 没有箭头 —— 只是一行字，点了也不会有事发生
library;

import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:mui/mui.dart';

/// 展开动画。与滚动补偿共用一条曲线 —— 两者不同步的话，块的顶边会在动画期间飘。
const Duration _kExpandDuration = Duration(milliseconds: 220);

class AssistantNotice extends StatefulWidget {
  /// null 表示「进行中」，画转圈。
  final IconData? icon;

  /// 类型词，加粗。如「思考了 3.2 秒」「查询日记」。
  final String kind;

  /// 一行摘要，超出省略。空串则只显示类型词。
  final String summary;

  /// 展开后的内容。null = 不可展开、不画向下箭头。
  final WidgetBuilder? detail;

  /// [detail] 为空时的点击行为，画向右箭头。
  final VoidCallback? onTap;

  const AssistantNotice({
    super.key,
    this.icon,
    required this.kind,
    this.summary = '',
    this.detail,
    this.onTap,
  });

  @override
  State<AssistantNotice> createState() => _AssistantNoticeState();
}

class _AssistantNoticeState extends State<AssistantNotice>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _kExpandDuration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// 展开后正文要占的高度，每次 [_toggle] 之前离屏量一次。0 表示这次不补偿。
  double _bodyExtent = 0;

  /// 已经补偿掉的高度，用来在动画每一帧只补增量。
  double _compensated = 0;

  ScrollPosition? _position;

  @override
  void initState() {
    super.initState();
    _curve.addListener(_compensateStep);
  }

  @override
  void dispose() {
    _curve
      ..removeListener(_compensateStep)
      ..dispose();
    _anim.dispose();
    super.dispose();
  }

  bool get _expandable => widget.detail != null;

  /// 整块。[measuring] 为真时用于离屏量高度：去掉 [SelectionArea]
  /// （它不占尺寸，却要一个 Overlay 才立得起来）。
  Widget _block(
    BuildContext context, {
    required double factor,
    bool measuring = false,
  }) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final fg = scheme.onSurfaceVariant;

    final Widget leading = widget.icon == null
        ? SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Icon(widget.icon, size: 15, color: fg);

    final row = Padding(
      // 上下各 5：一是把点击区撑到 ~30，二是让这一条和相邻的提示之间有喘息。
      padding: const .symmetric(vertical: 5),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 7),
          Text(
            widget.kind,
            maxLines: 1,
            style: typography.labelMedium.emphasized.onSurfaceVariant,
          ),
          if (widget.summary.isNotEmpty) ...[
            Text(
              ' · ',
              style: typography.labelMedium.onSurfaceVariant.copyWith(
                color: fg.withValues(alpha: 0.5),
              ),
            ),
            // 只有摘要可压缩：类型词与箭头都是定宽的，先让它们占住位。
            Expanded(
              child: Text(
                widget.summary,
                maxLines: 1,
                overflow: .ellipsis,
                style: typography.labelMedium.onSurfaceVariant,
              ),
            ),
          ] else
            const Spacer(),
          if (_expandable)
            // 转 180° 而不是换图标：换图标在动画中途会突然跳一下。
            Transform.rotate(
              angle: factor * 3.141592653589793,
              child: Icon(LucideIcons.chevronDown, size: 16, color: fg),
            )
          else if (widget.onTap != null)
            Icon(LucideIcons.chevronRight, size: 16, color: fg),
        ],
      ),
    );

    Widget? body;
    if (_expandable && factor > 0) {
      body = Padding(
        // 与类型词左对齐（图标 15 + 间隔 7）：展开的内容属于这一条，不是新起一段。
        padding: const .fromLTRB(22, 1, 0, 6),
        child: Builder(builder: widget.detail!),
      );
      if (!measuring) body = SelectionArea(child: body);
      // 宽高一起裁。只裁高的话，正文一进树就按完整宽度参与横轴测量，第一帧宽度
      // 直接弹到最宽 —— 那一下比高度跳还显眼。`Align` 会先用完整约束给子节点
      // 布局、再按 factor 缩自己，所以正文始终按最终宽度排版、中途不重新换行。
      if (factor < 1) {
        body = ClipRect(
          child: Align(
            alignment: .topLeft,
            widthFactor: factor,
            heightFactor: factor,
            child: body,
          ),
        );
      }
    }

    final content = Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [row, ?body],
    );

    // 与下方（正文或下一条提示）之间的间距归组件自己管：它是通用件，不该指望
    // 每个调用点自己补。**在水波之外**，免得点击高亮把这段留白也涂上。
    Widget wrapped = content;
    if (!measuring && (_expandable || widget.onTap != null)) {
      wrapped = MInkWell(
        borderRadius: .circular(8),
        onTap: _expandable ? _toggle : widget.onTap,
        child: content,
      );
    }
    return Padding(
      padding: const .only(bottom: 6),
      child: wrapped,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, _) => _block(context, factor: _curve.value),
  );

  /// 展开 / 收起，并把视口补偿回去，让它**向下**展开。
  ///
  /// 提示条落在中心线**上方**那一组时，那组的条目是从中心线往上累加的 ——
  /// 某条长高时它的下沿不动、上沿往上顶，看起来就是向上展开。补偿把这个抵消掉。
  ///
  /// 高度是渐变的，所以补偿也得逐帧跟：先离屏量出正文的完整高度，动画每一帧按
  /// 进度差值 `correctPixels` 一次。量在重建**之前**做，否则只能「先展开一帧、
  /// 再 post-frame 量完补回来」，中间那一帧就是肉眼看到的闪。
  void _toggle() {
    final expanding = !_expanded;
    _position = Scrollable.maybeOf(context)?.position;
    final before = _topOf();
    // 已经补偿掉的量按当前进度折算 —— 动画中途再点一次时 _compensated 不能清零，
    // 否则反向那几帧会把位置多推一个正文的高度。
    final previous = _bodyExtent;
    _bodyExtent = _canCompensate ? (_measureDelta(context) ?? 0) : 0;
    _compensated = previous <= 0 ? 0 : _curve.value * _bodyExtent;

    setState(() => _expanded = expanding);

    // **无条件**放弃跟随，补不补偿都要放。
    //
    // 补偿那条路：`correctPixels` 是静默的，不说一声的话列表下一条 metrics
    // 通知就把人拽回去。
    //
    // 不补偿那条路（正向组）：块是往下长的，长出来的部分落在视口下方，此时若
    // 还跟着底部，贴底物理会把视口整个拽下去 delta，块的顶边反而跑出屏幕。
    AssistantChatList.maybeOf(context)?.releaseFollow();

    final position = _position;
    (expanding ? _anim.forward() : _anim.reverse()).whenComplete(() {
      if (!mounted || position == null || before == null) return;
      _settleResidual(position, before);
    });
  }

  /// 能不能补偿。两种情况不补：
  ///
  /// 1. **正向组**（中心线下方）。它是往下长的，长高只把它下面的内容顶远，视口里
  ///    已有的东西一动不动，补了反而会把块自己推走。活跃会话里最新那条消息就在
  ///    这一组。
  /// 2. **内容不足一屏**。那时 `min == max`，pixels 无处可去：`correctPixels`
  ///    会把位置推到内容之外，下一次布局再被夹回来 —— 那一夹就是肉眼的一闪。
  bool get _canCompensate {
    if (AssistantChatList.maybeOf(context)?.isInForwardGroup(context) ?? false) {
      return false;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasContentDimensions) return false;
    return position.maxScrollExtent - position.minScrollExtent > 1;
  }

  /// 动画每一帧：把这一帧新长出来（或收回去）的那点高度补掉。
  void _compensateStep() {
    final position = _position;
    if (position == null || _bodyExtent <= 0.5 || !position.hasPixels) return;
    final target = _curve.value * _bodyExtent;
    final step = target - _compensated;
    if (step.abs() < 0.05) return;
    _compensated = target;
    // 下界随正文长出而变松：负向那组这一帧多出 step，新的 min 比当前更负。
    final lower = step > 0
        ? position.minScrollExtent - step
        : position.minScrollExtent;
    position.correctPixels(
      (position.pixels - step).clamp(lower, position.maxScrollExtent),
    );
  }

  /// 兜底：布局落定后看看自己的顶边有没有真的停在原处，差多少补多少；
  /// 最后按落定的位置重新判断跟随状态。
  void _settleResidual(ScrollPosition position, double before) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = _topOf();
      if (now != null) {
        final residual = now - before;
        if (residual.abs() >= 1) {
          position.jumpTo(
            (position.pixels + residual).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        }
      }
      // 位置是静默改的，列表自己看不见 —— 不同步一次的话，收起后明明已经回到
      // 底部，「回到底部」按钮还会一直挂着。
      AssistantChatList.maybeOf(context)?.syncFollowFromPosition();
    });
  }

  double? _topOf() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  /// 离屏量「展开态高度 − 收起态高度」。
  ///
  /// **必须量整块、且给足宽度**：块本身是 `Column(mainAxisSize: .min)`，收起时它的
  /// 宽度就是那一行。拿当时的宽度去量正文，markdown 会在一个远比实际窄的宽度上
  /// 换行，量出来的高度大得离谱 —— 补偿跟着偏，长内容甚至会把列表甩到内容之外。
  double? _measureDelta(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    // 用这块在真实树里**拿到的那份约束**，不要拿屏幕宽度去猜。
    final view = Size(box.constraints.maxWidth, double.infinity);
    // 只补 `InheritedLocaleData`，不能补 `TranslationProvider` —— 后者的构造器把
    // key 设成了 slang 那个按 base locale 缓存的**进程级单例** GlobalKey，再建一份
    // 就会和 App 根部那份撞成「同一个 GlobalKey 挂了两处」，整棵子树报错变灰。
    Widget wrap(Widget child) => InheritedLocaleData<AppLocale, Translations>(
      translations: TranslationProvider.of(context).translations,
      child: child,
    );
    double measure(double factor) => getWidgetSizeOffScreen(
      context: context,
      viewSize: view,
      widget: wrap(_block(context, factor: factor, measuring: true)),
    ).height;
    return measure(1) - measure(0);
  }
}
