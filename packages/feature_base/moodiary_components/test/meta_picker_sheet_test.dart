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
  ValueChanged<MetaPickerResult<String?>?> receive, {
  bool multi = true,
  List<MSheetOption<String?>> options = _options,
  Set<String?> initial = const {'c', 'a'},
  Future<String?> Function(String)? create,
}) async {
  await tester.pumpWidget(
    muiTestApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => receive(
            await MSheet.show<MetaPickerResult<String?>>(
              context,
              builder: (_) => multi
                  ? MetaPickerSheet<String?>.multi(
                      title: 'Tags',
                      selectionSubtitle: (count) => '$count selected',
                      icon: LucideIcons.hash,
                      searchHint: 'Search',
                      matchesLabel: (count) => 'Matches $count',
                      options: options,
                      initial: initial,
                      recentLabel: 'Recent',
                      createLabel: (name) => 'Create $name',
                    )
                  : MetaPickerSheet<String?>.single(
                      title: 'Category',
                      subtitle: 'Pick one',
                      icon: LucideIcons.folder,
                      searchHint: 'Search',
                      matchesLabel: (count) => 'Matches $count',
                      options: options,
                      createLabel: create == null ? null : 'New category',
                      onCreate: create,
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

Finder _optionsMatching([String? label]) => find.byWidgetPredicate(
  (widget) =>
      widget is MChip &&
      widget.variant == .tonal &&
      widget.onRemove == null &&
      (label == null || widget.label == label),
);

Finder _remove(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is MChip && widget.label == label && widget.onRemove != null,
  ),
  matching: find.byIcon(LucideIcons.x),
);

bool _doneEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.picker.done),
        )
        .onPressed !=
    null;

void main() {
  testWidgets(
    'filters labels and suppresses creation for trimmed exact matches',
    (tester) async {
      await _open(tester, (_) {});
      await tester.enterText(find.byType(EditableText), ' LP ');
      await tester.pump();
      expect(find.text('Matches 1'), findsOneWidget);
      expect(tester.getSize(_optionsMatching('Alpha')).height, 32);
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
    MetaPickerResult<String?>? result;
    await _open(tester, (value) => result = value);
    for (final label in ['Charlie', 'Beta', 'Charlie']) {
      await tester.tap(_optionsMatching(label));
      await tester.pumpAndSettle();
    }
    for (final name in ['Zed', 'Delta']) {
      await tester.enterText(find.byType(EditableText), name);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create $name'));
      await tester.pumpAndSettle();
      expect(_remove(name), findsOneWidget);
    }
    await tester.tap(find.text(l10n.picker.done));
    await tester.pumpAndSettle();
    expect(result?.selected, ['a', 'b', 'c']);
    expect(result?.created, ['Zed', 'Delta']);
  });

  testWidgets('Cancel discards changes', (tester) async {
    MetaPickerResult<String?>? result = (selected: [], created: []);
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
    MetaPickerResult<String?>? result;
    await _open(tester, (value) => result = value, multi: false);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(result?.selected, ['b']);
    expect(find.text('Category'), findsNothing);
  });

  testWidgets('toggling preserves chip positions and reverting disables Done', (
    tester,
  ) async {
    await _open(tester, (_) {});
    expect(_doneEnabled(tester), isFalse);
    final position = tester.getTopLeft(_optionsMatching('Charlie'));
    await tester.tap(_optionsMatching('Beta'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_optionsMatching('Charlie')), position);
    expect(tester.widget<MChip>(_optionsMatching('Beta')).selected, isTrue);
    expect(_doneEnabled(tester), isTrue);
    await tester.tap(_remove('Beta'));
    await tester.pumpAndSettle();
    expect(_remove('Beta'), findsNothing);
    expect(tester.widget<MChip>(_optionsMatching('Beta')).selected, isFalse);
    expect(_doneEnabled(tester), isFalse);
  });

  testWidgets('shows twelve recent options and expands in caller order', (
    tester,
  ) async {
    final options = List.generate(
      15,
      (index) => MSheetOption(value: '$index', label: '$index'),
    );
    await _open(tester, (_) {}, options: options, initial: {});
    expect(_optionsMatching(), findsNWidgets(12));
    expect(_optionsMatching('12'), findsNothing);
    final expand = find.text(l10n.diary.tagShowAll(count: 15));
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(_optionsMatching(), findsNWidgets(15));
    expect(expand, findsNothing);
    expect(
      tester.widgetList<MChip>(_optionsMatching()).last,
      tester.widget<MChip>(_optionsMatching('14')),
    );
  });

  testWidgets('empty catalog supports creating and removing a pending tag', (
    tester,
  ) async {
    await _open(tester, (_) {}, options: [], initial: {});
    expect(find.text(l10n.diary.tagEmpty), findsOneWidget);
    expect(find.text(l10n.diary.tagEmptyBody), findsOneWidget);
    expect(find.text('Recent'), findsNothing);
    await tester.enterText(find.byType(EditableText), ' New ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create New'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
    expect(_doneEnabled(tester), isTrue);
    await tester.tap(_remove('New'));
    await tester.pumpAndSettle();
    expect(_remove('New'), findsNothing);
    expect(_doneEnabled(tester), isFalse);
  });

  testWidgets(
    'single picker excludes the null option from its search threshold',
    (tester) async {
      final options = [
        const MSheetOption<String?>(value: null, label: 'None'),
        for (var index = 0; index < 8; index++)
          MSheetOption(value: '$index', label: '$index'),
      ];
      MetaPickerResult<String?>? result;
      await _open(
        tester,
        (value) => result = value,
        multi: false,
        options: options.sublist(0, 8),
      );
      expect(find.byType(SearchBar), findsNothing);
      expect(find.text(l10n.picker.done), findsNothing);
      await tester.tap(_optionsMatching('None'));
      await tester.pumpAndSettle();
      expect(result?.selected, [null]);
      await _open(
        tester,
        (value) => result = value,
        multi: false,
        options: options,
        create: (query) async => 'saved $query',
      );
      await tester.enterText(find.byType(EditableText), ' Work ');
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      expect(result?.selected, ['saved Work']);
      expect(result?.created, isEmpty);
    },
  );
}
