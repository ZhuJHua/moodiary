import 'package:mui/mui.dart';

const double _kOneLineHeight = 56;
const double _kTwoLineHeight = 72;

const double _kHorizontalPadding = 16;

const double _kSlotGap = 16;

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
    return Padding(
      padding: const .fromLTRB(_kHorizontalPadding, 16, _kHorizontalPadding, 8),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          _asText(title, theme.typography.titleLarge.primary)!,
          if (subtitle != null)
            _asText(subtitle, theme.typography.bodyMedium.onSurfaceVariant)!,
        ],
      ),
    );
  }
}

Widget? _asText(dynamic value, TextStyle style) => switch (value) {
  null => null,
  String() => Text(value, style: style),
  Text(style: null, data: final data?) => Text(data, style: style),
  Widget() => value,
  _ => throw ArgumentError('必须是 String 或 Widget，收到 ${value.runtimeType}'),
};

class MSettingDivider extends StatelessWidget {
  const MSettingDivider({super.key});

  @override
  Widget build(BuildContext context) => const Divider(
    height: 0,
    thickness: 0,
    indent: _kHorizontalPadding,
    endIndent: _kHorizontalPadding,
  );
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

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final fg = selected ? theme.colors.onSecondaryContainer : null;
    final titleStyle = selected
        ? theme.typography.bodyLarge.emphasized.onSecondaryContainer
        : theme.typography.bodyLarge.onSurface;
    final subtitleStyle = selected
        ? theme.typography.bodyMedium.onSecondaryContainer
        : theme.typography.bodyMedium.onSurfaceVariant;

    final titleWidget = _asText(title, titleStyle)!;
    final subtitleWidget = _asText(subtitle, subtitleStyle);

    Widget row = Padding(
      padding:
          contentPadding ??
          const .symmetric(horizontal: _kHorizontalPadding, vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(color: fg ?? theme.colors.onSurfaceVariant),
              child: leading!,
            ),
            const SizedBox(width: _kSlotGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              children: [titleWidget, ?subtitleWidget],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: _kSlotGap),
            IconTheme.merge(
              data: IconThemeData(color: fg ?? theme.colors.onSurfaceVariant),
              child: trailing!,
            ),
          ],
        ],
      ),
    );

    row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: subtitleWidget == null ? _kOneLineHeight : _kTwoLineHeight,
      ),
      child: Align(alignment: .centerLeft, child: row),
    );

    final background = selected ? theme.colors.secondaryContainer : tileColor;
    if (background != null) row = ColoredBox(color: background, child: row);

    return MInkWell(
      onTap: onTap,
      borderRadius: shape == null ? _groupRadius(context) : null,
      shape: shape,
      child: row,
    );
  }

  BorderRadius? _groupRadius(BuildContext context) {
    if (isFirst != true && isLast != true) return null;
    final r = Radius.circular(context.theme.radii.lg);
    return .vertical(
      top: isFirst == true ? r : Radius.zero,
      bottom: isLast == true ? r : Radius.zero,
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
    final onChanged = this.onChanged;
    return SettingListTile(
      title: title,
      subtitle: subtitle,
      leading: secondary,
      isFirst: isSingle == true ? true : isFirst,
      isLast: isSingle == true ? true : isLast,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }
}

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
