import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

import 'support/pump.dart';

const _options = [
  MSheetOption(value: 'a', label: 'Alpha'),
  MSheetOption(value: 'b', label: 'Beta'),
  MSheetOption(value: 'c', label: 'Charlie'),
];

Future<void> _open(
  WidgetTester tester,
  ValueChanged<MetaPickerResult<String>?> receive, {
  bool multi = true,
}) async {
  await tester.pumpWidget(
    muiTestApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => receive(
            await MSheet.show<MetaPickerResult<String>>(
              context,
              builder: (_) => multi
                  ? MetaPickerSheet<String>.wrap(
                      title: 'Tags',
                      selectionSubtitle: (count) => '$count selected',
                      icon: LucideIcons.hash,
                      searchHint: 'Search',
                      matchesLabel: (count) => 'Matches $count',
                      options: _options,
                      initial: const {'c', 'a'},
                      selectedLabel: 'Selected',
                      recentLabel: 'Recent',
                      createLabel: (name) => 'Create $name',
                    )
                  : MetaPickerSheet<String>.list(
                      title: 'Category',
                      subtitle: 'Pick one',
                      icon: LucideIcons.folder,
                      searchHint: 'Search',
                      matchesLabel: (count) => 'Matches $count',
                      options: _options,
                    ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'filters labels and suppresses creation for trimmed exact matches',
    (tester) async {
      await _open(tester, (_) {});
      await tester.enterText(find.byType(EditableText), ' LP ');
      await tester.pump();
      expect(find.text('Matches 1'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Create LP'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), ' aLpHa ');
      await tester.pump();
      expect(find.text('Create aLpHa'), findsNothing);
    },
  );

  testWidgets('Done preserves toggle order and pending creation order', (
    tester,
  ) async {
    MetaPickerResult<String>? result;
    await _open(tester, (value) => result = value);
    for (final label in ['Charlie', 'Beta', 'Charlie']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    for (final name in ['Zed', 'Delta']) {
      await tester.enterText(find.byType(EditableText), name);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create $name'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, name))
            .selected,
        isTrue,
      );
    }
    await tester.tap(find.text(l10n.picker.done));
    await tester.pumpAndSettle();
    expect(result?.selected, ['a', 'b', 'c']);
    expect(result?.created, ['Zed', 'Delta']);
  });

  testWidgets('Cancel discards changes', (tester) async {
    MetaPickerResult<String>? result = (selected: [], created: []);
    await _open(tester, (value) => result = value);
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text(l10n.common.cancel));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('single selection returns the tapped value immediately', (
    tester,
  ) async {
    MetaPickerResult<String>? result;
    await _open(tester, (value) => result = value, multi: false);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(result?.selected, ['b']);
    expect(find.text('Category'), findsNothing);
  });
}
