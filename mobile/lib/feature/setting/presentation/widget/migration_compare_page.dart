import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/edit/presentation/widget/editor_body.dart';
import 'package:moodiary/feature/edit/presentation/widget/moodiary_editor_view.dart';
import 'package:moodiary/feature/setting/data/editor_migration_service.dart';

/// 迁移「左右对比」预览：左侧是原始渲染（richText→只读 Quill，markdown→只读 TipTap 读 markdown），
/// 右侧是**新编辑器（TipTap）只读渲染**转换后的内容 —— 即迁移后的真实样子。
///
/// 右侧内容同步算出、无需无头服务：richText 走 [QuillDeltaToTiptap]、markdown 走 [MarkdownToTiptap]
/// （均纯 Dart，Delta/md→JSON，与落库结果一致）。点「迁移这一篇」落库（可回退），返回 true 让列表刷新。
class MigrationComparePage extends StatefulWidget {
  final Diary diary;

  const MigrationComparePage({super.key, required this.diary});

  @override
  State<MigrationComparePage> createState() => _MigrationComparePageState();
}

class _MigrationComparePageState extends State<MigrationComparePage> {
  /// 右侧（迁移后）喂给 TipTap 的内容：转换后的文档 JSON 串（richText / markdown 均已转 JSON）。
  String? _rightContent;
  bool _failed = false;
  bool _migrating = false;

  @override
  void initState() {
    super.initState();
    final diary = widget.diary;
    switch (DiaryType.fromValue(diary.type)) {
      case DiaryType.richText:
        _rightContent = QuillDeltaToTiptap.convert(diary.content);
        _failed = _rightContent == null || _rightContent!.isEmpty;
      case DiaryType.markdown:
        _rightContent = MarkdownToTiptap.convert(diary.content);
        _failed = _rightContent == null || _rightContent!.isEmpty;
      case DiaryType.tiptap:
        _rightContent = diary.content;
    }
  }

  Future<void> _migrate() async {
    setState(() => _migrating = true);
    bool ok = false;
    try {
      ok = await EditorMigrationService.migrate(widget.diary);
    } finally {
      if (mounted) setState(() => _migrating = false);
    }
    if (!mounted) return;
    if (ok) {
      toast.success(message: '已迁移');
      Navigator.of(context).pop(true);
    } else {
      toast.error(message: '迁移失败（已跳过，原文未改动）');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('迁移预览'),
        actions: [
          if (!_failed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _migrating
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _migrate,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('迁移这一篇'),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final before = _pane(
              context,
              label: '迁移前（旧格式）',
              child: EditorBody(
                type: DiaryType.fromValue(widget.diary.type),
                initialContent: widget.diary.content,
                editable: false,
                onChanged: (_, _) {},
              ),
            );
            final after = _pane(
              context,
              label: '迁移后（新编辑器）',
              child: _afterChild(),
            );
            // 宽屏左右对比，窄屏上下堆叠。
            if (constraints.maxWidth >= 720) {
              return Row(
                children: [
                  Expanded(child: before),
                  const VerticalDivider(width: 1),
                  Expanded(child: after),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: before),
                const Divider(height: 1),
                Expanded(child: after),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _afterChild() {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('无法转换此篇（迁移时会跳过，不改动原文）', textAlign: TextAlign.center),
        ),
      );
    }
    return MoodiaryEditorView(
      key: ValueKey('migrate-after-${widget.diary.id}'),
      initialContent: _rightContent!,
      editable: false,
      onChanged: (_) {},
    );
  }

  Widget _pane(BuildContext context, {required String label, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: scheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
