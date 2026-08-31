import 'dart:io';

import 'package:flutter/services.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mobile/app/di/bootstrap.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:mui/mui.dart';

/// 不可逆清空全部数据。清空后内存仍残留 Riverpod / get_it 状态（见 [resetAllData]），
/// 成功即 runApp 终态页接管界面、由用户手动重启走干净初始化；Android 顺带
/// SystemNavigator.pop 作为快捷退出（iOS 上 pop 是空操作，不能当契约）。
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
      // 内存单例已指向被清空的存储，必须立即接管界面（见 [resetAllData] 的契约），
      // 不能让用户留在旧 UI 里继续操作。iOS 上 SystemNavigator.pop 对标准 Flutter
      // 应用是空操作（root VC 不满足它的两条分支），所以终态页是主路径；
      // Android 的 Activity.finish() 真能退出，pop 作为快捷路径顺带调一次。
      runApp(const _ResetDonePage());
      if (Platform.isAndroid) await SystemNavigator.pop();
    } catch (e, s) {
      await toast.dismiss();
      logger.e('重置数据失败', error: e, stackTrace: s);
      toast.error(message: l10n.app.resetFailed);
    }
  }
}

/// 重置完成后的终态页：占满全屏、无返回路径，只提示手动重启。
class _ResetDonePage extends StatelessWidget {
  const _ResetDonePage();

  @override
  Widget build(BuildContext context) {
    // 此刻主题完好（与 BootFailurePage 不同），带上它——裸 MaterialApp 默认
    // 浅色，深色用户点完「清空」会闪一张纯白页，观感像崩溃。
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeManager().lightTheme,
      darkTheme: ThemeManager().darkTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.app.resetDone, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
