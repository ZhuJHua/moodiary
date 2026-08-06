import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 弹层底部的一个动作。字段名对齐 [MoodiaryMenuEntry]，让菜单、居中弹窗与底部
/// 弹窗共享同一套心智。
///
/// 三种呈现由两个布尔量决定：[isDestructive] → error 实心，[isPrimary] → primary
/// 实心，都不是则为中性键（取消）。
class MoodiaryAction<T> {
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

  const MoodiaryAction({
    required this.label,
    this.value,
    this.isPrimary = false,
    this.isDestructive = false,
    this.enabled = true,
    this.busy = false,
    this.onPressed,
    this.onIntercept,
  });
}

/// 底部按钮的排布方式。
enum MoodiaryActionsLayout {
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
class MoodiaryActionBar<T> extends StatelessWidget {
  final List<MoodiaryAction<T>> actions;
  final MoodiaryActionsLayout layout;
  final double height;
  final double gap;

  const MoodiaryActionBar({
    super.key,
    required this.actions,
    required this.layout,
    required this.height,
    required this.gap,
  });

  bool _fitsInRow(BuildContext context, double maxWidth, TextStyle? style) {
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

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelLarge?.copyWith(fontWeight: .w600);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = switch (layout) {
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
              for (final (index, action) in actions.indexed) ...[
                if (index > 0) SizedBox(width: gap),
                Expanded(
                  child: MoodiaryActionButton<T>(
                    action: action,
                    textStyle: style,
                    height: height,
                  ),
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            for (final (index, action) in actions.reversed.indexed) ...[
              if (index > 0) SizedBox(height: gap),
              MoodiaryActionButton<T>(
                action: action,
                textStyle: style,
                height: height,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 单颗动作键。点击默认 `pop(action.value)`，除非动作自带 [MoodiaryAction.onPressed]。
class MoodiaryActionButton<T> extends StatelessWidget {
  final MoodiaryAction<T> action;
  final TextStyle? textStyle;
  final double height;

  const MoodiaryActionButton({
    super.key,
    required this.action,
    required this.textStyle,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
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

    void handleTap() {
      final onPressed = action.onPressed;
      if (onPressed != null) {
        onPressed();
        return;
      }
      if (action.onIntercept?.call() == false) return;
      Navigator.of(context).pop(action.value);
    }

    return FilledButton(
      onPressed: action.enabled ? handleTap : null,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: .fromHeight(height),
        padding: const .symmetric(horizontal: 12),
        textStyle: textStyle,
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.mediumBorderRadius,
        ),
      ),
      // 转圈期间按钮通常已被禁用，颜色只能显式给——否则会被 disabledForegroundColor 吃掉。
      child: action.busy
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
