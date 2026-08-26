import 'package:flutter/services.dart';
import 'package:moodiary/app/di/bootstrap.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:mui/mui.dart';

/// 不可逆清空全部数据。因清空后内存仍残留 Riverpod / get_it 状态（见 [resetAllData]），
/// 确认后退出应用，由用户重新打开走一次干净初始化。
class ResetDataTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const ResetDataTile({super.key, this.isFirst = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    // 走 SettingListTile 而不是裸 ListTile：圆角与组内分隔线都归它管，自绘就漏掉了。
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(LucideIcons.trash2, color: scheme.error),
      title: Text(
        context.l10n.app.resetTitle,
        style: context.theme.typography.bodyLarge.error,
      ),
      subtitle: context.l10n.app.resetSubtitle,
      onTap: () => _confirmAndReset(context),
    );
  }

  Future<void> _confirmAndReset(BuildContext context) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.resetTitle,
      message: l10n.app.resetMessage,
      confirmLabel: l10n.app.resetConfirm,
      isDestructive: true,
      icon: LucideIcons.triangleAlert,
    );
    if (!confirmed) return;
    await _performReset();
  }

  Future<void> _performReset() async {
    toast.loading(message: l10n.app.resetRunning);
    try {
      await resetAllData();
      await toast.dismiss();
      // 退出以从干净存储重新初始化
      await SystemNavigator.pop();
    } catch (e, s) {
      await toast.dismiss();
      logger.e('重置数据失败', error: e, stackTrace: s);
      toast.error(message: l10n.app.resetFailed);
    }
  }
}
