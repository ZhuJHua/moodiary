import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/detail/diary_page.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _Repository implements DiaryRepository {
  _Repository(this.diary);
  final Diary diary;
  @override
  Stream<DiaryEvent> get diaryEvents => const Stream.empty();
  @override
  Future<Diary?> getDiaryByBusinessId(String id) async => diary;
  @override
  Future<List<Diary>> getForwardLinks(String id) async => [];
  @override
  Future<List<Diary>> getBacklinks(String id) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Categories extends CategoryController {
  @override
  FutureOr<List<Category>> build() => [];
}

void main() {
  testWidgets(
    'metadata updates counts and headings without rebuilding the editor body',
    (tester) async {
      final diary = Diary.empty(type: .tiptap);
      getIt.registerSingleton<DiaryRepository>(_Repository(diary));
      getIt.registerSingleton<OpenDiaryRegistry>(OpenDiaryRegistry());
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      getIt.registerSingleton<ThemeManager>(ThemeManager());
      addTearDown(getIt.reset);
      await tester.pumpWidget(
        muiTestApp(
          DiaryPage(diaryId: diary.id, startInEdit: true),
          wrapScaffold: false,
          overrides: [
            categoryControllerProvider.overrideWith(_Categories.new),
            orderedPlacesProvider.overrideWith((ref) => const AsyncData([])),
            secretKvProvider(MoodiarySecureKVs.qweatherKey)
                .overrideWith((ref) async => null),
          ],
        ),
      );
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final before = tester.widget<EditorBody>(find.byType(EditorBody));
      TiptapMetadata metadata(String title) => TiptapContent.parse(
        jsonEncode({
          'type': 'doc',
          'attrs': {'v': 2},
          'content': [
            {
              'type': 'heading',
              'attrs': {'level': 1},
              'content': [
                {'type': 'text', 'text': title},
              ],
            },
          ],
        }),
      ).metadata();
      before.onMetadataChanged!(metadata('Heading'));
      await tester.pump();
      final afterHeading = tester.widget<EditorBody>(find.byType(EditorBody));
      expect(identical(before, afterHeading), isTrue);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).endDrawer,
        isNotNull,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final countMetadata = metadata('Heading')
          .forContentText('longer preview text');
      afterHeading.onMetadataChanged!(countMetadata);
      await tester.pump();
      expect(
        identical(before, tester.widget<EditorBody>(find.byType(EditorBody))),
        isTrue,
      );
      expect(
        identical(
          scaffold,
          tester.widget<Scaffold>(find.byType(Scaffold).first),
        ),
        isTrue,
      );
      expect(
        find.text(
          l10n.diary.wordCount(count: countMetadata.contentTextCharacterCount),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
