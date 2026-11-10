import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

String _content({bool large = false, int version = 2, bool broken = false}) =>
    jsonEncode({
      'type': 'doc',
      'attrs': {'v': version},
      'content': [
        {
          'type': 'heading',
          'attrs': {'level': 2},
          'content': [
            {'type': 'text', 'text': 'Heading'},
          ],
        },
        {
          'type': broken ? 'unknown' : 'paragraph',
          'content': [
            {'type': 'text', 'text': '汉 👨‍👩‍👧‍👦 é ' * (large ? 6000 : 1)},
          ],
        },
        {
          'type': 'image',
          'attrs': {'src': 'image-test.png', 'name': 'Photo'},
        },
        {'type': 'paragraph'},
      ],
    });

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: buildMuiTheme(brightness: Brightness.light),
    localizationsDelegates: const [
      ...GlobalMaterialLocalizations.delegates,
      GlobalMuiLocalizations.delegate,
    ],
    // ignore: deprecated_member_use
    builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final large in [false, true]) {
    testWidgets('opening shares deferred metadata (large=$large)', (
      tester,
    ) async {
      final content = _content(large: large);
      final previous = TiptapContent.parse(content);
      final text = previous.plainText;
      final received = <TiptapMetadata>[];
      await tester.pumpWidget(const SizedBox());
      late MoodiaryEditorHost host;
      await tester.runAsync(() async {
        host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: content,
            initialContentText: text,
            onMetadataChanged: received.add,
          ),
        );
        await host.documentLoaded;
      });
      addTearDown(host.dispose);
      expect(host.editor.state.doc.textContent, contains('Heading'));
      expect(received, isEmpty);
      expect(host.characterCount, isNull);
      await tester.pumpWidget(const SizedBox());
      for (var attempt = 0; received.isEmpty && attempt < 100; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpWidget(const SizedBox());
      }
      expect(received, hasLength(1));
      expect(received.single.plainText, text);
      expect(received.single.headings, previous.headings);
      expect(
        received.single.characterCount,
        TiptapContent.countCharacters(
          TiptapContent.fromDocument(host.editor.state.doc.toJson()).plainText,
        ),
      );
      expect(host.characterCount, received.single.characterCount);
      expect(received.single.contentTextCharacterCount, host.characterCount);
    });
  }

  testWidgets('edits and undo refresh shared count, text and headings', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final received = <TiptapMetadata>[];
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _content(),
        initialContentText: 'stale 👨‍👩‍👧‍👦',
        onMetadataChanged: received.add,
      ),
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(const SizedBox());
    expect(
      received.single.contentTextCharacterCount,
      TiptapContent.countCharacters('stale 👨‍👩‍👧‍👦'),
    );
    for (final command in ['insertText', 'undo']) {
      host.editor.exec(
        command,
        command == 'insertText' ? {'text': '中 👨‍👩‍👧‍👦 é '} : {},
      );
      await tester.pump(const Duration(milliseconds: 299));
      final before = received.length;
      await tester.pump(const Duration(milliseconds: 1));
      expect(received.length, before + 1);
      final previous = TiptapContent.parse(host.editor.json);
      expect(received.last.plainText, previous.plainText);
      expect(received.last.headings, previous.headings);
      expect(
        received.last.characterCount,
        TiptapContent.countCharacters(previous.plainText),
      );
      expect(
        received.last.contentTextCharacterCount,
        received.last.characterCount,
      );
      expect(host.characterCount, received.last.characterCount);
    }
    await host.swapDocument(content: _content(), title: '', contentText: '新');
    await tester.pumpWidget(const SizedBox());
    expect(received.last.contentTextCharacterCount, 1);
  });

  testWidgets(
    'stale deferred opening metadata is dropped after a swap or disposal',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final received = <TiptapMetadata>[];
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: _content(),
          onMetadataChanged: received.add,
        ),
      );
      await host.swapDocument(content: '', title: 'new');
      await tester.pumpWidget(const SizedBox());
      expect(received, hasLength(1));
      expect(received.single.characterCount, 0);
      await host.swapDocument(content: _content(), title: 'disposed');
      host.dispose();
      await tester.pumpWidget(const SizedBox());
      expect(received, hasLength(1));
    },
  );

  for (final beforeMetadata in [false, true]) {
    testWidgets(
      'persisted text refresh reuses metadata (before=$beforeMetadata)',
      (tester) async {
        final received = <TiptapMetadata>[];
        final content = _content();
        final host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: content,
            initialContentText: 'old',
            onMetadataChanged: received.add,
          ),
        );
        addTearDown(host.dispose);
        if (!beforeMetadata) await tester.pumpWidget(const SizedBox());
        host.update(
          MoodiaryEditor(
            initialContent: content,
            initialContentText: '中 👨‍👩‍👧‍👦',
            onMetadataChanged: received.add,
          ),
        );
        await tester.pumpWidget(const SizedBox());
        expect(received.last.contentTextCharacterCount, 2);
        expect(received.last.headings, TiptapContent.parse(content).headings);
        expect(
          host.characterCount,
          TiptapContent.countCharacters(received.last.plainText),
        );
        if (!beforeMetadata) {
          expect(received.last.plainText, same(received.first.plainText));
        }
      },
    );
  }

  testWidgets('large same-source swap uses its explicit persisted text', (
    tester,
  ) async {
    final received = <TiptapMetadata>[];
    final content = _content(large: true);
    late MoodiaryEditorHost host;
    await tester.runAsync(() async {
      host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: content,
          initialContentText: 'old',
          onMetadataChanged: received.add,
        ),
      );
      await host.documentLoaded;
      await host.swapDocument(
        content: content,
        title: '',
        contentText: '中 👨‍👩‍👧‍👦',
      );
    });
    addTearDown(host.dispose);
    expect(received, isEmpty);
    await tester.pumpWidget(const SizedBox());
    for (var attempt = 0; received.isEmpty && attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(received, hasLength(1));
    expect(received.single.contentTextCharacterCount, 2);
    expect(received.single.headings, TiptapContent.parse(content).headings);
  });

  test(
    'large isolate load matches the synchronous schema tree and is silent',
    () async {
      final content = _content(large: true),
          saved = <String>[],
          titles = <String>[];
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: content,
          onChanged: saved.add,
          onTitleChanged: titles.add,
        ),
      );
      addTearDown(host.dispose);
      expect(host.editor.state.doc.textContent, isEmpty);
      expect(host.readOnly, isTrue);
      await host.documentLoaded;
      expect(
        host.editor.state.doc.toJson(),
        ft.Schema.standard()
            .fromJson(TiptapContent.parse(content).document!)
            .toJson(),
      );
      expect(host.readOnly, isFalse);
      expect(host.state.value.canUndo, isFalse);
      expect(host.state.value.canRedo, isFalse);
      expect(host.focusTarget.value, EditorFocusTarget.none);
      expect(host.bodyFocus.hasFocus, isFalse);
      await host.flush();
      expect(saved, isEmpty);
      expect(titles, isEmpty);
    },
  );

  test('a swap drops an in-flight initial load and a competing swap', () async {
    final host = MoodiaryEditorHost(
      MoodiaryEditor(initialContent: _content(large: true)),
    );
    addTearDown(host.dispose);
    final initial = host.documentLoaded;
    final pending = host.swapDocument(
      content: _content(large: true, version: 3),
      title: 'stale',
    );
    await host.swapDocument(content: _content(), title: 'current');
    final current = host.editor.state.doc;
    await initial;
    await pending;
    expect(identical(host.editor.state.doc, current), isTrue);
    expect(host.title.text, 'current');
    expect(host.readOnly, isFalse);
    expect(host.contentError.value, isNull);
    expect(host.state.value.canUndo, isFalse);
  });

  test('updated content supersedes an initial load still in flight', () async {
    final host = MoodiaryEditorHost(
      MoodiaryEditor(initialContent: _content(large: true)),
    );
    addTearDown(host.dispose);
    final initial = host.documentLoaded;
    host.update(
      MoodiaryEditor(initialContent: _content(), initialTitle: 'updated'),
    );
    await initial;
    expect(
      host.editor.state.doc.toJson(),
      ft.Schema.standard()
          .fromJson(TiptapContent.parse(_content()).document!)
          .toJson(),
    );
    expect(host.title.text, 'updated');
  });

  test('disposing during an isolate load drops its result', () async {
    final host = MoodiaryEditorHost(
      MoodiaryEditor(initialContent: _content(large: true)),
    );
    final pending = host.documentLoaded;
    host.dispose();
    await pending;
  });

  for (final broken in [false, true]) {
    test(
      'large protected content retains readable portions (broken=$broken)',
      () async {
        final saved = <String>[];
        final host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: _content(
              large: true,
              version: broken ? 2 : 3,
              broken: broken,
            ),
            onChanged: saved.add,
          ),
        );
        addTearDown(host.dispose);
        await host.documentLoaded;
        expect(host.readOnly, isTrue);
        expect(host.contentError.value, isNotNull);
        expect(host.state.value.contentError, isTrue);
        expect(host.editor.state.doc.textContent, contains('Heading'));
        final before = host.editor.json;
        await host.exec(EditorCommand.insertHorizontalRule, null);
        await host.flush();
        expect(host.editor.json, before);
        expect(saved, isEmpty);
      },
    );
  }

  testWidgets(
    'small diary has its body in the first frame; count follows without shifting the header',
    (tester) async {
      final content = _content();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            initialContent: content,
            readOnly: true,
            initialTitle: 'Title',
            metaJson: jsonEncode({'dateText': 'Today', 'subText': '12:00'}),
          ),
        ),
      );
      final editor = tester.widget<ft.TiptapEditor>(
        find.byType(ft.TiptapEditor),
      );
      expect(editor.controller.state.doc.textContent, contains('Heading'));
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('editor-title')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          l10n.diary.wordCount(
            count: TiptapContent.countCharacters(
              TiptapContent.parse(content).plainText,
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('editor-title'))),
        before,
      );
    },
  );

  testWidgets(
    'large header is immediate, body and count follow without saving or focus',
    (tester) async {
      final saved = <String>[], content = _content(large: true);
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            initialContent: content,
            initialTitle: 'Large title',
            readOnly: true,
            metaJson: jsonEncode({'dateText': 'Today', 'subText': '12:00'}),
            onChanged: saved.add,
          ),
        ),
      );
      expect(find.text('Large title'), findsOneWidget);
      final editor = tester.widget<ft.TiptapEditor>(
        find.byType(ft.TiptapEditor),
      );
      expect(editor.controller.state.doc.textContent, isEmpty);
      final count = TiptapContent.countCharacters(
        TiptapContent.parse(content).plainText,
      );
      final countFinder = find.textContaining(
        l10n.diary.wordCount(count: count),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (countFinder.evaluate().isNotEmpty) break;
      }
      expect(editor.controller.state.doc.textContent, contains('Heading'));
      expect(countFinder, findsOneWidget);
      expect(
        TiptapContent.fromDocument(editor.controller.state.doc.toJson())
            .headings,
        [(level: 2, text: 'Heading')],
      );
      expect(editor.controller.state.history.canUndo, isFalse);
      expect(editor.focusNode?.hasFocus, isFalse);
      expect(saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
