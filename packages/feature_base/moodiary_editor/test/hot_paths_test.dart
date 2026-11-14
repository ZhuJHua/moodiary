// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart' show TiptapMetadata;
import 'package:mui/mui.dart';

Widget _app(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: buildMuiTheme(brightness: Brightness.light),
    localizationsDelegates: const [
      ...GlobalMaterialLocalizations.delegates,
      GlobalMuiLocalizations.delegate,
    ],
    builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    home: Scaffold(body: child),
  ),
);

void main() {
  final schema = ft.Schema.standard();
  ft.Node paragraph(String text) =>
      schema.node('paragraph', content: [schema.node('text', text: text)]);
  String content(List<ft.Node> nodes) =>
      schema.node('doc', attrs: {'v': 2}, content: nodes).toJsonString();

  testWidgets(
    'host reuses node builders, heading positions and indent commands',
    (tester) async {
      final configuration = MoodiaryEditor(
        initialContent: content([
          schema.node(
            'heading',
            attrs: {'level': 2},
            content: [schema.node('text', text: 'Heading')],
          ),
          paragraph('Body'),
        ]),
      );
      final host = MoodiaryEditorHost(configuration);
      addTearDown(host.dispose);
      final views = host.nodeViews, headings = host.debugHeadingPositions;
      final computations = host.debugIndentComputations;
      host.update(configuration);
      expect(identical(host.nodeViews, views), isTrue);
      expect(identical(host.debugHeadingPositions, headings), isTrue);
      expect(host.debugIndentComputations, computations);
      host.editor.insertPlainText('new');
      expect(identical(host.debugHeadingPositions, headings), isFalse);
      expect(host.debugIndentComputations, computations + 1);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets(
    'document and selection changes retain editor chrome and typography',
    (tester) async {
      var fontReads = 0;
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            initialContent: content([paragraph('Body')]),
            fontResolver: () {
              fontReads++;
              return null;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final before = tester.widget<ft.TiptapEditor>(
        find.byType(ft.TiptapEditor),
      );
      final reads = fontReads;
      before.controller.setSelection(const ft.TextSelection(2));
      before.controller.insertPlainText('text');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final after = tester.widget<ft.TiptapEditor>(
        find.byType(ft.TiptapEditor),
      );
      expect(fontReads, reads);
      expect(identical(after.header, before.header), isTrue);
      expect(identical(after.nodeViews, before.nodeViews), isTrue);
      expect(identical(after.codeBlockHeader, before.codeBlockHeader), isTrue);
      expect(identical(after.style, before.style), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('image headers notify once for all probes completed in a frame', (
    tester,
  ) async {
    final pending = <Completer<FastImageProbe>>[];
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: content([
          for (var index = 0; index < 4; index++)
            schema.node('image', attrs: {'src': 'image-hot-$index.jpg'}),
        ]),
        mediaResolver: (name, {poster = false}) async =>
            (path: '/$name', mime: 'image/jpeg'),
      ),
      imageProbe: ({required filePath}) {
        final result = Completer<FastImageProbe>();
        pending.add(result);
        return result.future;
      },
    );
    addTearDown(host.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
    }
    expect(pending, hasLength(4));
    var notifications = 0;
    host.addListener(() => notifications++);
    for (final probe in pending) {
      probe.complete(
        const FastImageProbe(
          format: FastImageFormat.jpeg,
          width: 20,
          height: 60,
          progressive: false,
          regionDecodable: false,
        ),
      );
    }
    await tester.pump();
    await tester.pump();
    expect(notifications, 1);
  });

  testWidgets(
    'autosave and metadata share one plain text computation per document',
    (tester) async {
      final saved = <(String, String)>[];
      final metadata = <TiptapMetadata>[];
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: content([paragraph('Body')]),
          onChangedWithText: (json, plain) => saved.add((json, plain)),
          onMetadataChanged: metadata.add,
        ),
      );
      addTearDown(host.dispose);
      await tester.pump();
      final before = host.debugMetadataComputations;
      host.editor.setSelection(const ft.TextSelection(2));
      host.editor.insertPlainText('new');
      await tester.pump(const Duration(milliseconds: 400));
      await host.flush();
      expect(host.debugMetadataComputations, before + 1);
      expect(saved, hasLength(1));
      expect(saved.single.$2, metadata.last.plainText);
      expect(jsonDecode(saved.single.$1)['type'], 'doc');
    },
  );

  test(
    'code highlighting reuses exact language, text and brightness results',
    () {
      final first = buildCodeHighlight(
        null,
        'const value = 42;',
        Brightness.light,
      );
      expect(
        identical(
          first,
          buildCodeHighlight(null, 'const value = 42;', Brightness.light),
        ),
        isTrue,
      );
      expect(
        identical(
          first,
          buildCodeHighlight(null, 'const value = 43;', Brightness.light),
        ),
        isFalse,
      );
      expect(
        identical(
          first,
          buildCodeHighlight(null, 'const value = 42;', Brightness.dark),
        ),
        isFalse,
      );
      for (var index = 0; index < 33; index++) {
        buildCodeHighlight(
          'javascript',
          'const value = $index;',
          Brightness.light,
        );
      }
      expect(
        identical(
          first,
          buildCodeHighlight(null, 'const value = 42;', Brightness.light),
        ),
        isFalse,
      );
    },
  );

  testWidgets('flush waits for metadata already started by autosave', (
    tester,
  ) async {
    final saved = <String>[];
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: content([paragraph('Body')]),
        onChangedWithText: (json, plain) => saved.add(plain),
      ),
    );
    addTearDown(host.dispose);
    await tester.pump();
    final text = 'large document ' * 6000;
    host.editor.insertPlainText(text);
    await tester.pump(const Duration(milliseconds: 300));
    var flushed = false;
    final flushing = host.flush().then((_) => flushed = true);
    for (var attempt = 0; !flushed && attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(flushed, isTrue);
    await flushing;
    expect(saved, hasLength(1));
    expect(saved.single, contains(text));
  });

  for (final autosavePending in [false, true]) {
    testWidgets(
      'dispose delivers final content while ${autosavePending ? 'autosave' : 'flush'} metadata is pending',
      (tester) async {
        final saved = <(String, String)>[];
        final jsonSaved = <String>[];
        final host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: content([paragraph('Body')]),
            onChanged: jsonSaved.add,
            onChangedWithText: (json, plain) => saved.add((json, plain)),
          ),
        );
        await tester.pump();
        final text = 'large document ' * 6000;
        host.editor.insertPlainText(text);
        if (autosavePending) {
          await tester.pump(const Duration(milliseconds: 300));
          expect(saved, isEmpty);
          host.editor.insertPlainText('final edit');
        }
        final expectedJson = host.editor.state.doc.toJsonString();
        final expectedText = host.editor.state.doc.textContent;
        var flushed = false;
        final flushing = host.flush().then((_) => flushed = true);
        expect(saved, isEmpty);
        expect(jsonSaved.last, expectedJson);
        host.dispose();
        expect(saved, hasLength(1));
        for (var attempt = 0; !flushed && attempt < 100; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(flushed, isTrue);
        await flushing;
        expect(saved, hasLength(1));
        expect(saved.single.$1, expectedJson);
        expect(saved.single.$2, expectedText);
        if (autosavePending) expect(saved.single.$2, contains('final edit'));
        expect(host.debugMetadataComputations, autosavePending ? 2 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unmount delivers large final content before owner disposal', (
    tester,
  ) async {
    final saved = <(String, String)>[];
    final jsonSaved = <String>[];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => MoodiaryEditor(
            initialContent: content([paragraph('Body')]),
            onChanged: jsonSaved.add,
            onChangedWithText: (json, plain) {
              expect(context.mounted, isTrue);
              saved.add((json, plain));
            },
          ),
        ),
      ),
    );
    final editor = tester.widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor));
    final text = 'large document ' * 6000;
    editor.controller.insertPlainText(text);
    final expectedJson = editor.controller.state.doc.toJsonString();
    final expectedText = editor.controller.state.doc.textContent;
    expect(saved, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(jsonSaved, [expectedJson]);
    expect(saved, hasLength(1));
    for (var attempt = 0; saved.isEmpty && attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(saved, hasLength(1));
    expect(saved.single.$1, expectedJson);
    expect(saved.single.$2, expectedText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose drains a snapshot queued after synchronous delivery', (
    tester,
  ) async {
    final saved = <(String, String)>[];
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: content([paragraph('Body')]),
        onChangedWithText: (json, plain) => saved.add((json, plain)),
      ),
    );
    await tester.pump();
    host.editor.insertPlainText('first');
    final firstFlush = host.flush();
    host.editor.insertPlainText('last');
    final expectedJson = host.editor.state.doc.toJsonString();
    host.dispose();
    await firstFlush;
    expect(saved, hasLength(2));
    expect(saved.last.$1, expectedJson);
    expect(saved.last.$2, contains('last'));
    expect(tester.takeException(), isNull);
  });
}
