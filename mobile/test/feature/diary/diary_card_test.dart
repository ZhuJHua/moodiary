import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary/feature/diary/presentation/widget/diary_card.dart';

// `Diary.empty()`/`Category.create()` call `uuidV7()` (Rust FFI), which
// throws in host unit tests — build literals directly instead (pattern from
// mobile/test/feature/sync/sync_test_harness.dart `buildDiary()`).
Diary diary({double mood = 0.5, List<String> weather = const []}) => Diary(
      id: 'test',
      categoryId: null,
      title: 'T',
      content: '',
      contentText: 'body',
      time: DateTime(2026),
      lastModified: DateTime(2026),
      show: true,
      deleted: false,
      mood: mood,
      weather: weather,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: const [],
      position: const [],
      type: DiaryType.tiptap.value,
    );

Category cat() => Category(
      id: 'a', categoryName: 'work', lastModified: DateTime(2026), deleted: false,
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows category name when showCategoryLabel true', (t) async {
    await t.pumpWidget(wrap(DiaryListTile(
        diary: diary(), category: cat(), showCategoryLabel: true)));
    expect(find.text('work'), findsOneWidget);
  });

  testWidgets('hides category name when showCategoryLabel false', (t) async {
    await t.pumpWidget(wrap(DiaryListTile(
        diary: diary(), category: cat(), showCategoryLabel: false)));
    expect(find.text('work'), findsNothing);
  });

  testWidgets('always renders a mood glyph', (t) async {
    await t.pumpWidget(wrap(DiaryListTile(diary: diary(mood: 0.5))));
    expect(find.byType(MoodIconComponent), findsOneWidget);
  });

  testWidgets('shows weather when weather has 3 parts', (t) async {
    await t.pumpWidget(wrap(DiaryListTile(
        diary: diary(weather: const ['100', '22', '晴']))));
    expect(find.textContaining('晴'), findsOneWidget);
  });

  testWidgets('DiaryListTile renders inside a ListView without layout error',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      DiaryListTile(diary: diary(), category: cat(), showCategoryLabel: true),
    ]))));
    expect(t.takeException(), isNull);
  });

  testWidgets('DiaryGridTile renders inside a ListView without layout error',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      DiaryGridTile(diary: diary(), category: cat(), showCategoryLabel: true),
    ]))));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'CalendarDiaryCard renders inside a ListView without layout error',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(children: [
      CalendarDiaryCard(
          diary: diary(), category: cat(), showCategoryLabel: true),
    ]))));
    expect(t.takeException(), isNull);
  });
}
