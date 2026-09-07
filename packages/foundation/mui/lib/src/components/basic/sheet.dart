import 'package:mui/mui.dart';

const RoundedRectangleBorder _kSheetShape = RoundedRectangleBorder(
  borderRadius: .vertical(top: .circular(24)),
);

const double _kSheetActionHeight = 52;
const double _kSheetActionGap = 12;
const double _kSheetPadding = 20;

abstract final class MSheet {
  static Future<T?> show<T>(
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
      clipBehavior: .antiAlias,
      barrierColor: context.theme.colors.scrim.withValues(alpha: 0.32),
      builder: (sheetContext) => Semantics(
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

  static Future<T?> picker<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? icon,
    required List<MSheetOption<T>> options,
    T? selected,
    String? cancelLabel,
    Widget? footer,
  }) {
    return MSheet.show<T>(
      context,
      builder: (sheetContext) => MSheetScaffold<T>(
        title: title,
        subtitle: subtitle,
        icon: icon,
        actions: [MAction(label: cancelLabel ?? sheetContext.muiL10n.cancel)],
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            for (final option in options)
              MSheetOptionTile<T>(
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
}

class _SheetInsets extends StatelessWidget {
  final double topGap;
  final Widget child;

  const _SheetInsets({required this.topGap, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    return Padding(
      padding: .only(
        top: topGap,
        bottom: bottomInset + (bottomInset > 0 ? 0 : media.viewPadding.bottom),
      ),
      child: child,
    );
  }
}

class MSheetOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;

  const MSheetOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });
}

class MSheetOptionTile<T> extends StatelessWidget {
  final MSheetOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  const MSheetOptionTile({
    super.key,
    required this.option,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      selected: selected,
      enabled: option.enabled,
      child: Padding(
        padding: const .only(bottom: 6),
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          clipBehavior: .antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: MuiRadius.md,
            side: selected
                ? BorderSide(color: scheme.primary, width: 1.5)
                : .none,
          ),
          child: MInkWell(
            onTap: option.enabled ? onTap : null,
            child: Opacity(
              opacity: option.enabled ? 1 : 0.4,
              child: Padding(
                padding: const .symmetric(horizontal: 16, vertical: 12),
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
                            style:
                                (selected
                                        ? typography.bodyLarge.emphasized
                                        : typography.bodyLarge)
                                    .onSurface
                                    .copyWith(color: foreground),
                          ),
                          if (option.subtitle != null)
                            Text(
                              option.subtitle!,
                              style: selected
                                  ? typography.bodySmall.onPrimaryContainer
                                  : typography.bodySmall.onSurfaceVariant,
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

class MSheetScaffold<T> extends StatelessWidget {
  final String? title;

  final String? subtitle;
  final IconData? icon;
  final bool isDestructive;
  final Widget child;
  final List<MAction<T>> actions;
  final MActionsLayout actionsLayout;

  const MSheetScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
    required this.child,
    this.actions = const [],
    this.actionsLayout = .auto,
  });

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
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final hasHeader = title != null || subtitle != null || icon != null;

    final header = hasHeader
        ? Padding(
            padding: .symmetric(horizontal: foldHeader ? 0 : _kSheetPadding),
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
                          style: typography.titleLarge.emphasized.onSurface,
                        ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: typography.bodySmall.onSurfaceVariant,
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
            padding: .fromLTRB(
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
            padding: const .fromLTRB(_kSheetPadding, 12, _kSheetPadding, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: MActionBar<T>(
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
