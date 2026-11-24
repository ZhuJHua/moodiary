import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  testWidgets(
    'parent values move idle wheels and wait for an active drag to settle',
    (tester) async {
      var hour = 8;
      var minute = 30;
      var callbacks = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MTimeWheel(
                  hour: hour,
                  minute: minute,
                  onChanged: (selectedHour, selectedMinute) => setState(() {
                    callbacks++;
                    hour = selectedHour;
                    minute = selectedMinute;
                  }),
                );
              },
            ),
          ),
        ),
      );
      final wheels = tester
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      final hours = wheels.first.controller! as FixedExtentScrollController;
      final minutes = wheels.last.controller! as FixedExtentScrollController;
      update(() {
        hour = 20;
        minute = 45;
      });
      await tester.pumpAndSettle();
      expect(hours.selectedItem % 24, 20);
      expect(minutes.selectedItem % 60, 45);
      expect(callbacks, 0);

      final bounds = tester.getRect(find.byType(MTimeWheel));
      final gesture = await tester.startGesture(
        Offset(bounds.left + 8, bounds.center.dy),
      );
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      final before = hours.selectedItem;
      update(() {
        hour = 6;
        minute = 10;
      });
      await tester.pump();
      expect(hours.selectedItem, before);
      expect(minutes.selectedItem % 60, 10);
      final beforeCallbacks = callbacks;
      await gesture.moveBy(const Offset(0, -44));
      await tester.pump();
      expect(hour, 6);
      expect(callbacks, beforeCallbacks);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(hours.selectedItem % 24, 6);
      expect(minutes.selectedItem % 60, 10);
    },
  );

  testWidgets('wheel halves respond to drags near both outer edges', (
    tester,
  ) async {
    var hour = 8;
    var minute = 30;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMuiTheme(brightness: .light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MTimeWheel(
              hour: hour,
              minute: minute,
              onChanged: (selectedHour, selectedMinute) => setState(() {
                hour = selectedHour;
                minute = selectedMinute;
              }),
            ),
          ),
        ),
      ),
    );
    final bounds = tester.getRect(find.byType(MTimeWheel));
    await tester.dragFrom(
      Offset(bounds.left + 8, bounds.center.dy),
      const Offset(0, -88),
    );
    await tester.pumpAndSettle();
    expect(hour, isNot(8));
    expect(minute, 30);
    final selectedHour = hour;
    await tester.dragFrom(
      Offset(bounds.right - 8, bounds.center.dy),
      const Offset(0, -88),
    );
    await tester.pumpAndSettle();
    expect(hour, selectedHour);
    expect(minute, isNot(30));
  });
}
