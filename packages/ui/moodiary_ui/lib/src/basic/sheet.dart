import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/src/basic/action_bar.dart';

/// 顶部圆角取仓内的 [AppBorderRadius.xLargeBorderRadius]（24）而不是 M3 默认的 28 ——
/// 那个 24 本来就是为了统一替掉 M3 弹窗的 28 才定的，两处得说同一种话。这也是本组件
/// 唯一覆盖官方默认值的形状；底色、elevation、宽度上限 640、高度上限、抓手与拖动
/// 手势全部沿用 [showModalBottomSheet] 的默认行为。
const RoundedRectangleBorder _kSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

const double _kSheetActionHeight = 52;
const double _kSheetActionGap = 12;
const double _kSheetPadding = 20;

/// 底部弹窗。就是官方的 [showModalBottomSheet]，本仓只固定了几个参数，让 18 处调用点
/// 说同一种话：`isScrollControlled`（表单要吃键盘）、`useSafeArea`（别盖住状态栏）、
/// 抓手、遮罩色与顶部圆角。
///
/// 尺寸上限全走官方：宽度 640 后居中，高度即可用高度（顶部安全区已被 `useSafeArea`
/// 扣掉），超出部分由 [MoodiarySheetScaffold] 的内容区滚动吸收。
///
/// [builder] 通常返回一个 [MoodiarySheetScaffold]；需要完全自定义版式（PIN 键盘、
/// 录音）时也可以直接返回内容。
Future<T?> showMoodiarySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool showHandle = true,
  bool barrierDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: barrierDismissible,
    showDragHandle: showHandle,
    shape: _kSheetShape,
    clipBehavior: Clip.antiAlias,
    barrierColor: context.colorScheme.scrim.withValues(alpha: 0.32),
    builder: (sheetContext) => Semantics(
      // 官方路由不给弹窗起名，读屏进入时只会念遮罩的「关闭」。
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: MaterialLocalizations.of(sheetContext).bottomSheetLabel,
      child: _SheetInsets(
        topGap: showHandle ? 0 : 12,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// 键盘避让 + 底部安全区。官方这两件不管：`useSafeArea` 只挡上、左、右，
/// 键盘按惯例由 builder 自己让。
class _SheetInsets extends StatelessWidget {
  final double topGap;
  final Widget child;

  const _SheetInsets({required this.topGap, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    return Padding(
      // 弹窗贴住屏幕下沿，内容要让开手势条；键盘顶起时那块已经被 viewInsets 占了。
      padding: EdgeInsets.only(
        top: topGap,
        bottom: bottomInset + (bottomInset > 0 ? 0 : media.viewPadding.bottom),
      ),
      child: child,
    );
  }
}

/// 选择型弹窗：一列选项，点中即回填并关闭，底部只留一颗「取消」。
///
/// 返回被选中的值；取消 / 下拉 / 点遮罩 / 返回键都返回 null。需要在列表尾部挂
/// 「新建…」这类附加入口时给 [footer]。
Future<T?> showMoodiaryPickerSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  required List<MoodiarySheetOption<T>> options,
  T? selected,
  String? cancelLabel,
  Widget? footer,
}) {
  return showMoodiarySheet<T>(
    context,
    builder: (sheetContext) => MoodiarySheetScaffold<T>(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actions: [MoodiaryAction(label: cancelLabel ?? sheetContext.l10n.cancel)],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          for (final option in options)
            MoodiarySheetOptionTile<T>(
              option: option,
              selected: option.value == selected,
              onTap: () => Navigator.of(sheetContext).pop(option.value),
            ),
          ?footer,
        ],
      ),
    ),
  );
}

/// [showMoodiaryPickerSheet] 的一项。
class MoodiarySheetOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;

  const MoodiarySheetOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });
}

/// 选项行。选中态用 primaryContainer 打底 + 右侧对勾，不用 Radio ——
/// 点一下即关闭的列表里，单选圈只是多一层要解读的控件。
class MoodiarySheetOptionTile<T> extends StatelessWidget {
  final MoodiarySheetOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  const MoodiarySheetOptionTile({
    super.key,
    required this.option,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    // 选中态给读屏一个真的标志位：底色、字重、对勾都只是视觉，语义树里三项完全同形，
    // 读屏用户无从知道当前生效的是哪一个。
    return Semantics(
      selected: selected,
      enabled: option.enabled,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          clipBehavior: .antiAlias,
          // primaryContainer 与卡片底色在浅色 tonalSpot 下只差一点，描边是不依赖
          // 色彩辨识度的第二条线索。shape 与 borderRadius 只能给一个（Material 断言）。
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            side: selected
                ? BorderSide(color: scheme.primary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: option.enabled ? onTap : null,
            child: Opacity(
              opacity: option.enabled ? 1 : 0.4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (option.icon != null) ...[
                      Icon(option.icon, size: 20, color: foreground),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        mainAxisSize: .min,
                        children: [
                          Text(
                            option.label,
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: foreground,
                              fontWeight: selected ? .w600 : .w400,
                            ),
                          ),
                          if (option.subtitle != null)
                            Text(
                              option.subtitle!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: selected
                                    ? foreground.withValues(alpha: 0.75)
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(LucideIcons.check, size: 18, color: foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹窗骨架：抓手 → 头部 → 可滚内容 → 固定动作条。
///
/// 只有中间内容滚动，动作条永远贴在卡片底边 —— 键盘升起时整卡上移，「保存」不会
/// 被推出屏幕（这正是旧表单把整体塞进 SingleChildScrollView 的毛病）。
///
/// [actions] 语义与排布规则和 [showMoodiaryAlert] 完全一致，只是按钮更高更宽松。
class MoodiarySheetScaffold<T> extends StatelessWidget {
  final String? title;

  /// 承载状态而非说明：写「已连接 · dav.example.com」，不写「请填写服务器地址」。
  final String? subtitle;
  final IconData? icon;
  final bool isDestructive;
  final Widget child;
  final List<MoodiaryAction<T>> actions;
  final MoodiaryActionsLayout actionsLayout;

  const MoodiarySheetScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
    required this.child,
    this.actions = const [],
    this.actionsLayout = .auto,
  });

  /// 低于这个可用高度就把头部折进滚动区。头部与动作条都不可压缩，两者之和撑破
  /// 剩余高度时 Column 会直接溢出（平板分屏 / 折叠屏横屏 + 键盘就够矮）。
  static const double _kFoldHeaderBelow = 240;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        foldHeader:
            constraints.hasBoundedHeight &&
            constraints.maxHeight < _kFoldHeaderBelow,
      ),
    );
  }

  Widget _build(BuildContext context, {required bool foldHeader}) {
    final scheme = context.colorScheme;
    final textTheme = context.textTheme;
    final hasHeader = title != null || subtitle != null || icon != null;

    // 折进滚动区时不再重复左右内边距 —— 滚动区自己已经有一份。
    final header = hasHeader
        ? Padding(
            // 顶部空隙由容器的手柄区负责，头部自己不再留。
            padding: EdgeInsets.symmetric(
              horizontal: foldHeader ? 0 : _kSheetPadding,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: .circle,
                      color: isDestructive
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isDestructive
                          ? scheme.onErrorContainer
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: .w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : null;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (!foldHeader) ?header,
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              _kSheetPadding,
              hasHeader && !foldHeader ? 16 : 8,
              _kSheetPadding,
              actions.isEmpty ? 16 : 4,
            ),
            child: foldHeader && header != null
                ? Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .stretch,
                    children: [header, const SizedBox(height: 16), child],
                  )
                : child,
          ),
        ),
        if (actions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(
              _kSheetPadding,
              12,
              _kSheetPadding,
              16,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: MoodiaryActionBar<T>(
              actions: actions,
              layout: actionsLayout,
              height: _kSheetActionHeight,
              gap: _kSheetActionGap,
            ),
          ),
      ],
    );
  }
}
