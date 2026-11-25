import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_reminder/moodiary_reminder.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

final _theme = buildMuiTheme(brightness: .light);

Widget _host(Widget child) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    reminderStateProvider.overrideWithValue((
      reminders: const <Reminder>[],
      enabled: false,
      tapAction: ReminderTapAction.openApp,
      notificationsEnabled: true,
      next: null,
      now: DateTime(2026, 11, 24, 21, 30),
    )),
  ],
  child: TranslationProvider(
    child: MuiTheme(
      data: _theme,
      child: MaterialApp(
        theme: _theme,
        locale: const Locale('zh'),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  Reminder? reminder,
  DateTime? now,
}) async {
  await withClock(
    Clock.fixed(now ?? DateTime(2026, 11, 24, 21, 30)),
    () =>
        tester.pumpWidget(_host(ReminderEditSheet(id: 1, reminder: reminder))),
  );
  await tester.pumpAndSettle();
}

Finder _segment(String label) => find.byWidgetPredicate(
  (widget) => widget is MSegment && widget.semanticLabel == label,
);

MSheetScaffold<ReminderEditResult> _sheet(WidgetTester tester) =>
    tester.widget<MSheetScaffold<ReminderEditResult>>(
      find.byType(MSheetScaffold<ReminderEditResult>),
    );

void main() {
  setUp(() async {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    await LocaleSettings.setLocale(AppLocale.zh);
  });

  testWidgets('saving keeps the selected time, weekdays and enabled state', (
    tester,
  ) async {
    ReminderEditResult? result;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await MSheet.show<ReminderEditResult>(
                context,
                builder: (_) => ReminderEditSheet(
                  id: 1,
                  reminder: Reminder(
                    id: 1,
                    hour: 19,
                    minute: 0,
                    weekdays: {1, 3},
                    enabled: false,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(_sheet(tester).subtitle, '周一、周三 19:00');
    tester.widget<MTimeWheel>(find.byType(MTimeWheel)).onChanged(23, 59);
    await tester.pumpAndSettle();
    expect(_sheet(tester).subtitle, '周一、周三 23:59');
    await tester.tap(_segment('周二'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(result?.reminder?.toJson(), {
      'id': 1,
      'hour': 23,
      'minute': 59,
      'weekdays': [1, 2, 3],
      'enabled': false,
    });
    expect(result?.deleted, isFalse);
  });

  testWidgets('new reminder uses the form header and every day preset', (
    tester,
  ) async {
    await _pump(tester);
    expect(_sheet(tester).icon, LucideIcons.alarmClock);
    expect(_sheet(tester).title, '新建提醒');
    expect(_sheet(tester).subtitle, '每天 21:30');
    expect(_sheet(tester).actions.map((action) => action.label), ['取消', '保存']);
    expect(tester.widget<MSegment>(_segment('每天')).selected, isTrue);
    expect(_segment('周一'), findsNothing);
    expect(find.byType(MDangerRow), findsNothing);
  });

  testWidgets('new reminder starts at the current time', (tester) async {
    await _pump(tester, now: DateTime(2026, 11, 24, 8, 5, 59));
    expect(_sheet(tester).subtitle, '每天 08:05');
  });

  for (final (days, label) in [
    ({1, 2, 3, 4, 5, 6, 7}, '每天'),
    ({1, 2, 3, 4, 5}, '工作日'),
    ({6, 7}, '周末'),
    ({1, 3}, '自定义'),
  ]) {
    testWidgets('existing days initialize the $label mode', (tester) async {
      await _pump(
        tester,
        reminder: Reminder(id: 1, hour: 8, minute: 30, weekdays: days),
      );
      expect(_sheet(tester).title, '编辑提醒');
      expect(tester.widget<MSegment>(_segment(label)).selected, isTrue);
      expect(find.byType(MDangerRow), findsOneWidget);
      expect(_segment('周一'), label == '自定义' ? findsOneWidget : findsNothing);
      if (label == '自定义') {
        expect(tester.widget<MSegment>(_segment('周一')).selected, isTrue);
        expect(tester.widget<MSegment>(_segment('周二')).selected, isFalse);
        expect(tester.widget<MSegment>(_segment('周三')).selected, isTrue);
      }
    });
  }

  testWidgets(
    'presets set days and custom stays selected when matching a preset',
    (tester) async {
      await _pump(tester);
      await tester.tap(_segment('工作日'));
      await tester.pumpAndSettle();
      expect(_sheet(tester).subtitle, '工作日 21:30');
      expect(_segment('周一'), findsNothing);
      await tester.tap(_segment('自定义'));
      await tester.pumpAndSettle();
      for (var index = 0; index < 7; index++) {
        expect(
          tester
              .widget<MSegment>(_segment(l10n.reminder.weekdays[index]))
              .selected,
          index < 5,
        );
      }
      await tester.tap(_segment('周六'));
      await tester.pumpAndSettle();
      await tester.tap(_segment('周日'));
      await tester.pumpAndSettle();
      expect(_sheet(tester).subtitle, '每天 21:30');
      expect(tester.widget<MSegment>(_segment('自定义')).selected, isTrue);
      expect(tester.widget<MSegment>(_segment('每天')).selected, isFalse);
      expect(_segment('周一'), findsOneWidget);
      await tester.tap(_segment('周末'));
      await tester.pumpAndSettle();
      expect(_sheet(tester).subtitle, '周末 21:30');
      expect(_segment('周一'), findsNothing);
      await tester.tap(_segment('每天'));
      await tester.pumpAndSettle();
      expect(_sheet(tester).subtitle, '每天 21:30');
    },
  );

  testWidgets('empty weekdays disable saving until a day is selected', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(_segment('自定义'));
    await tester.pumpAndSettle();
    for (var day = 0; day < 7; day++) {
      await tester.tap(_segment(l10n.reminder.weekdays[day]));
      await tester.pumpAndSettle();
    }
    expect(_sheet(tester).actions.last.enabled, isFalse);
    await tester.tap(_segment('周一'));
    await tester.pumpAndSettle();
    expect(_sheet(tester).actions.last.enabled, isTrue);
  });

  testWidgets(
    'danger row keeps the sheet on cancel and returns deletion on confirm',
    (tester) async {
      ReminderEditResult? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await MSheet.show<ReminderEditResult>(
                  context,
                  builder: (_) => ReminderEditSheet(
                    id: 1,
                    reminder: Reminder(
                      id: 1,
                      hour: 8,
                      minute: 30,
                      weekdays: {1, 3},
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(MDangerRow));
      await tester.tap(find.byType(MDangerRow));
      await tester.pumpAndSettle();
      expect(find.text('删除这条提醒？'), findsOneWidget);
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();
      expect(find.byType(ReminderEditSheet), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.byType(MDangerRow));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除提醒'));
      await tester.pumpAndSettle();
      expect(result?.deleted, isTrue);
      expect(result?.reminder, isNull);
      expect(find.byType(ReminderEditSheet), findsNothing);
    },
  );
}
