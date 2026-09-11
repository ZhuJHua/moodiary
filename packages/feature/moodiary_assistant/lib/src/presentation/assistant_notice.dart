library;

import 'package:moodiary_assistant/src/presentation/chat_list.dart';
import 'package:mui/mui.dart';

const Duration _kExpandDuration = Duration(milliseconds: 220);

class AssistantNotice extends StatefulWidget {
  final IconData? icon;

  final String kind;

  final String summary;

  final WidgetBuilder? detail;

  final VoidCallback? onTap;

  // 给了才把展开状态托管到列表；没给的块被重建就回到收起
  final String? stateKey;

  final bool hideSummaryWhenExpanded;

  const AssistantNotice({
    super.key,
    this.icon,
    required this.kind,
    this.summary = '',
    this.detail,
    this.onTap,
    this.stateKey,
    this.hideSummaryWhenExpanded = false,
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

  AssistantChatListState? _list;

  // 一个 State 至多持一份 hold：动画中途再点只是掉头，停下来才还
  String? _held;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener(_onStatus);
    final key = widget.stateKey;
    if (key == null || !_expandable) return;
    _list = AssistantChatList.maybeOf(context);
    _expanded = _list?.expandedOf(context, key) ?? false;
    if (_expanded) _anim.value = 1;
  }

  void _onStatus(AnimationStatus status) {
    if (!status.isAnimating) _releaseHold();
  }

  void _releaseHold() {
    final id = _held;
    _held = null;
    if (id != null) _list?.endItemResize(id);
  }

  @override
  void dispose() {
    _releaseHold();
    _curve.dispose();
    _anim.dispose();
    super.dispose();
  }

  bool get _expandable => widget.detail != null;

  Widget _block(BuildContext context, {required double factor}) {
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

    final summaryOpacity = widget.hideSummaryWhenExpanded ? 1 - factor : 1.0;
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
          if (widget.summary.isNotEmpty && summaryOpacity > 0)
            Expanded(
              child: Opacity(
                opacity: summaryOpacity,
                child: Row(
                  children: [
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
                  ],
                ),
              ),
            )
          else
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
      body = SelectionArea(
        child: Padding(
          padding: const .fromLTRB(22, 1, 0, 6),
          child: Builder(builder: widget.detail!),
        ),
      );
      if (factor < 1) {
        body = ClipRect(
          child: Align(
            alignment: .topLeft,
            // 只展开高度：宽度跟着 factor 缩会让整块内容横向抽动
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
    if (_expandable || widget.onTap != null) {
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
    final list = _list ??= AssistantChatList.maybeOf(context);
    final key = widget.stateKey;
    if (key != null) list?.setExpanded(context, key, expanding);
    _held ??= list?.beginItemResize(context);
    setState(() => _expanded = expanding);
    if (expanding) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }
}
