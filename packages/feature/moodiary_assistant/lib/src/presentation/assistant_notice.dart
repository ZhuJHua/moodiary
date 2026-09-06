library;

import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

const Duration _kExpandDuration = Duration(milliseconds: 220);

class AssistantNotice extends StatefulWidget {
  final IconData? icon;

  final String kind;

  final String summary;

  final WidgetBuilder? detail;

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

  double _bodyExtent = 0;

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
        padding: const .fromLTRB(22, 1, 0, 6),
        child: Builder(builder: widget.detail!),
      );
      if (!measuring) body = SelectionArea(child: body);
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

    Widget wrapped = content;
    if (!measuring && (_expandable || widget.onTap != null)) {
      wrapped = GestureDetector(
        behavior: .opaque,
        onTap: _expandable ? _toggle : widget.onTap,
        child: content,
      );
    }
    return Padding(padding: const .only(bottom: 6), child: wrapped);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, _) => _block(context, factor: _curve.value),
  );

  void _toggle() {
    final expanding = !_expanded;
    _position = Scrollable.maybeOf(context)?.position;
    final before = _topOf();
    final previous = _bodyExtent;
    _bodyExtent = _measureDelta(context) ?? 0;
    _compensated = previous <= 0 ? 0 : _curve.value * _bodyExtent;

    setState(() => _expanded = expanding);

    AssistantChatList.maybeOf(context)?.releaseFollow();

    (expanding ? _anim.forward() : _anim.reverse()).whenComplete(() {
      if (!mounted || before == null) return;
      _settleResidual(before);
    });
  }

  bool get _shouldCompensateNow {
    final list = AssistantChatList.maybeOf(context);
    if (list != null &&
        (list.isInForwardGroup(context) || list.contentFitsViewport)) {
      return false;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasContentDimensions) return false;
    return position.maxScrollExtent - position.minScrollExtent > 1;
  }

  void _compensateStep() {
    if (!mounted || _bodyExtent <= 0.5) return;
    final target = _curve.value * _bodyExtent;
    final live = Scrollable.maybeOf(context)?.position;
    if (live == null || !live.hasPixels) {
      _compensated = target;
      return;
    }
    if (!identical(live, _position)) {
      _position = live;
      _compensated = target;
      return;
    }
    if (!_shouldCompensateNow) {
      _compensated = target;
      return;
    }
    final step = target - _compensated;
    if (step.abs() < 0.05) return;
    _compensated = target;
    final lower = step > 0 ? live.minScrollExtent - step : live.minScrollExtent;
    live.correctPixels((live.pixels - step).clamp(lower, live.maxScrollExtent));
  }

  void _settleResidual(double before) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      final now = _topOf();
      if (position != null && now != null && _shouldCompensateNow) {
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
      AssistantChatList.maybeOf(context)?.syncFollowFromPosition();
    });
  }

  double? _topOf() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  double? _measureDelta(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final view = Size(box.constraints.maxWidth, double.infinity);
    // TranslationProvider 的 key 是按 locale 缓存的进程级单例 GlobalKey，重复创建会冲突
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
