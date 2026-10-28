import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary/src/presentation/widget/diary_tile_frame.dart';
import 'package:mui/mui.dart';

void main() {
  testWidgets('diary card exposes selection only while selecting', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      Future<void> mount(bool selecting, bool selected) => tester.pumpWidget(
        MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Scaffold(
            body: DiaryTileFrame(
              selecting: selecting,
              selected: selected,
              onTap: () {},
              child: const Text('Diary entry'),
            ),
          ),
        ),
      );
      final card = find
          .descendant(
            of: find.byType(DiaryTileFrame),
            matching: find.byType(Semantics),
          )
          .first;
      for (final selected in [false, true]) {
        await mount(true, selected);
        expect(
          tester.getSemantics(card),
          matchesSemantics(
            label: 'Diary entry',
            hasSelectedState: true,
            isSelected: selected,
            hasTapAction: true,
          ),
        );
      }
      await mount(false, false);
      expect(
        tester.getSemantics(card),
        matchesSemantics(label: 'Diary entry', hasTapAction: true),
      );
    } finally {
      semantics.dispose();
    }
  });
}
