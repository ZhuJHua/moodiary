import 'dart:math';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'panel_parts.dart';
import 'toolbar_button.dart';

const _minPercent = 25;
const _maxPercent = 100;
const _widthPercents = [_minPercent, 50, 75, _maxPercent];

class FloatingCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const FloatingCard({super.key, required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ExcludeFocus(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: panelGroupColor(context),
          borderRadius: .circular(theme.radii.lg),
          border: Border.all(color: theme.colors.surfaceContainerHighest),
          boxShadow: theme.elevations.low,
        ),
        child: child,
      ),
    );
  }
}

class PopoverHeader extends StatelessWidget {
  final String title;
  final String value;

  const PopoverHeader({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final role = context.theme.typography.labelLarge;
    return Row(
      children: [
        Expanded(child: Text(title, style: role.withColor(colors.onSurface))),
        Text(value, style: role.withColor(colors.onSurfaceVariant).tabular),
      ],
    );
  }
}

class LinkBar extends StatelessWidget {
  final String href;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const LinkBar({
    super.key,
    required this.href,
    required this.onOpen,
    required this.onCopy,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final colors = context.theme.colors;
    return FloatingCard(
      padding: const .only(left: 12, right: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          spacing: 4,
          children: [
            Icon(LucideIcons.link, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                href.replaceFirst(RegExp(r'^[a-zA-Z][\w+.-]*://'), ''),
                maxLines: 1,
                overflow: .ellipsis,
                style: context.theme.typography.bodyMedium.onSurfaceVariant,
              ),
            ),
            ToolbarIconButton(
              icon: LucideIcons.externalLink,
              tooltip: t.openLink,
              onTap: onOpen,
            ),
            ToolbarIconButton(
              icon: LucideIcons.copy,
              tooltip: t.copyLink,
              onTap: onCopy,
            ),
            ToolbarIconButton(
              icon: LucideIcons.pencil,
              tooltip: t.editLink,
              onTap: onEdit,
            ),
            ToolbarIconButton(
              icon: LucideIcons.unlink,
              tooltip: t.removeLink,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class WidthPicker extends StatefulWidget {
  final int? current;
  final ValueChanged<int> onPreview;
  final ValueChanged<int?> onPick;

  const WidthPicker({
    super.key,
    required this.current,
    required this.onPreview,
    required this.onPick,
  });

  @override
  State<WidthPicker> createState() => _WidthPickerState();
}

class _WidthPickerState extends State<WidthPicker> {
  int? _draft;
  bool _dragging = false;

  @override
  void didUpdateWidget(WidthPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current == oldWidget.current) return;
    if (!_dragging) _draft = null;
  }

  static int _snap(double value) {
    final percent = value.round().clamp(_minPercent, _maxPercent);
    for (final stop in _widthPercents) {
      if ((percent - stop).abs() <= 3) return stop;
    }
    return percent;
  }

  void _pick(int? percent) {
    if (percent != widget.current) return widget.onPick(percent);
    if (_draft != null) setState(() => _draft = null);
  }

  void _show(int percent) {
    if (percent == _draft) return;
    setState(() => _draft = percent);
    widget.onPreview(percent);
  }

  void _preview(double value) => _show(_snap(value));

  void _release() {
    _dragging = false;
    if (_draft case final percent?) _pick(percent);
  }

  void _step(int delta) {
    _show(
      ((_draft ?? widget.current ?? _maxPercent) + delta).clamp(
        _minPercent,
        _maxPercent,
      ),
    );
    _release();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final typo = context.theme.typography;
    final colors = context.theme.colors;
    final shown = _draft ?? widget.current;
    Widget segment(int? percent) {
      final label = percent == null ? t.original : '$percent%';
      return PanelSegment(
        selected: shown == percent,
        onTap: () => _pick(percent),
        semanticLabel: percent == null ? t.originalSize : label,
        child: SegmentText(label, style: typo.labelLarge.onSurface),
      );
    }

    final slider = LayoutBuilder(
      builder: (context, constraints) {
        double at(Offset position) =>
            _minPercent +
            (position.dx / constraints.maxWidth).clamp(0.0, 1.0) *
                (_maxPercent - _minPercent);
        final value = shown ?? _maxPercent;
        return Semantics(
          slider: true,
          label: t.width,
          value: '$value%',
          increasedValue: '${min(value + 1, _maxPercent)}%',
          decreasedValue: '${max(value - 1, _minPercent)}%',
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: GestureDetector(
            behavior: .opaque,
            onTapUp: (d) {
              _preview(at(d.localPosition));
              _release();
            },
            onHorizontalDragStart: (d) {
              _dragging = true;
              _preview(at(d.localPosition));
            },
            onHorizontalDragUpdate: (d) => _preview(at(d.localPosition)),
            onHorizontalDragEnd: (_) => _release(),
            onHorizontalDragCancel: _release,
            child: SizedBox(
              height: 40,
              child: Center(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: colors.primary,
                        inactiveTrackColor: colors.surfaceContainerHighest,
                        thumbColor: colors.primary,
                        trackShape: const RoundedRectSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                          elevation: 0,
                          pressedElevation: 0,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        min: _minPercent.toDouble(),
                        max: _maxPercent.toDouble(),
                        padding: .zero,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    return FloatingCard(
      padding: const .all(16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          PopoverHeader(
            title: t.width,
            value: shown == null ? t.originalSize : '$shown%',
          ),
          const SizedBox(height: 4),
          slider,
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: Row(
              spacing: 4,
              children: [
                for (final percent in [..._widthPercents, null])
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: .circular(context.theme.radii.sm),
                      ),
                      child: segment(percent),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TableMenuBar extends StatelessWidget {
  final VoidCallback onToggleHeader;
  final VoidCallback onDelete;

  const TableMenuBar({
    super.key,
    required this.onToggleHeader,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    return FloatingCard(
      padding: const .all(4),
      child: Row(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          ToolbarLabelButton(
            icon: LucideIcons.panelTop,
            label: t.tableHeaderRow,
            onTap: onToggleHeader,
          ),
          ToolbarLabelButton(
            icon: LucideIcons.trash2,
            label: t.tableDelete,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
