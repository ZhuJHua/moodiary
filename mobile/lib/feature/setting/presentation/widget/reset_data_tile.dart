import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';

/// 不可逆清空全部数据。因清空后内存仍残留 Riverpod / get_it 状态（见 [resetAllData]），
/// 确认后退出应用，由用户重新打开走一次干净初始化。
class ResetDataTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const ResetDataTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(12) : Radius.zero,
          bottom: isLast ? const Radius.circular(12) : Radius.zero,
        ),
      ),
      leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
      title: Text(
        '重置所有数据',
        style: context.textTheme.bodyLarge?.copyWith(color: scheme.error),
      ),
      subtitle: Text(
        '清空全部日记、设置与媒体，不可恢复',
        style: context.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _confirmAndReset(context),
    );
  }

  Future<void> _confirmAndReset(BuildContext context) async {
    final scheme = context.colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
        title: const Text('重置所有数据'),
        content: const Text(
          '此操作将永久删除全部日记、分类、媒体文件、字体，以及所有设置'
          '（包括同步配置、加密密钥、应用锁密码等），且无法恢复。\n\n'
          '请确保已做好备份。确认后应用将自动关闭，请重新打开以完成重置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performReset();
  }

  Future<void> _performReset() async {
    toast.loading(message: '正在重置...');
    try {
      await resetAllData();
      await toast.dismiss();
      // 退出以从干净存储重新初始化
      await SystemNavigator.pop();
    } catch (e, s) {
      await toast.dismiss();
      logger.e('重置数据失败', error: e, stackTrace: s);
      toast.error(message: '重置失败');
    }
  }
}
