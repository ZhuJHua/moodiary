import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

/// 可视化「迁移到新编辑器」工具：把旧的 richText(Quill) / markdown 日记转换为 TipTap。
/// 列出待迁移日记（单篇或全部迁移），并列出已迁移项支持回退（转换前已备份原文）。
/// 旧日记打开时本就按转换结果渲染，等于常驻预览，故不再单设对比页。
class EditorMigrationPage extends StatefulWidget {
  const EditorMigrationPage({super.key});

  @override
  State<EditorMigrationPage> createState() => _EditorMigrationPageState();
}

class _EditorMigrationPageState extends State<EditorMigrationPage> {
  List<Diary>? _pending; // null = 加载中
  List<({MigrationBackup backup, Diary? diary})> _backups = [];
  bool _busy = false;
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await EditorMigrationService.pendingDiaries();
    final backups = await EditorMigrationService.backups();
    final repo = DiaryRepository.get();
    final resolved = <({MigrationBackup backup, Diary? diary})>[];
    for (final b in backups) {
      resolved.add((backup: b, diary: await repo.getDiaryByBusinessId(b.id)));
    }
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _backups = resolved;
    });
  }

  Future<void> _migrateAll() async {
    final pending = _pending;
    if (pending == null || pending.isEmpty) return;
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.editor.migrationTitle,
      message: l10n.editor.migrationMessage(count: pending.length),
      confirmLabel: l10n.editor.migrationStart,
    );
    if (!confirmed) return;
    setState(() {
      _busy = true;
      _done = 0;
      _total = pending.length;
    });
    try {
      final report = await EditorMigrationService.migrateAll(
        pending,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      await _load();
      if (!mounted) return;
      toast.success(
        message: report.failed == 0
            ? l10n.editor.migrationDone(count: report.migrated)
            : l10n.editor.migrationPartial(
                count: report.migrated,
                failed: report.failed,
              ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _migrateOne(Diary diary) async {
    setState(() => _busy = true);
    try {
      final ok = await EditorMigrationService.migrate(diary);
      await _load();
      if (!mounted) return;
      ok
          ? toast.success(message: l10n.editor.migrationOneDone)
          : toast.error(message: l10n.editor.migrationOneFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revert(({MigrationBackup backup, Diary? diary}) item) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.editor.rollbackTitle,
      message: l10n.editor.rollbackMessage,
      confirmLabel: l10n.editor.rollbackConfirm,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final ok = await EditorMigrationService.revert(item.backup.id);
      await _load();
      if (!mounted) return;
      ok
          ? toast.success(message: l10n.editor.rollbackDone)
          : toast.error(message: l10n.editor.rollbackFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editor.migrationTitle)),
      bottomNavigationBar: _bottomBar(pending),
      body: pending == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const .symmetric(vertical: 8),
              children: [
                _section(
                  context.l10n.editor.migrationPending(count: pending.length),
                ),
                if (pending.isEmpty)
                  Padding(
                    padding: const .fromLTRB(16, 8, 16, 16),
                    child: Text(context.l10n.editor.migrationEmpty),
                  )
                else
                  for (final d in pending)
                    ListTile(
                      leading: const Icon(LucideIcons.notebookText),
                      title: Text(_label(d), maxLines: 1, overflow: .ellipsis),
                      subtitle: Text(_date(d.time)),
                      trailing: IconButton(
                        tooltip: context.l10n.editor.migrateThisOne,
                        icon: const Icon(LucideIcons.arrowRight),
                        onPressed: _busy ? null : () => _migrateOne(d),
                      ),
                    ),
                if (_backups.isNotEmpty) ...[
                  _section(context.l10n.editor.migrationMigrated),
                  for (final item in _backups)
                    ListTile(
                      leading: const Icon(LucideIcons.history),
                      title: Text(
                        item.diary == null
                            ? context.l10n.editor.diaryDeleted
                            : _label(item.diary!),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                      subtitle: Text(
                        context.l10n.editor.migratedAt(
                          date: _date(item.backup.savedAt),
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _revert(item),
                        child: Text(context.l10n.editor.rollbackConfirm),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget? _bottomBar(List<Diary>? pending) {
    if (pending == null || pending.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const .all(12),
        child: _busy
            ? Column(
                mainAxisSize: .min,
                children: [
                  LinearProgressIndicator(
                    value: _total == 0 ? null : _done / _total,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.editor.migrationProgress(
                      done: _done,
                      total: _total,
                    ),
                  ),
                ],
              )
            : FilledButton.icon(
                onPressed: _migrateAll,
                icon: const Icon(LucideIcons.wandSparkles),
                label: Text(
                  context.l10n.editor.migrateAll(count: pending.length),
                ),
              ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const .fromLTRB(16, 16, 16, 4),
      child: Text(title, style: context.theme.typography.labelMedium.primary),
    );
  }

  static String _label(Diary d) {
    final t = d.title.trim();
    if (t.isNotEmpty) return t;
    final c = d.contentText.trim();
    if (c.isEmpty) return l10n.editor.emptyDiary;
    return c.length > 30 ? '${c.substring(0, 30)}…' : c;
  }

  static String _date(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
