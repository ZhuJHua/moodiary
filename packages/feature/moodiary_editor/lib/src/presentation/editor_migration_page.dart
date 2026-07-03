import 'package:flutter/material.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_editor/src/presentation/widget/migration_compare_page.dart';

/// 可视化「迁移到新编辑器」工具：把旧的 richText(Quill) 日记转换为 TipTap/markdown。
/// 列出待迁移日记（可逐条预览转换结果、单篇或全部迁移），并列出已迁移项支持回退
/// （转换前已备份原始 Delta）。
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
    final confirmed = await _confirmMigrate(pending.length);
    if (confirmed != true) return;
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
            ? '已迁移 ${report.migrated} 篇'
            : '迁移 ${report.migrated} 篇，${report.failed} 篇失败（已跳过，原文未动）',
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
          ? toast.success(message: '已迁移')
          : toast.error(message: '该篇解析失败，已跳过');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revert(({MigrationBackup backup, Diary? diary}) item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('回退迁移'),
        content: const Text(
          '将这篇恢复为迁移前的旧编辑器格式，并删除备份。'
          '\n\n注意：迁移之后对该篇做的修改会丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('回退'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final ok = await EditorMigrationService.revert(item.backup.id);
      await _load();
      if (!mounted) return;
      ok ? toast.success(message: '已回退') : toast.error(message: '回退失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 左右对比预览（右侧为新编辑器真实渲染）；在对比页里迁移成功后回 true，刷新列表。
  Future<void> _preview(Diary diary) async {
    final migrated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MigrationComparePage(diary: diary),
      ),
    );
    if (migrated == true && mounted) await _load();
  }

  Future<bool?> _confirmMigrate(int count) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('迁移到新编辑器'),
        content: Text(
          '将 $count 篇旧编辑器日记转换为新编辑器格式（markdown）。'
          '\n\n· 文字、标题、列表、引用、代码、图片、音频、视频都会保留；'
          '\n· 文字颜色 / 高亮 / 对齐无法在新格式中表示，会被丢弃；'
          '\n· 转换前会备份原文，可随时回退。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('开始迁移'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Scaffold(
      appBar: AppBar(title: const Text('迁移到新编辑器')),
      bottomNavigationBar: _bottomBar(pending),
      body: pending == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _section('待迁移（${pending.length}）'),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text('没有需要迁移的旧编辑器日记 🎉'),
                  )
                else
                  for (final d in pending)
                    ListTile(
                      leading: const Icon(Icons.feed_outlined),
                      title: Text(_label(d), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_date(d.time)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '预览转换结果',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: _busy ? null : () => _preview(d),
                          ),
                          IconButton(
                            tooltip: '迁移这一篇',
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: _busy ? null : () => _migrateOne(d),
                          ),
                        ],
                      ),
                    ),
                if (_backups.isNotEmpty) ...[
                  _section('已迁移（可回退）'),
                  for (final item in _backups)
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        item.diary == null ? '(已删除)' : _label(item.diary!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('迁移于 ${_date(item.backup.savedAt)}'),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _revert(item),
                        child: const Text('回退'),
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
        padding: const EdgeInsets.all(12),
        child: _busy
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _total == 0 ? null : _done / _total,
                  ),
                  const SizedBox(height: 6),
                  Text('正在迁移 $_done / $_total'),
                ],
              )
            : FilledButton.icon(
                onPressed: _migrateAll,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text('全部迁移（${pending.length}）'),
              ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  static String _label(Diary d) {
    final t = d.title.trim();
    if (t.isNotEmpty) return t;
    final c = d.contentText.trim();
    if (c.isEmpty) return '(空日记)';
    return c.length > 30 ? '${c.substring(0, 30)}…' : c;
  }

  static String _date(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
