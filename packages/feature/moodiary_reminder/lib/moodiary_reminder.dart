library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/reminder_page.dart';

export 'src/reminder.dart' hide formatReminderTime;
export 'src/reminder_edit_sheet.dart';
export 'src/reminder_labels.dart';
export 'src/reminder_page.dart';
export 'src/reminder_scheduler.dart';
export 'src/reminder_service.dart';

List<RouteBase> reminderRoutes() => [
  GoRoute(
    path: ReminderRoute.path,
    builder: (_, state) => ReminderPage.fromRoute(state),
  ),
];
