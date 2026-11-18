import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import '../application/reminder_service.dart';

Future<bool> ensureReminderPermission(
  BuildContext context,
  ReminderService service,
) async {
  if (await service.checkPermission()) return true;
  if (!context.mounted) return false;

  final proceed = await MAlert.confirm(
    context,
    title: context.l10n.reminder.primerTitle,
    message: context.l10n.reminder.primerMessage,
    icon: LucideIcons.bell,
    confirmLabel: context.l10n.reminder.continueAction,
    cancelLabel: context.l10n.reminder.notNow,
  );
  if (!proceed) return false;
  await service.permission.request();
  if (await service.checkPermission()) return true;
  if (!context.mounted) return false;
  final settings = await MAlert.confirm(
    context,
    title: context.l10n.reminder.notificationsOff,
    message: context.l10n.reminder.settingsMessage,
    icon: LucideIcons.bellOff,
    confirmLabel: context.l10n.reminder.openSettings,
    cancelLabel: context.l10n.reminder.notNow,
  );
  if (settings) await service.permission.openSettings();
  return false;
}
