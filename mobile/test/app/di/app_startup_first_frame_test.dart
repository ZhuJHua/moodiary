import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_mobile/app/boot_failure_page.dart';
import 'package:moodiary_mobile/app/di/app_startup.dart';
import 'package:moodiary_mobile/main.dart';

void main() {
  testWidgets(
    'AppStartupWidget holds first frame while loading and releases once on error',
    (tester) async {
      final startup = Completer<void>();
      var releases = 0;

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appStartupProvider.overrideWith((ref) => startup.future),
          ],
          child: AppStartupWidget(onFirstFrameReady: () => releases++),
        ),
      );

      expect(releases, 0);
      expect(find.byType(BootFailurePage), findsNothing);

      startup.completeError(StateError('boom'));
      await tester.pumpAndSettle();

      expect(releases, 1);
      expect(find.byType(BootFailurePage), findsOneWidget);
    },
  );

  testWidgets(
    'AppStartupWidget releases first frame once even when startup is already settled',
    (tester) async {
      var releases = 0;

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            appStartupProvider.overrideWith(
              (ref) => Future<void>.error(StateError('immediate')),
            ),
          ],
          child: AppStartupWidget(onFirstFrameReady: () => releases++),
        ),
      );
      await tester.pumpAndSettle();

      expect(releases, 1);
      expect(find.byType(BootFailurePage), findsOneWidget);
    },
  );
}
