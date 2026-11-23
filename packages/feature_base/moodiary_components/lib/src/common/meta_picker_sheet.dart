import 'package:flutter/foundation.dart' show setEquals;
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

typedef MetaPickerResult<T> = ({List<T> selected, List<String> created});

class MetaPickerSheet<T> extends StatefulWidget {
  const MetaPickerSheet.single({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.searchHint,
    required this.options,
    required this.matchesLabel,
    this.selected,
    this.chipSize = .small,
    String? createLabel,
    this.onCreate,
  }) : assert((createLabel == null) == (onCreate == null)),
       singleCreateLabel = createLabel,
       tagCreateLabel = null,
       recentLabel = null,
       initial = null,
       selectionSubtitle = null,
       normalizeName = null;

  const MetaPickerSheet.multi({
    super.key,
    required this.title,
    required this.selectionSubtitle,
    required this.icon,
    required this.searchHint,
    required this.options,
    required this.matchesLabel,
    required String this.recentLabel,
    required String Function(String) createLabel,
    required Set<T> this.initial,
    this.normalizeName,
  }) : chipSize = .small,
       selected = null,
       subtitle = null,
       singleCreateLabel = null,
       tagCreateLabel = createLabel,
       onCreate = null;

  final String title;
  final MChipSize chipSize;
  final String? subtitle;
  final String Function(int)? selectionSubtitle;
  final IconData icon;
  final String searchHint;
  final List<MSheetOption<T>> options;
  final T? selected;
  final Set<T>? initial;
  final String Function(int) matchesLabel;
  final String? recentLabel;
  final String? singleCreateLabel;
  final String Function(String)? tagCreateLabel;
  final Future<T?> Function(String query)? onCreate;
  final String? Function(String)? normalizeName;

  @override
  State<MetaPickerSheet<T>> createState() => _MetaPickerSheetState<T>();
}

class _MetaPickerSheetState<T> extends State<MetaPickerSheet<T>> {
  static const _recentLimit = 12;
  final _search = TextEditingController();
  late final _selected = {...?widget.initial};
  final _created = <String>{};
  bool _expanded = false;
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(T value) => Navigator.pop<MetaPickerResult<T>>(context, (
    selected: [value],
    created: [],
  ));

  Future<void> _createSingle(String query) async {
    setState(() => _creating = true);
    try {
      final value = await widget.onCreate!(query);
      if (mounted &&
          value != null &&
          ModalRoute.of(context)?.isCurrent == true) {
        _pick(value);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Widget _option(MSheetOption<T> option) {
    final multi = widget.initial != null;
    final selected = multi
        ? _selected.contains(option.value)
        : option.value == widget.selected;
    return MChip(
      label: option.label,
      leading: option.leading,
      selected: selected,
      size: widget.chipSize,
      onTap: option.enabled && !_creating
          ? () {
              if (!multi) return _pick(option.value);
              setState(() {
                if (selected) {
                  _selected.remove(option.value);
                } else {
                  _selected.add(option.value);
                }
              });
            }
          : null,
    );
  }

  Widget _removable(String label, VoidCallback remove) {
    void onRemove() => setState(remove);
    return MChip(
      label: label,
      selected: true,
      onTap: onRemove,
      onRemove: onRemove,
      removeTooltip: context.l10n.diary.tagRemove(name: label),
    );
  }

  Widget _createChip(String label, VoidCallback? create) => MChip(
    label: label,
    leading: const Icon(LucideIcons.plus, size: 16),
    variant: .ghost,
    size: widget.chipSize,
    onTap: create,
  );

  @override
  Widget build(BuildContext context) {
    final multi = widget.initial != null;
    final raw = _search.text.trim();
    final query = widget.normalizeName == null
        ? raw
        : widget.normalizeName!(raw) ?? '';
    final needle = query.toLowerCase();
    final options = widget.options;
    final matches = options.where(
      (option) => option.label.toLowerCase().contains(needle),
    );
    final pendingMatches = _created.where(
      (name) => query.isNotEmpty && name.toLowerCase().contains(needle),
    );
    final visible = multi && query.isEmpty && !_expanded
        ? matches.take(_recentLimit)
        : matches;
    final byValue = {for (final option in options) option.value: option};
    final selectedChips = [
      for (final value in _selected)
        if (byValue[value] case final option?)
          _removable(option.label, () => _selected.remove(value)),
      for (final name in _created)
        _removable(name, () => _created.remove(name)),
    ];
    final canCreateTag =
        multi &&
        query.isNotEmpty &&
        !options.any((option) => option.label.toLowerCase() == needle) &&
        !_created.any((name) => name.toLowerCase() == needle);
    return MSheetScaffold<MetaPickerResult<T>>(
      title: widget.title,
      subtitle:
          widget.selectionSubtitle?.call(_selected.length + _created.length) ??
          widget.subtitle,
      icon: widget.icon,
      actions: [
        MAction(label: context.l10n.common.cancel),
        if (multi)
          MAction(
            label: context.l10n.picker.done,
            isPrimary: true,
            enabled:
                _created.isNotEmpty || !setEquals(_selected, widget.initial),
            value: (selected: _selected.toList(), created: _created.toList()),
          ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          if (multi ||
              _search.text.isNotEmpty ||
              options.where((option) => option.value != null).length >= 8)
            SearchBar(
              controller: _search,
              hintText: widget.searchHint,
              leading: const Icon(LucideIcons.search),
              onChanged: (_) => setState(() {}),
            ),
          if (selectedChips.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: selectedChips),
          if (multi) const Divider(height: 1),
          if (multi && query.isEmpty && options.isEmpty) ...[
            Icon(
              LucideIcons.tag,
              size: 32,
              color: context.theme.colors.outline,
            ),
            Text(context.l10n.diary.tagEmpty, textAlign: .center),
            Text(context.l10n.diary.tagEmptyBody, textAlign: .center),
          ] else ...[
            if (query.isNotEmpty || multi)
              Text(
                query.isNotEmpty
                    ? widget.matchesLabel(
                        matches.length + pendingMatches.length,
                      )
                    : widget.recentLabel!,
                style: context.theme.typography.labelMedium.onSurfaceVariant,
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in visible) _option(option),
                for (final name in pendingMatches)
                  _removable(name, () => _created.remove(name)),
                if (canCreateTag)
                  _createChip(widget.tagCreateLabel!(query), () {
                    setState(() {
                      _created.add(query);
                      _search.clear();
                    });
                  }),
                if (widget.singleCreateLabel case final label?)
                  _createChip(
                    label,
                    _creating ? null : () => _createSingle(query),
                  ),
              ],
            ),
            if (multi &&
                query.isEmpty &&
                !_expanded &&
                options.length > _recentLimit)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MChip(
                  label: context.l10n.diary.tagShowAll(count: options.length),
                  trailing: const Icon(LucideIcons.chevronDown, size: 16),
                  variant: .ghost,
                  onTap: () => setState(() => _expanded = true),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
