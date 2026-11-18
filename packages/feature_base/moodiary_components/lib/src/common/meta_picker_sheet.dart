import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

typedef MetaPickerResult<T> = ({List<T> selected, List<String> created});

class MetaPickerSheet<T> extends StatefulWidget {
  const MetaPickerSheet.list({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.searchHint,
    required this.matchesLabel,
    required this.options,
    this.selected,
    this.createLabel,
  }) : initial = null,
       selectionSubtitle = null,
       selectedLabel = null,
       recentLabel = null,
       createHint = null,
       normalizeName = null;

  const MetaPickerSheet.wrap({
    super.key,
    required this.title,
    required this.selectionSubtitle,
    required this.icon,
    required this.searchHint,
    required this.matchesLabel,
    required this.options,
    required Set<T> this.initial,
    required this.selectedLabel,
    required this.recentLabel,
    this.createLabel,
    this.createHint,
    this.normalizeName,
  }) : selected = null,
       subtitle = null;

  final String title;
  final String? subtitle;
  final String Function(int)? selectionSubtitle;
  final IconData icon;
  final String searchHint;
  final String Function(int) matchesLabel;
  final List<MSheetOption<T>> options;
  final T? selected;
  final Set<T>? initial;
  final String? selectedLabel;
  final String? recentLabel;
  final String Function(String)? createLabel;
  final String? createHint;
  final String? Function(String)? normalizeName;

  @override
  State<MetaPickerSheet<T>> createState() => _MetaPickerSheetState<T>();
}

class _MetaPickerSheetState<T> extends State<MetaPickerSheet<T>> {
  final _search = TextEditingController();
  late final _selected = {...?widget.initial};
  final _created = <String>{};
  String _query = '';

  bool get _multi => widget.initial != null;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _create(String name) {
    if (!_multi) {
      Navigator.pop<MetaPickerResult<T>>(context, (
        selected: <T>[],
        created: [name],
      ));
      return;
    }
    setState(() {
      _created.add(name);
      _query = '';
      _search.clear();
    });
  }

  Widget _chip(String label, bool selected, VoidCallback toggle) {
    final colors = context.theme.colors;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      selectedColor: colors.secondaryContainer,
      side: BorderSide(
        color: selected ? Colors.transparent : colors.outlineVariant,
      ),
      onSelected: (_) => setState(toggle),
    );
  }

  Widget _option(MSheetOption<T> option) {
    if (!_multi) {
      return MSheetOptionTile<T>(
        option: option,
        selected: option.value == widget.selected,
        onTap: () => Navigator.pop<MetaPickerResult<T>>(context, (
          selected: [option.value],
          created: [],
        )),
      );
    }
    return _chip(option.label, _selected.contains(option.value), () {
      if (!_selected.remove(option.value)) _selected.add(option.value);
    });
  }

  Widget _pending(String name) =>
      _chip(name, true, () => _created.remove(name));

  Widget _section(List<Widget> children, {String? label}) => Column(
    crossAxisAlignment: .stretch,
    children: [
      if (label != null)
        Padding(
          padding: const .only(bottom: 8),
          child: Text(
            label,
            style: context.theme.typography.labelMedium.onSurfaceVariant,
          ),
        ),
      if (_multi)
        Wrap(spacing: 8, runSpacing: 8, children: children)
      else
        ...children,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final candidate = widget.normalizeName == null
        ? _query
        : widget.normalizeName!(_query);
    final query = (candidate ?? '').toLowerCase();
    final options = widget.options;
    final byValue = {for (final option in options) option.value: option};
    final matches = query.isEmpty && _multi
        ? <Widget>[]
        : [
            for (final option in options)
              if (option.label.toLowerCase().contains(query)) _option(option),
            for (final name in _created)
              if (name.toLowerCase().contains(query)) _pending(name),
          ];
    final canCreate =
        widget.createLabel != null &&
        candidate != null &&
        candidate.isNotEmpty &&
        ![
          ...options.map((option) => option.label),
          ..._created,
        ].any((label) => label.toLowerCase() == candidate.toLowerCase());

    return MSheetScaffold<MetaPickerResult<T>>(
      title: widget.title,
      subtitle:
          widget.selectionSubtitle?.call(_selected.length + _created.length) ??
          widget.subtitle,
      icon: widget.icon,
      actions: [
        MAction(label: context.l10n.common.cancel),
        if (_multi)
          MAction(
            label: context.l10n.picker.done,
            isPrimary: true,
            value: (selected: _selected.toList(), created: _created.toList()),
          ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 16,
        children: [
          SearchBar(
            controller: _search,
            hintText: widget.searchHint,
            leading: const Icon(LucideIcons.search),
            onChanged: (text) => setState(() => _query = text.trim()),
          ),
          if (query.isNotEmpty || !_multi)
            _section(
              matches,
              label: query.isEmpty ? null : widget.matchesLabel(matches.length),
            )
          else ...[
            _section([
              for (final value in _selected)
                if (byValue[value] case final option?) _option(option),
              for (final name in _created) _pending(name),
            ], label: widget.selectedLabel),
            _section([
              for (final option in options)
                if (!_selected.contains(option.value)) _option(option),
            ], label: widget.recentLabel),
          ],
          if (canCreate)
            CustomPaint(
              painter: _DashedOutline(context.theme.colors.outline),
              child: ListTile(
                leading: const Icon(LucideIcons.plus),
                title: Text(widget.createLabel!(candidate)),
                subtitle: widget.createHint == null
                    ? null
                    : Text(widget.createHint!),
                onTap: () => _create(candidate),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(MuiRadius.md.toRRect(Offset.zero & size).deflate(.5));
    final outline = path.computeMetrics().single;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = .stroke;
    for (double start = 0; start < outline.length; start += 8) {
      canvas.drawPath(outline.extractPath(start, start + 4), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedOutline oldDelegate) => oldDelegate.color != color;
}
