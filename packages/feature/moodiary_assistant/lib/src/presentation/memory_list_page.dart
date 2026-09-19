import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

const List<String> _kCategories = ['preference', 'theme', 'goal', 'fact'];

const int _kSearchThreshold = 6;

class MemoryListPage extends StatefulWidget {
  const MemoryListPage({super.key});

  @override
  State<MemoryListPage> createState() => _MemoryListPageState();
}

class _MemoryListPageState extends State<MemoryListPage> {
  final _repo = getIt<MemoryRepository>();
  final _search = TextEditingController();
  List<MemoryEntry>? _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _repo.getAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      if (all.length <= _kSearchThreshold) {
        _search.clear();
        _query = '';
      }
    });
  }

  List<MemoryEntry> get _matched {
    final all = _all ?? const <MemoryEntry>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final m in all)
        if (m.text.toLowerCase().contains(q)) m,
    ];
  }

  Future<void> _edit(MemoryEntry m) async {
    final edited = await MSheet.show<MemoryEntry>(
      context,
      builder: (_) => _MemoryEditSheet(entry: m),
    );
    if (edited == null) return;
    await _repo.put(edited.copyWith(updatedAt: DateTime.timestamp()));
    await _load();
  }

  Future<void> _forget(MemoryEntry m) async {
    final l10n = context.l10n;
    final ok = await MAlert.confirm(
      context,
      title: l10n.assistant.memoryDeleteTitle,
      message: l10n.assistant.memoryDeleteMessage(text: m.text),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
      icon: LucideIcons.trash2,
    );
    if (!ok) return;
    await _repo.delete(m.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final l10n = context.l10n;
    final ok = await MAlert.confirm(
      context,
      title: l10n.assistant.memoryClearTitle,
      message: l10n.assistant.memoryClearMessage,
      confirmLabel: l10n.assistant.memoryClearConfirm,
      isDestructive: true,
      icon: LucideIcons.trash2,
    );
    if (!ok) return;
    await _repo.clearAll();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = _all;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistant.memoryTitle),
        actions: [
          if (all != null && all.isNotEmpty)
            MMenuButton<String>(
              tooltip: l10n.common.more,
              onSelected: (_) => _clearAll(),
              entries: [
                MMenuEntry(
                  value: 'clear',
                  label: l10n.assistant.memoryClearConfirm,
                  icon: LucideIcons.trash2,
                  isDestructive: true,
                ),
              ],
              child: const Padding(
                padding: .all(12),
                child: Icon(LucideIcons.ellipsisVertical),
              ),
            ),
        ],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const .fromLTRB(16, 0, 16, 10),
                  child: Text(
                    l10n.assistant.memoryLede,
                    style: context.theme.typography.bodySmall.onSurfaceVariant,
                  ),
                ),
                if (all.isEmpty)
                  const Expanded(child: _Empty())
                else ...[
                  if (all.length > _kSearchThreshold)
                    Padding(
                      padding: const .fromLTRB(12, 2, 12, 6),
                      child: MField(
                        controller: _search,
                        hintText: l10n.assistant.memorySearchHint,
                        trailing: const Icon(LucideIcons.search),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  Expanded(child: _buildList()),
                ],
              ],
            ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    final matched = _matched;
    if (matched.isEmpty) {
      return Center(
        child: Text(
          l10n.assistant.memoryNoMatch,
          style: context.theme.typography.bodyMedium.onSurfaceVariant,
        ),
      );
    }
    return ListView(
      padding: const .fromLTRB(12, 4, 12, 32),
      children: [for (final m in matched) _tile(m)],
    );
  }

  Widget _tile(MemoryEntry m) =>
      _MemoryTile(entry: m, onEdit: () => _edit(m), onForget: () => _forget(m));
}

class _MemoryTile extends StatelessWidget {
  final MemoryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onForget;

  const _MemoryTile({
    required this.entry,
    required this.onEdit,
    required this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    return Card.filled(
      margin: const .symmetric(vertical: 4),
      color: colors.surfaceContainerLow,
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onEdit,
        child: Padding(
          padding: const .fromLTRB(16, 14, 8, 12),
          child: Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(entry.text, style: typography.bodyMedium.onSurface),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _KindChip(category: entry.category),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            switch (_sourceLabel(l10n, entry.source)) {
                              final source? => l10n.assistant.memoryMeta(
                                date: TimeFormat.monthDay(entry.updatedAt),
                                source: source,
                              ),
                              null => TimeFormat.monthDay(entry.updatedAt),
                            },
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: typography.labelSmall.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              MMenuButton<String>(
                tooltip: l10n.common.more,
                onSelected: (key) {
                  switch (key) {
                    case 'edit':
                      onEdit();
                    case 'forget':
                      onForget();
                  }
                },
                entries: [
                  MMenuEntry(
                    value: 'edit',
                    label: l10n.assistant.memoryEdit,
                    icon: LucideIcons.squarePen,
                  ),
                  MMenuEntry(
                    value: 'forget',
                    label: l10n.common.delete,
                    icon: LucideIcons.trash2,
                    isDestructive: true,
                  ),
                ],
                child: Padding(
                  padding: const .all(12),
                  child: Icon(
                    LucideIcons.ellipsisVertical,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _sourceLabel(Translations l10n, String? source) =>
      switch (source) {
        'user_asked' => l10n.assistant.memorySourceAsked,
        'user_said' => l10n.assistant.memorySourceSaid,
        _ => null,
      };
}

class _KindChip extends StatelessWidget {
  final String category;

  const _KindChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: .circular(999),
      ),
      child: Text(
        _memoryCategoryLabel(context, category),
        style: context.theme.typography.labelSmall.onSurfaceVariant,
      ),
    );
  }
}

String _memoryCategoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    'preference' => l10n.assistant.memoryKindPreference,
    'theme' => l10n.assistant.memoryKindTheme,
    'goal' => l10n.assistant.memoryKindGoal,
    _ => l10n.assistant.memoryKindFact,
  };
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.theme.colors;
    return Center(
      child: Padding(
        padding: const .symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(LucideIcons.brain, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              l10n.assistant.memoryEmpty,
              style: context.theme.typography.titleMedium.onSurface,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.assistant.memoryEmptyDes,
              textAlign: .center,
              style: context.theme.typography.bodySmall.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryEditSheet extends StatefulWidget {
  final MemoryEntry entry;

  const _MemoryEditSheet({required this.entry});

  @override
  State<_MemoryEditSheet> createState() => _MemoryEditSheetState();
}

class _MemoryEditSheetState extends State<_MemoryEditSheet> {
  late final _text = TextEditingController(text: widget.entry.text);
  late String _category = widget.entry.category;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = _text.text.trim();
    return MSheetScaffold<MemoryEntry>(
      title: l10n.assistant.memoryEditTitle,
      icon: LucideIcons.squarePen,
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(
          label: l10n.common.save,
          isPrimary: true,
          enabled: text.isNotEmpty,
          onPressed: () =>
              Navigator.of(context)
                  .pop(widget.entry.copyWith(text: text, category: _category)),
        ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          MField(
            controller: _text,
            maxLines: 3,
            label: l10n.assistant.memoryFieldText,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.assistant.memoryFieldKind,
            style: context.theme.typography.labelSmall.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          MChipBar<String>(
            padding: .zero,
            items: [
              for (final c in _kCategories)
                MChipData(value: c, label: _memoryCategoryLabel(context, c)),
            ],
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
        ],
      ),
    );
  }
}
