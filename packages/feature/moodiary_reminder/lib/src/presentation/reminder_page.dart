import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

import '../application/reminder_service.dart';
import '../data/reminder.dart';
import 'reminder_edit_sheet.dart';
import 'reminder_labels.dart';
import 'reminder_permission.dart';

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});
  factory ReminderPage.fromRoute(GoRouterState state) => const ReminderPage();

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  late final _service = ref.read(reminderServiceProvider);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run(_service.checkPermission);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } catch (error, stack) {
      logger.e('Reminder action failed', error: error, stackTrace: stack);
      if (mounted) toast.error(message: context.l10n.reminder.failed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _edit([Reminder? reminder]) async {
    final items = _service.reminders;
    final id =
        reminder?.id ??
        List.generate(
          Reminder.maxCount,
          (index) => index + 1,
        ).firstWhere((id) => !items.any((item) => item.id == id));
    final result = await MSheet.show<ReminderEditResult>(
      context,
      builder: (_) => ReminderEditSheet(id: id, reminder: reminder),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      await _service.remove(id);
    } else if (result.reminder case final updated?) {
      final allowed =
          items.isEmpty && await ensureReminderPermission(context, _service);
      await _service.save(updated);
      if (allowed) await _service.setEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(reminderStateProvider);
    final theme = context.theme;
    final items = state.reminders;
    final canAdd = items.length < Reminder.maxCount;
    final addColor = canAdd
        ? theme.colors.primary
        : theme.colors.onSurfaceVariant;
    final summary = reminderStatusLabel(l10n, state);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminder.title)),
      body: Padding(
        padding: const .symmetric(horizontal: 16),
        child: CustomScrollView(
          slivers: [
            if (state.enabled && !state.notificationsEnabled)
              SliverPadding(
                padding: const .only(bottom: 12),
                sliver: SliverToBoxAdapter(
                  child: MCallout(
                    level: .error,
                    icon: LucideIcons.bellOff,
                    title: l10n.reminder.notificationsOff,
                    message: l10n.reminder.notificationsOffHint,
                    actionLabel: l10n.reminder.enableNotifications,
                    onAction: () => _run(() async {
                      await ensureReminderPermission(context, _service);
                    }),
                  ),
                ),
              ),
            MSliverSettingGroup(
              children: [
                SettingSwitchListTile(
                  title: l10n.reminder.enable,
                  subtitle: summary,
                  secondary: const Icon(LucideIcons.bell),
                  value: state.enabled,
                  onChanged: items.isEmpty
                      ? null
                      : (enabled) => _run(() async {
                          if (!enabled ||
                              await ensureReminderPermission(
                                context,
                                _service,
                              )) {
                            await _service.setEnabled(enabled);
                          }
                        }),
                ),
              ],
            ),
            MSliverSettingGroup(
              title: l10n.reminder.times,
              children: [
                ...items.map((reminder) {
                  final days = reminderDaysLabel(l10n, reminder.weekdays);
                  final color = state.enabled && reminder.enabled
                      ? theme.colors.onSurface
                      : theme.colors.onSurfaceVariant;
                  return SettingListTile(
                    leading: Icon(LucideIcons.alarmClock, color: color),
                    title: Text(
                      reminder.time,
                      style: theme.typography.titleLarge
                          .withColor(color)
                          .tabular,
                    ),
                    subtitle: days,
                    trailing: Switch(
                      value: reminder.enabled,
                      onChanged: (enabled) => _run(
                        () => _service.save(reminder.withEnabled(enabled)),
                      ),
                    ),
                    onTap: () => _run(() => _edit(reminder)),
                  );
                }),
                SettingListTile(
                  title: Text(
                    l10n.reminder.add,
                    style: theme.typography.bodyLarge.withColor(addColor),
                  ),
                  leading: Icon(LucideIcons.plus, color: addColor),
                  onTap: canAdd ? () => _run(_edit) : null,
                ),
              ],
            ),
            if (Platform.isAndroid)
              SliverPadding(
                padding: const .only(top: 12),
                sliver: SliverToBoxAdapter(
                  child: MCallout(message: l10n.reminder.autostartHint),
                ),
              ),
            MSliverSettingGroup(
              title: l10n.reminder.notifications,
              children: [
                SettingListTile(
                  title: l10n.reminder.tapAction,
                  leading: const Icon(LucideIcons.mousePointerClick),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.tapAction == ReminderTapAction.openApp
                            ? l10n.reminder.openApp
                            : l10n.reminder.newDiary,
                        style: theme.typography.bodyMedium.withColor(
                          theme.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.chevronRight, size: 20),
                    ],
                  ),
                  onTap: () => _run(() async {
                    final picked = await MSheet.picker<ReminderTapAction>(
                      context,
                      title: l10n.reminder.tapAction,
                      selected: state.tapAction,
                      options: [
                        MSheetOption(
                          value: ReminderTapAction.openApp,
                          label: l10n.reminder.openApp,
                        ),
                        MSheetOption(
                          value: ReminderTapAction.newDiary,
                          label: l10n.reminder.newDiary,
                        ),
                      ],
                    );
                    if (picked != null) _service.setTapAction(picked);
                  }),
                ),
                SettingListTile(
                  title: l10n.reminder.test,
                  leading: const Icon(LucideIcons.send),
                  onTap: () => _run(() async {
                    if (!await ensureReminderPermission(context, _service)) {
                      return;
                    }
                    await _service.sendTest();
                    if (context.mounted) {
                      toast.success(message: context.l10n.reminder.testSent);
                    }
                  }),
                ),
                SettingListTile(
                  title: l10n.reminder.notificationSettings,
                  leading: const Icon(LucideIcons.settings),
                  trailing: const Icon(LucideIcons.externalLink, size: 20),
                  onTap: () => _run(_service.permission.openSettings),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 32 + context.safeBottom),
            ),
          ],
        ),
      ),
    );
  }
}
