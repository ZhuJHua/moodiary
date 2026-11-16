// ignore_for_file: deprecated_member_use

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import '../../../foundation/flutter_tiptap/test/support/ime.dart';
import '../../../foundation/flutter_tiptap/test/support/reference_doc.dart';

void main() {
  testWidgets('iOS host keeps autocorrection after entering edit mode', (
    tester,
  ) async {
    final ime = FakeIme(tester);
    final content = referenceDocument;
    final readOnly = ValueNotifier(true);
    addTearDown(readOnly.dispose);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: Brightness.light),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: readOnly,
              builder: (_, value, _) =>
                  MoodiaryEditor(initialContent: content, readOnly: value),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    readOnly.value = false;
    await tester.pump();
    final finder = find.byType(ft.TiptapEditor);
    final state = tester.state<ft.TiptapEditorState>(finder);
    final controller = tester.widget<ft.TiptapEditor>(finder).controller;
    final original = controller.state.doc.blocks.first.textContent;
    final end = controller.state.doc.blocks.first.content.size + 1;
    await tester.tapAt(
      tester.getTopLeft(finder) + state.geometry!.caretRect(end).center,
    );
    await tester.pump();
    expect(controller.state.selection, ft.TextSelection(end));
    for (final text in [' hello', 'd', 'u']) {
      await ime.edit(text: text);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.debugInputValue, ime.value);
    }
    final before = ime.value;
    final wordStart = before.text.length - 'hellodu'.length;
    state.debugApplyDeltas([
      TextEditingDeltaNonTextUpdate(
        oldText: before.text,
        selection: before.selection,
        composing: TextRange(start: wordStart, end: before.text.length),
      ),
      TextEditingDeltaReplacement(
        oldText: before.text,
        replacedRange: TextRange(start: wordStart, end: before.text.length),
        replacementText: 'hellodu ',
        selection: TextSelection.collapsed(offset: before.text.length + 1),
        composing: TextRange.empty,
      ),
    ]);
    expect(controller.state.doc.blocks.first.textContent, '$original hellodu ');
    expect(controller.state.selection, ft.TextSelection(end + 9));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
