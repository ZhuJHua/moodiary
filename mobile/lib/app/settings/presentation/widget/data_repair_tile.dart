import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';

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
      title: context.l10n.app.repairTitle,
      subtitle: context.l10n.app.repairSubtitle,
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
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.repairTitle,
      message: l10n.app.repairMessage,
      confirmLabel: l10n.app.repairStart,
    );
    if (!confirmed) return;
    await _repair();
  }

  Future<void> _repair() async {
    setState(() => _repairing = true);
    toast.loading(message: l10n.app.repairRunning);
    try {
      final report = await DiaryRepository.get().repairData();
      await toast.dismiss();
      if (!mounted) return;
      await _showResult(report);
    } catch (e, s) {
      await toast.dismiss();
      logger.e('数据修复失败', error: e, stackTrace: s);
      if (mounted) toast.error(message: l10n.app.repairFailed);
    } finally {
      if (mounted) setState(() => _repairing = false);
    }
  }

  Future<void> _showResult(DiaryRepairReport report) async {
    final lines = <String>[
      l10n.app.repairScanned(count: report.scanned),
      if (!report.hasFix)
        l10n.app.repairAllGood
      else ...[
        l10n.app.repairFixed(count: report.changed),
        if (report.contentTextFixed > 0)
          l10n.app.repairFixedPreview(count: report.contentTextFixed),
        if (report.mediaFixed > 0)
          l10n.app.repairFixedMedia(count: report.mediaFixed),
        if (report.orphanCategoryFixed > 0)
          l10n.app.repairFixedOrphan(count: report.orphanCategoryFixed),
      ],
      l10n.app.repairReindexed(count: report.reindexed),
    ];
    await MAlert.notice(
      context,
      title: l10n.app.repairDoneTitle,
      message: lines.join('\n'),
      closeLabel: l10n.app.repairOk,
    );
  }
}
