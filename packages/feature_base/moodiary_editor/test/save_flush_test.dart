// ignore_for_file: deprecated_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
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
