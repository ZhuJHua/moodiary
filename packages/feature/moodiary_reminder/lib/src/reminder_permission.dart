import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'reminder_service.dart';

Future<bool> ensureReminderPermission(
  BuildContext context,
  ReminderService service,
) async {
  if (await service.checkPermission()) return true;
  if (!context.mounted) return false;

  Future<bool?> notice({
    required String title,
    required String message,
    required IconData icon,
    required String action,
  }) => MAlert.show<bool>(
    context,
    title: title,
    message: message,
    icon: icon,
    actions: [
      MAction(label: context.l10n.reminder.notNow, value: false),
      MAction(label: action, value: true, isPrimary: true),
    ],
  );
  final proceed = await notice(
    title: context.l10n.reminder.primerTitle,
    message: context.l10n.reminder.primerMessage,
    icon: LucideIcons.bell,
    action: context.l10n.reminder.continueAction,
  );
  if (proceed != true) return false;
  await service.permission.request();
  if (await service.checkPermission()) return true;
  if (!context.mounted) return false;
  final settings = await notice(
    title: context.l10n.reminder.notificationsOff,
    message: context.l10n.reminder.settingsMessage,
    icon: LucideIcons.bellOff,
    action: context.l10n.reminder.openSettings,
  );
  if (settings == true) await service.permission.openSettings();
  return false;
}
