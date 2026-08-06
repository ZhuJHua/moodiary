import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

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
        borderRadius: .vertical(
          top: isFirst ? const .circular(12) : .zero,
          bottom: isLast ? const .circular(12) : .zero,
        ),
      ),
      leading: Icon(LucideIcons.trash2, color: scheme.error),
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
    final confirmed = await showMoodiaryConfirm(
      context,
      title: '重置所有数据',
      message:
          '此操作将永久删除全部日记、分类、媒体文件、字体，以及所有设置'
          '（包括同步配置、加密密钥、应用锁密码等），且无法恢复。\n\n'
          '请确保已做好备份。确认后应用将自动关闭，请重新打开以完成重置。',
      confirmLabel: '确认重置',
      isDestructive: true,
      icon: LucideIcons.triangleAlert,
    );
    if (!confirmed) return;
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
