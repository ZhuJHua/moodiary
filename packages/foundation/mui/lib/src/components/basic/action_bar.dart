import 'package:mui/mui.dart';

/// 弹层底部的一个动作。字段名对齐 [MMenuEntry]，让菜单、居中弹窗与底部
/// 弹窗共享同一套心智。
///
/// 三种呈现由两个布尔量决定：[isDestructive] → error 实心，[isPrimary] → primary
/// 实心，都不是则为中性键（取消）。
class MAction<T> {
  /// 点击后弹层返回的值。[onPressed] 接管点击时不使用。
  final T? value;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final bool enabled;

  /// 用转圈代替文字。异步提交期间用，通常与 `enabled: false` 同时给。
  final bool busy;

  /// 自行接管点击：给了它就不再自动关闭弹层，何时关闭由调用方决定。异步提交
  /// （先转圈、成功才 pop）走这条路。
  final VoidCallback? onPressed;

  /// 点击拦截：返回 false 时弹层不关闭。给自带同步校验的复合内容用 —— 校验失败
  /// 应当留住弹层并就地报错，不要「先关弹层再 toast」。[onPressed] 存在时不生效。
  final bool Function()? onIntercept;

  /// 异步提交：执行期间这颗键转圈、整条动作条禁用、遮罩与返回键挡住；resolve true
  /// 关闭弹层并返回 [value]，false 留住弹层（错误由内容区就地展示）。抛错视同 false
  /// 并继续向上抛。[onIntercept] 先跑，同步校验没过就不进异步。[onPressed] 存在时不生效。
  ///
  /// 与 [busy] 的分工：[busy] 是调用方自己管状态时的静态旗子（[onPressed] 那条路），
  /// 走 [onSubmit] 则由动作条自己管，调用方一行都不用写。
  final Future<bool> Function()? onSubmit;

  const MAction({
    required this.label,
    this.value,
    this.isPrimary = false,
    this.isDestructive = false,
    this.enabled = true,
    this.busy = false,
    this.onPressed,
    this.onIntercept,
    this.onSubmit,
  });
}

/// 底部按钮的排布方式。
enum MActionsLayout {
  /// 两个动作且文案放得下时横排等宽，否则竖排。
  auto,
  horizontal,
  vertical,
}

/// 弹层底部的动作条。
///
/// [actions] 的顺序是「从次要到主要」——横排时从左到右按原序（取消在左、主操作在
/// 右，沿用 M3 OverflowBar 的既有顺序），竖排时反序（主操作在上、取消在最下）。
///
/// 排布规则：单个动作全宽；两个动作且量出来放得下时横排等宽；其余一律竖排并反序。
///
/// 有状态只为一件事：某颗键的 [MAction.onSubmit] 跑着的时候，它转圈、其它键禁用、
/// 本路由禁 pop（PopScope 注册到最近的 ModalRoute，遮罩与返回键都走 maybePop）。
class MActionBar<T> extends StatefulWidget {
  final List<MAction<T>> actions;
  final MActionsLayout layout;
  final double height;
  final double gap;

  const MActionBar({
    super.key,
    required this.actions,
    required this.layout,
    required this.height,
    required this.gap,
  });

  @override
  State<MActionBar<T>> createState() => _MActionBarState<T>();
}

class _MActionBarState<T> extends State<MActionBar<T>> {
  /// 正在异步提交的那颗键。
  int? _busyIndex;

  bool _fitsInRow(BuildContext context, double maxWidth, TextStyle? style) {
    final actions = widget.actions;
    final gap = widget.gap;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var total = gap * (actions.length - 1);
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      // 每颗按钮文字两侧至少各留 16。
      total += painter.width + 32;
    }
    return total <= maxWidth;
  }

  /// 点击默认 `pop(action.value)`；[MAction.onPressed] 接管则什么都不做；
  /// [MAction.onIntercept] 返回 false 留住；[MAction.onSubmit] 先转圈等结果。
  Future<void> _tap(int index) async {
    final action = widget.actions[index];
    final onPressed = action.onPressed;
    if (onPressed != null) {
      onPressed();
      return;
    }
    if (action.onIntercept?.call() == false) return;
    final submit = action.onSubmit;
    if (submit != null) {
      setState(() => _busyIndex = index);
      var ok = false;
      try {
        ok = await submit();
      } finally {
        if (mounted) setState(() => _busyIndex = null);
      }
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(action.value);
  }

  Widget _button(int index, TextStyle style) {
    final action = widget.actions[index];
    final busyIndex = _busyIndex;
    return MActionButton<T>(
      action: action,
      textStyle: style,
      height: widget.height,
      busy: action.busy || busyIndex == index,
      enabled: action.enabled && busyIndex == null,
      onTap: () => _tap(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = context.theme.typography.labelLarge.emphasized.onSurface;
    final actions = widget.actions;
    final gap = widget.gap;

    return PopScope(
      canPop: _busyIndex == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = switch (widget.layout) {
            .horizontal => true,
            .vertical => false,
            .auto =>
              actions.length == 1 ||
                  (actions.length == 2 &&
                      _fitsInRow(context, constraints.maxWidth, style)),
          };

          if (horizontal) {
            return Row(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) SizedBox(width: gap),
                  Expanded(child: _button(index, style)),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [
              for (var index = actions.length - 1; index >= 0; index--) ...[
                if (index < actions.length - 1) SizedBox(height: gap),
                _button(index, style),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 单颗动作键，纯呈现：转圈 / 禁用 / 点击全由 [MActionBar] 决定。
class MActionButton<T> extends StatelessWidget {
  final MAction<T> action;
  final TextStyle? textStyle;
  final double height;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const MActionButton({
    super.key,
    required this.action,
    required this.textStyle,
    required this.height,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final Color background;
    final Color foreground;
    if (action.isDestructive) {
      background = scheme.error;
      foreground = scheme.onError;
    } else if (action.isPrimary) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
    }

    return FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: scheme.onSurface.withValues(
          alpha: context.theme.states.disabledContainerOpacity,
        ),
        disabledForegroundColor: scheme.onSurface.withValues(
          alpha: context.theme.states.disabledOpacity,
        ),
        minimumSize: .fromHeight(height),
        padding: const .symmetric(horizontal: 12),
        textStyle: textStyle,
        shape: const RoundedRectangleBorder(borderRadius: MuiRadius.md),
      ),
      // 转圈期间按钮通常已被禁用，颜色只能显式给——否则会被 disabledForegroundColor 吃掉。
      child: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : Text(action.label, maxLines: 1, overflow: .ellipsis),
    );
  }
}
