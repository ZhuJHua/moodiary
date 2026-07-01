import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_desktop/main.dart';

void main() {
  testWidgets('desktop skeleton builds and shows placeholder', (tester) async {
    await tester.pumpWidget(const MoodiaryDesktopApp());
    expect(find.text('Moodiary Desktop'), findsOneWidget);
  });
}
