import 'package:clock/clock.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import '../data/reminder.dart';
import 'reminder_labels.dart';

class ReminderEditResult {
  const ReminderEditResult({this.reminder, this.deleted = false});
  final Reminder? reminder;
  final bool deleted;
}

class ReminderEditSheet extends StatefulWidget {
  const ReminderEditSheet({super.key, required this.id, this.reminder});
  final int id;
  final Reminder? reminder;

  @override
  State<ReminderEditSheet> createState() => _ReminderEditSheetState();
}

class _ReminderEditSheetState extends State<ReminderEditSheet> {
  late final _now = clock.now();
  late int _hour = widget.reminder?.hour ?? _now.hour;
  late int _minute = widget.reminder?.minute ?? _now.minute;
  late Set<int> _days = {
    ...(widget.reminder?.weekdays ?? ReminderPreset.everyDay.days),
  };
  late ReminderPreset _repeat = ReminderPreset.of(_days);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final time = formatReminderTime(_hour, _minute);
    return MSheetScaffold<ReminderEditResult>(
      icon: LucideIcons.alarmClock,
      title: widget.reminder == null
          ? l10n.reminder.create
          : l10n.reminder.edit,
      subtitle: '${reminderDaysLabel(l10n, _days)} $time'.trim(),
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(
          label: l10n.common.save,
          isPrimary: true,
          enabled: _days.isNotEmpty,
          onPressed: () => Navigator.of(context).pop(
            ReminderEditResult(
              reminder: Reminder(
                id: widget.id,
                hour: _hour,
                minute: _minute,
                weekdays: _days,
                enabled: widget.reminder?.enabled ?? true,
              ),
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const .only(bottom: 4),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            MTimeWheel(
              hour: _hour,
              minute: _minute,
              onChanged: (hour, minute) => setState(() {
                _hour = hour;
                _minute = minute;
              }),
            ),
            Column(
              crossAxisAlignment: .stretch,
              spacing: 4,
              children: [
                MFormSection(l10n.reminder.repeat),
                MSegmentedControl<ReminderPreset>(
                  height: 44,
                  selected: _repeat,
                  options: [
                    MSegmentOption(
                      value: ReminderPreset.everyDay,
                      label: l10n.reminder.everyDay,
                    ),
                    MSegmentOption(
                      value: ReminderPreset.workdays,
                      label: l10n.reminder.workdays,
                    ),
                    MSegmentOption(
                      value: ReminderPreset.weekend,
                      label: l10n.reminder.weekend,
                    ),
                    MSegmentOption(
                      value: ReminderPreset.custom,
                      label: l10n.common.custom,
                    ),
                  ],
                  onChanged: (mode) => setState(() {
                    _repeat = mode;
                    if (mode != ReminderPreset.custom) _days = mode.days;
                  }),
                ),
              ],
            ),
            if (_repeat == ReminderPreset.custom)
              MSegmentGroup(
                height: 44,
                children: [
                  for (var index = 0; index < 7; index++)
                    MSegment(
                      selected: _days.contains(index + 1),
                      semanticLabel: l10n.reminder.weekdays[index],
                      onTap: () => setState(() {
                        if (!_days.remove(index + 1)) _days.add(index + 1);
                      }),
                      child: MSegmentText(
                        l10n.reminder.weekdayShort[index],
                        style: theme.typography.labelLarge.onSurface,
                      ),
                    ),
                ],
              ),
            if (widget.reminder != null)
              MDangerRow(
                label: l10n.reminder.delete,
                onPressed: () async {
                  final confirmed = await MAlert.confirm(
                    context,
                    title: l10n.reminder.delete,
                    message: l10n.reminder.deleteMessage,
                    confirmLabel: l10n.reminder.delete,
                    cancelLabel: l10n.common.cancel,
                    isDestructive: true,
                  );
                  if (confirmed && context.mounted) {
                    Navigator.of(context)
                        .pop(const ReminderEditResult(deleted: true));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
