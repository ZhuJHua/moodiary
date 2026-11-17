import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_reminder/src/application/reminder_service.dart';

void main() {
  final bands = [
    (
      hours: [0, 4, 23],
      zh: (title: '夜深了', body: '睡前写几句，给今天收个尾。'),
      en: (
        title: "It's late",
        body: 'A few lines before bed to close the day.',
      ),
    ),
    (
      hours: [5, 10],
      zh: (title: '早上好', body: '新的一天，先记下此刻的心情。'),
      en: (
        title: 'Good morning',
        body: 'Start the day by noting how you feel.',
      ),
    ),
    (
      hours: [11, 13],
      zh: (title: '午间小憩', body: '歇一会儿，记两句上午的事。'),
      en: (
        title: 'Midday pause',
        body: 'Take a breather and jot down your morning.',
      ),
    ),
    (
      hours: [14, 17],
      zh: (title: '下午好', body: '抽一分钟，记下现在的状态。'),
      en: (
        title: 'Good afternoon',
        body: "Take a minute to note how it's going.",
      ),
    ),
    (
      hours: [18, 22],
      zh: (title: '晚上好', body: '今天过得怎么样？写下来吧。'),
      en: (title: 'Good evening', body: 'How was your day? Write it down.'),
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
