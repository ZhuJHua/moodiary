import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return ListTile(
      title: (title is String)
          ? Text(
              title as String,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            )
          : title as Widget,
      subtitle: (subtitle is String)
          ? Text(
              subtitle as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : subtitle as Widget?,
    );
  }
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
    final theme = Theme.of(context);
    final selectedFg = theme.colorScheme.onSecondaryContainer;
    // 兼容历史用法：传入 Text 时取其文本，按 tile 默认样式渲染。
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text) {
      realSubtitle = (subtitle as Text).data;
    }
    return ListTile(
      tileColor: tileColor,
      selected: selected,
      selectedColor: selectedFg,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      title: (realTitle is String)
          ? Text(
              realTitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: selected ? selectedFg : theme.colorScheme.onSurface,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            )
          : realTitle as Widget,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: isFirst == true ? const Radius.circular(12) : Radius.zero,
              bottom: isLast == true ? const Radius.circular(12) : Radius.zero,
            ),
          ),
      contentPadding: contentPadding,
      subtitle: (realSubtitle is String)
          ? Text(
              realSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
    final theme = Theme.of(context);
    var realTitle = title;
    var realSubtitle = subtitle;
    if (title is Text) {
      realTitle = (title as Text).data;
    }
    if (subtitle is Text) {
      realSubtitle = (subtitle as Text).data;
    }
    return SwitchListTile(
      title: (realTitle is String)
          ? Text(
              realTitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            )
          : realTitle as Widget,
      secondary: secondary,
      shape: RoundedRectangleBorder(
        borderRadius: isSingle == true
            ? BorderRadius.circular(12)
            : BorderRadius.vertical(
                top: isFirst == true ? const Radius.circular(12) : Radius.zero,
                bottom: isLast == true ? const Radius.circular(12) : Radius.zero,
              ),
      ),
      subtitle: (realSubtitle is String)
          ? Text(
              realSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : realSubtitle as Widget?,
      value: value,
      onChanged: onChanged,
    );
  }
}
