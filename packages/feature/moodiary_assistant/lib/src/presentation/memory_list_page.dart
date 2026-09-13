import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/memory_repository.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:mui/mui.dart';

const List<String> _kCategories = ['preference', 'theme', 'goal', 'fact'];

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
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.getAll();
    if (!mounted) return;
    setState(() => _all = all);
  }

  bool _isResident(MemoryEntry m) => m.pinned || m.category == 'preference';

  List<MemoryEntry> get _matched {
    final all = _all ?? const <MemoryEntry>[];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final m in all)
        if (m.text.toLowerCase().contains(q)) m,
    ];
  }

  Future<void> _togglePin(MemoryEntry m) async {
    final l10n = context.l10n;
    if (!m.pinned && await _repo.pinnedCount() >= memoryProfileLimit) {
      if (!mounted) return;
      toast.info(
        message: l10n.assistant.memoryPinFull(count: memoryProfileLimit),
      );
      return;
    }
    await _repo.setPinned(m.id, !m.pinned);
    await _load();
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
      title: l10n.assistant.memoryForgetTitle,
      message: l10n.assistant.memoryForgetMessage(text: m.text),
      confirmLabel: l10n.assistant.memoryForget,
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
                  Expanded(child: _Empty())
                else ...[
                  if (all.length > 6)
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
    final resident = [
      for (final m in matched)
        if (_isResident(m)) m,
    ]..sort(_byPinnedThenTime);
    final rest = [
      for (final m in matched)
        if (!_isResident(m)) m,
    ]..sort(_byPinnedThenTime);
    return ListView(
      padding: const .fromLTRB(12, 4, 12, 32),
      children: [
        if (resident.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.assistant.memoryResident,
            count: resident.length,
            description: l10n.assistant.memoryResidentDes,
          ),
          for (final m in resident) _tile(m),
        ],
        if (rest.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.assistant.memoryRest,
            count: rest.length,
            description: l10n.assistant.memoryRestDes,
          ),
          for (final m in rest) _tile(m),
        ],
      ],
    );
  }

  static int _byPinnedThenTime(MemoryEntry a, MemoryEntry b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  Widget _tile(MemoryEntry m) => _MemoryTile(
    entry: m,
    resident: _isResident(m),
    onTogglePin: () => _togglePin(m),
    onEdit: () => _edit(m),
    onForget: () => _forget(m),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final String description;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    return Padding(
      padding: const .fromLTRB(4, 14, 4, 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              Text(title, style: typography.labelMedium.emphasized.onSurface),
              const SizedBox(width: 8),
              Text(
                context.l10n.assistant.memoryCount(count: count),
                style: typography.labelSmall.onSurfaceVariant,
              ),
            ],
          ),
          Text(description, style: typography.labelSmall.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final MemoryEntry entry;
  final bool resident;
  final VoidCallback onTogglePin;
  final VoidCallback onEdit;
  final VoidCallback onForget;

  const _MemoryTile({
    required this.entry,
    required this.resident,
    required this.onTogglePin,
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
                        if (entry.pinned) ...[
                          Icon(
                            LucideIcons.pin,
                            size: 13,
                            color: colors.onSurface,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _KindChip(category: entry.category),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.assistant.memoryMeta(
                              date: _formatDate(entry.updatedAt.toLocal()),
                              source: _sourceLabel(context, entry.source),
                            ),
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
                    case 'pin':
                      onTogglePin();
                    case 'edit':
                      onEdit();
                    case 'forget':
                      onForget();
                  }
                },
                entries: [
                  MMenuEntry(
                    value: 'pin',
                    label: entry.pinned
                        ? l10n.assistant.memoryUnpin
                        : l10n.assistant.memoryPin,
                    icon: entry.pinned ? LucideIcons.pinOff : LucideIcons.pin,
                  ),
                  MMenuEntry(
                    value: 'edit',
                    label: l10n.assistant.memoryEdit,
                    icon: LucideIcons.squarePen,
                  ),
                  MMenuEntry(
                    value: 'forget',
                    label: l10n.assistant.memoryForget,
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

  static String _formatDate(DateTime t) => '${t.month}月${t.day}日';

  static String _sourceLabel(BuildContext context, String? source) =>
      source == 'user_asked'
      ? context.l10n.assistant.memorySourceAsked
      : context.l10n.assistant.memorySourceSaid;
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
        memoryCategoryLabel(context, category),
        style: context.theme.typography.labelSmall.onSurfaceVariant,
      ),
    );
  }
}

String memoryCategoryLabel(BuildContext context, String category) {
  final l10n = context.l10n;
  return switch (category) {
    'preference' => l10n.assistant.memoryKindPreference,
    'theme' => l10n.assistant.memoryKindTheme,
    'goal' => l10n.assistant.memoryKindGoal,
    _ => l10n.assistant.memoryKindFact,
  };
}

class _Empty extends StatelessWidget {
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
  late bool _pinned = widget.entry.pinned;
  int _pinnedOthers = 0;

  @override
  void initState() {
    super.initState();
    _countPinned();
  }

  Future<void> _countPinned() async {
    final total = await getIt<MemoryRepository>().pinnedCount();
    if (!mounted) return;
    setState(() => _pinnedOthers = total - (widget.entry.pinned ? 1 : 0));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final full = _pinnedOthers >= memoryProfileLimit;
    return MSheetScaffold<MemoryEntry>(
      title: l10n.assistant.memoryEditTitle,
      icon: LucideIcons.squarePen,
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(
          label: l10n.common.save,
          isPrimary: true,
          value: widget.entry.copyWith(
            text: _text.text.trim(),
            category: _category,
            pinned: _pinned,
          ),
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
                MChipData(value: c, label: memoryCategoryLabel(context, c)),
            ],
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      l10n.assistant.memoryPin,
                      style: context.theme.typography.bodyMedium.onSurface,
                    ),
                    Text(
                      full && !_pinned
                          ? l10n.assistant.memoryPinFull(
                              count: memoryProfileLimit,
                            )
                          : l10n.assistant.memoryPinDes(
                              count: memoryProfileLimit,
                            ),
                      style:
                          context.theme.typography.labelSmall.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pinned,
                onChanged: full && !_pinned
                    ? null
                    : (v) => setState(() => _pinned = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
