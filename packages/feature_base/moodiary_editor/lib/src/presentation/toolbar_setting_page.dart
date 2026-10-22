import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import '../toolbar/editor_toolbar.dart';
import '../toolbar/toolbar_tools.dart';

class ToolbarSettingPage extends StatefulWidget {
  const ToolbarSettingPage({super.key});

  @override
  State<ToolbarSettingPage> createState() => _ToolbarSettingPageState();
}

enum _Menu { reset }

class _ToolbarSettingPageState extends State<ToolbarSettingPage> {
  List<ToolbarTool> _shown = ToolbarPrefs.load();

  Set<ToolbarTool>? _removing;

  void _update(List<ToolbarTool> shown) {
    setState(() => _shown = shown);
    ToolbarPrefs.save(shown);
  }

  void _reset() {
    ToolbarPrefs.reset();
    setState(() => _shown = ToolbarPrefs.load());
  }

  void _reorder(int from, int to) {
    final shown = [..._shown];
    shown.insert(to, shown.removeAt(from));
    _update(shown);
  }

  void _toggle(ToolbarTool tool) => setState(() {
    final removing = _removing!;
    if (!removing.remove(tool)) removing.add(tool);
  });

  void _removeSelected() {
    final removing = _removing!;
    _update([
      for (final tool in _shown)
        if (!removing.contains(tool)) tool,
    ]);
    setState(() => _removing = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n.editor.toolbar;
    final colors = context.theme.colors;
    final removing = _removing;
    final available = [
      for (final tool in ToolbarTool.values)
        if (!_shown.contains(tool)) tool,
    ];
    return PopScope(
      canPop: removing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _removing = null);
      },
      child: Scaffold(
        appBar: removing == null
            ? AppBar(
                title: Text(t.settingsTitle),
                actions: [
                  if (_shown.isNotEmpty)
                    IconButton(
                      tooltip: t.removeTools,
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () => setState(() => _removing = {}),
                    ),
                  MMenuButton<_Menu>(
                    tooltip: context.l10n.common.more,
                    onSelected: (_) => _reset(),
                    entries: [
                      MMenuEntry(
                        value: .reset,
                        label: t.resetDefault,
                        icon: LucideIcons.rotateCcw,
                      ),
                    ],
                    child: const Padding(
                      padding: .all(12),
                      child: Icon(LucideIcons.ellipsisVertical),
                    ),
                  ),
                ],
              )
            : AppBar(
                leading: CloseButton(
                  onPressed: () => setState(() => _removing = null),
                ),
                title: Text(t.selectedCount(count: removing.length)),
                actions: [
                  TextButton(
                    onPressed: removing.isEmpty ? null : _removeSelected,
                    child: Text(t.remove),
                  ),
                ],
              ),
        body: Padding(
          padding: const .symmetric(horizontal: 8),
          child: CustomScrollView(
            slivers: [
              MSliverSettingGroup(
                title: t.preview,
                children: [
                  _Preview(tools: _shown, dimmed: removing ?? const {}),
                ],
              ),
              if (_shown.isNotEmpty)
                MSliverReorderableSettingGroup(
                  title: t.shownSection,
                  items: _shown,
                  onReorder: _reorder,
                  reorderable: removing == null,
                  itemBuilder: (context, tool, handle) {
                    final selected = removing?.contains(tool) ?? false;
                    return SettingListTile(
                      leading: Icon(tool.icon),
                      title: tool.label(context),
                      tileColor: selected ? colors.secondaryContainer : null,
                      onTap: removing == null ? null : () => _toggle(tool),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: removing == null
                            ? handle
                            : Checkbox(
                                shape: const CircleBorder(),
                                value: selected,
                                onChanged: (_) => _toggle(tool),
                              ),
                      ),
                      contentPadding: const .only(left: 16, right: 4),
                    );
                  },
                ),
              if (removing == null && available.isNotEmpty)
                MSliverSettingGroup(
                  title: t.availableSection,
                  children: [
                    for (final tool in available)
                      SettingListTile(
                        leading: Icon(tool.icon),
                        title: tool.label(context),
                        trailing: IconButton(
                          tooltip: t.addToToolbar,
                          icon: const Icon(LucideIcons.plus),
                          onPressed: () => _update([..._shown, tool]),
                        ),
                        onTap: () => _update([..._shown, tool]),
                        contentPadding: const .only(left: 16, right: 4),
                      ),
                  ],
                ),
              SliverToBoxAdapter(child: SizedBox(height: context.safeBottom)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final List<ToolbarTool> tools;
  final Set<ToolbarTool> dimmed;

  const _Preview({required this.tools, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    Widget icon(IconData data, {bool dim = false}) => SizedBox.square(
      dimension: 40,
      child: AnimatedOpacity(
        opacity: dim ? 0.3 : 1,
        duration: const Duration(milliseconds: 150),
        child: Icon(data, size: 20, color: colors.onSurface),
      ),
    );
    return Padding(
      padding: const .symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: EdgeFadeScroll(
              child: Row(
                spacing: 2,
                children: [
                  for (final tool in tools)
                    icon(tool.icon, dim: dimmed.contains(tool)),
                ],
              ),
            ),
          ),
          if (tools.isNotEmpty)
            Container(
              width: 1,
              height: 22,
              margin: const .symmetric(horizontal: 4),
              color: colors.outlineVariant,
            ),
          icon(LucideIcons.chevronDown),
        ],
      ),
    );
  }
}
