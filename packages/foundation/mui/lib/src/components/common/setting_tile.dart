import 'package:mui/mui.dart';

import '../../l10n/mui_l10n.dart';

class SettingTitleTile extends StatelessWidget {
  const SettingTitleTile({super.key, required this.title, this.subtitle});

  final dynamic title;

  final dynamic subtitle;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    final theme = context.theme;
    return ListTile(
      title: (title is String)
          ? Text(title as String, style: theme.typography.titleLarge.primary)
          : title as Widget,
      subtitle: (subtitle is String)
          ? Text(
              subtitle as String,
              style: theme.typography.bodyMedium.onSurfaceVariant,
            )
          : subtitle as Widget?,
    );
  }
}

/// 设置组内两项之间的分隔线。
///
/// `thickness: 0` 在 Skia 里就是 hairline —— **恰好一个设备像素**，见 divider.dart 对
/// thickness 的注释。别改成 `1 / devicePixelRatio`：那条线按逻辑像素排版，落点多半不在
/// 设备像素边界上，会跨两行各画一半，反而显出一条更宽更灰的边。
///
/// 缩进与 [ListTile] 默认的横向 contentPadding 对齐，线两端因此不顶到卡片侧边。
///
/// 正常情况下不用手写它 —— [MSliverSettingGroup] 会在项与项之间自动插。只有**自己就是
/// 一组多行的复合项**（比如应用锁那一块）才需要用它隔开自己内部的行。
class MSettingDivider extends StatelessWidget {
  const MSettingDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 0, thickness: 0, indent: 16, endIndent: 16);
}

class SettingListTile extends StatelessWidget {
  const SettingListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.leading,
    this.isFirst,
    this.isLast,
    this.contentPadding,
    this.tileColor,
    this.shape,
    this.selected = false,
  });

  final dynamic title;

  final dynamic subtitle;

  final Widget? trailing;

  final Widget? leading;

  final VoidCallback? onTap;

  final bool? isFirst;

  final bool? isLast;

  final EdgeInsets? contentPadding;

  final Color? tileColor;

  final ShapeBorder? shape;

  /// 桌面 master-detail 左栏选中态高亮（对应右栏当前打开的项）。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    final theme = context.theme;
    final selectedFg = theme.colors.onSecondaryContainer;
    // 兼容历史用法：传入**不带样式**的 Text 时取其文本，按 tile 默认样式渲染。
    // 带了 style 的原样放行 —— 否则「重置数据」那种 error 色标题会被悄悄套回
    // onSurface，红色没了也不报错。
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text && (title as Text).style == null) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text && (subtitle as Text).style == null) {
      realSubtitle = (subtitle as Text).data;
    }
    return ListTile(
      tileColor: tileColor,
      selected: selected,
      selectedColor: selectedFg,
      selectedTileColor: theme.colors.secondaryContainer,
      title: (realTitle is String)
          ? Text(
              realTitle,
              style: selected
                  ? theme.typography.bodyLarge.emphasized.onSecondaryContainer
                  : theme.typography.bodyLarge.onSurface,
            )
          : realTitle as Widget,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: .vertical(
              top: isFirst == true ? const .circular(12) : .zero,
              bottom: isLast == true ? const .circular(12) : .zero,
            ),
          ),
      contentPadding: contentPadding,
      subtitle: (realSubtitle is String)
          ? Text(
              realSubtitle,
              style: theme.typography.bodyMedium.onSurfaceVariant,
            )
          : realSubtitle as Widget?,
      trailing: trailing,
      leading: leading,
      onTap: onTap,
    );
  }
}

class SettingSwitchListTile extends StatelessWidget {
  const SettingSwitchListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.isFirst,
    this.isLast,
    this.secondary,
    this.isSingle,
  });

  final dynamic title;

  final dynamic subtitle;

  final bool value;

  final ValueChanged<bool>? onChanged;

  final Widget? secondary;

  final bool? isFirst;

  final bool? isLast;

  final bool? isSingle;

  @override
  Widget build(BuildContext context) {
    assert(
      title is String || title is Widget,
      'title must be a String or a Widget',
    );
    assert(
      subtitle == null || subtitle is String || subtitle is Widget,
      'subtitle must be a String or a Widget',
    );
    final theme = context.theme;
    // 同 [SettingListTile]：带样式的 Text 原样放行。
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text && (title as Text).style == null) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text && (subtitle as Text).style == null) {
      realSubtitle = (subtitle as Text).data;
    }
    return SwitchListTile(
      title: (realTitle is String)
          ? Text(realTitle, style: theme.typography.bodyLarge.onSurface)
          : realTitle as Widget,
      secondary: secondary,
      shape: RoundedRectangleBorder(
        borderRadius: isSingle == true
            ? .circular(12)
            : .vertical(
                top: isFirst == true ? const .circular(12) : .zero,
                bottom: isLast == true ? const .circular(12) : .zero,
              ),
      ),
      subtitle: (realSubtitle is String)
          ? Text(
              realSubtitle,
              style: theme.typography.bodyMedium.onSurfaceVariant,
            )
          : realSubtitle as Widget?,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// 弹输入框录入单个字符串值的 ListTile（API Key 等）。
class SettingInputTile extends StatelessWidget {
  const SettingInputTile({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.leading,
    this.onValue,
    this.isFirst = false,
    this.isLast = false,
    this.hintText,
    this.obscureText = false,
  });

  final String title;

  final String? subtitle;

  final String value;

  final Widget? leading;

  final bool isFirst;

  final bool isLast;

  final void Function(String value)? onValue;

  final String? hintText;

  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final hasValue = value.trim().isNotEmpty;
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      title: title,
      leading: leading,
      subtitle:
          subtitle ??
          (hasValue
              ? context.muiL10n.configured
              : context.muiL10n.notConfigured),
      trailing: IconButton.filled(
        tooltip: context.muiL10n.input,
        icon: Icon(LucideIcons.squarePen, color: scheme.onPrimary),
        onPressed: () => _showInputDialog(context),
      ),
    );
  }

  Future<void> _showInputDialog(BuildContext context) async {
    final result = await MAlert.prompt(
      context,
      title: title,
      initialValue: value,
      hintText: hintText,
      obscureText: obscureText,
      confirmLabel: context.muiL10n.save,
    );
    if (result != null && result.isNotEmpty) onValue?.call(result);
  }
}
