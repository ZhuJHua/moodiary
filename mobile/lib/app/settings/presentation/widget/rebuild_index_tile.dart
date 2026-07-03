import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';

class RebuildIndexTile extends ConsumerStatefulWidget {
  final bool isFirst;
  final bool isLast;

  const RebuildIndexTile({
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  ConsumerState<RebuildIndexTile> createState() => _RebuildIndexTileState();
}

class _RebuildIndexTileState extends ConsumerState<RebuildIndexTile> {
  bool _rebuilding = false;

  @override
  Widget build(BuildContext context) {
    return SettingListTile(
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      leading: const Icon(Icons.manage_search_rounded),
      title: '重建搜索索引',
      trailing: _rebuilding
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _rebuilding ? null : _rebuild,
    );
  }

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    toast.loading(message: '正在重建索引...');
    try {
      final count = await DiaryRepository.get().rebuildSearchIndex();
      await toast.dismiss();
      toast.success(message: '索引重建完成，共处理 $count 篇日记');
    } catch (e) {
      await toast.dismiss();
      logger.e('索引重建失败', error: e);
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }
}
