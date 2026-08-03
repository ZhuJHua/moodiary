import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';

/// 重推导预览/媒体引用、清除失效分类引用并重建索引。幂等，可反复执行。
class DataRepairTile extends ConsumerStatefulWidget {
  final bool isFirst;
  final bool isLast;

  const DataRepairTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  ConsumerState<DataRepairTile> createState() => _DataRepairTileState();
}

class _DataRepairTileState extends ConsumerState<DataRepairTile> {
  bool _repairing = false;

  @override
  Widget build(BuildContext context) {
    return SettingListTile(
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      leading: const Icon(LucideIcons.bandage),
      title: '数据修复',
      subtitle: '检查并修正卡片预览、媒体引用与失效分类',
      trailing: _repairing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.chevronRight),
      onTap: _repairing ? null : _confirmAndRepair,
    );
  }

  Future<void> _confirmAndRepair() async {
    final confirmed = await showMoodiaryConfirm(
      context,
      title: '数据修复',
      message:
          '将扫描全部日记，按正文重新生成卡片预览、媒体引用，并清理失效的分类引用，'
          '最后重建搜索索引。\n\n该操作只修正可从正文重算的衍生数据，不会改动你的正文内容。',
      confirmLabel: '开始修复',
    );
    if (!confirmed) return;
    await _repair();
  }

  Future<void> _repair() async {
    setState(() => _repairing = true);
    toast.loading(message: '正在修复数据...');
    try {
      final report = await DiaryRepository.get().repairData();
      await toast.dismiss();
      if (!mounted) return;
      await _showResult(report);
    } catch (e, s) {
      await toast.dismiss();
      logger.e('数据修复失败', error: e, stackTrace: s);
      if (mounted) toast.error(message: '数据修复失败');
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  Future<void> _showResult(DiaryRepairReport report) async {
    final lines = <String>[
      '共扫描 ${report.scanned} 篇日记。',
      if (!report.hasFix)
        '所有数据正常，无需修复。'
      else ...[
        '修复 ${report.changed} 篇：',
        if (report.contentTextFixed > 0) '· 卡片预览 ${report.contentTextFixed} 篇',
        if (report.mediaFixed > 0) '· 媒体引用 ${report.mediaFixed} 篇',
        if (report.orphanCategoryFixed > 0)
          '· 失效分类 ${report.orphanCategoryFixed} 篇',
      ],
      '搜索索引已重建（${report.reindexed} 篇）。',
    ];
    await showMoodiaryNotice(
      context,
      title: '修复完成',
      message: lines.join('\n'),
      closeLabel: '好',
    );
  }
}
