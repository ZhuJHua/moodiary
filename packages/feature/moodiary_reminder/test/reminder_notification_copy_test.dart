import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_reminder/src/application/reminder_service.dart';

void main() {
  final bands = [
    (
      hours: [0, 4, 23],
      zh: (title: '睡前片刻', body: '睡前写几句今天的事。'),
      en: (title: 'Before bed', body: 'Write a few lines about today.'),
    ),
    (
      hours: [5, 10],
      zh: (title: '早上好', body: '写下今早的心情。'),
      en: (title: 'Good morning', body: 'Write how you feel this morning.'),
    ),
    (
      hours: [11, 13],
      zh: (title: '午间片刻', body: '记一件上午的小事。'),
      en: (title: 'Midday pause', body: 'Jot down a moment from your morning.'),
    ),
    (
      hours: [14, 17],
      zh: (title: '下午好', body: '写几句此刻的感受。'),
      en: (title: 'Good afternoon', body: 'Write a line about how you feel.'),
    ),
    (
      hours: [18, 22],
      zh: (title: '晚上好', body: '记下今天的一刻。'),
      en: (title: 'Good evening', body: 'Write about one moment from today.'),
    ),
  ];
  for (final band in bands) {
    for (final locale in AppLocale.values) {
      test('${locale.languageCode} copy for hours ${band.hours}', () async {
        final strings = await locale.build();
        for (final hour in band.hours) {
          expect(
            reminderNotificationCopy(strings, hour),
            locale == AppLocale.zh ? band.zh : band.en,
          );
        }
      });
    }
  }
}
