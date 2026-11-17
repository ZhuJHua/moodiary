library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/reminder_page.dart';

export 'src/application/reminder_scheduler.dart';
export 'src/application/reminder_service.dart';
export 'src/data/reminder.dart' hide formatReminderTime;
export 'src/presentation/reminder_edit_sheet.dart';
export 'src/presentation/reminder_labels.dart';
export 'src/presentation/reminder_page.dart';

List<RouteBase> reminderRoutes() => [
  GoRoute(
    path: ReminderRoute.path,
    builder: (_, state) => ReminderPage.fromRoute(state),
  ),
];
