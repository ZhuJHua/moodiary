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
  late int _startMinutes =
      (widget.reminder?.hour ?? 21) * 60 + (widget.reminder?.minute ?? 30);
  late int _endMinutes =
      (widget.reminder?.endHour ?? 23) * 60 +
      (widget.reminder?.endMinute ?? 59);
  late bool _isRandom = widget.reminder?.isRandom ?? false;
  bool _editingEnd = false;
  late Set<int> _days = {
    ...(widget.reminder?.weekdays ?? ReminderPreset.everyDay.days),
  };
  late ReminderPreset _repeat = ReminderPreset.of(_days);

  void _setKind(bool random) => setState(() {
    if (random && !_isRandom) {
      _startMinutes = _startMinutes.clamp(0, 1409);
      _endMinutes = (_startMinutes + 180).clamp(_startMinutes + 30, 1439);
    }
    _isRandom = random;
    _editingEnd = false;
  });

  void _setTime(int hour, int minute) => setState(() {
    final value = hour * 60 + minute;
    if (!_isRandom) {
      _startMinutes = value;
    } else if (_editingEnd) {
      _endMinutes = value.clamp(30, 1439);
      if (_startMinutes > _endMinutes - 30) _startMinutes = _endMinutes - 30;
    } else {
      _startMinutes = value.clamp(0, 1409);
      if (_endMinutes < _startMinutes + 30) _endMinutes = _startMinutes + 30;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = context.theme;
    final start = formatReminderTime(_startMinutes ~/ 60, _startMinutes % 60);
    final end = formatReminderTime(_endMinutes ~/ 60, _endMinutes % 60);
    final time = _isRandom ? '$start–$end ${l10n.reminder.random}' : start;
    final selectedTime = _isRandom && _editingEnd ? _endMinutes : _startMinutes;
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
                hour: _startMinutes ~/ 60,
                minute: _startMinutes % 60,
                endHour: _isRandom ? _endMinutes ~/ 60 : null,
                endMinute: _isRandom ? _endMinutes % 60 : null,
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
            MSegmentedControl<bool>(
              height: 44,
              selected: _isRandom,
              options: [
                MSegmentOption(value: false, label: l10n.reminder.fixedTime),
                MSegmentOption(value: true, label: l10n.reminder.randomWindow),
              ],
              onChanged: _setKind,
            ),
            if (_isRandom)
              MSegmentGroup(
                height: 56,
                children: [
                  for (final (isEnd, label, value) in [
                    (false, l10n.reminder.start, start),
                    (true, l10n.reminder.end, end),
                  ])
                    MSegment(
                      selected: _editingEnd == isEnd,
                      semanticLabel: label,
                      onTap: () => setState(() => _editingEnd = isEnd),
                      child: Column(
                        mainAxisAlignment: .center,
                        spacing: 2,
                        children: [
                          Opacity(
                            opacity: 0.7,
                            child: MSegmentText(
                              label,
                              style: theme.typography.labelSmall.onSurface,
                            ),
                          ),
                          MSegmentText(
                            value,
                            style: theme
                                .typography
                                .titleMedium
                                .emphasized
                                .onSurface
                                .tabular,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            MTimeWheel(
              hour: selectedTime ~/ 60,
              minute: selectedTime % 60,
              onChanged: _setTime,
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
