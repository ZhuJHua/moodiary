import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  testWidgets('caret glides vertically and interpolates font metric height', (
    tester,
  ) async {
    final schema = ft.Schema.standard();
    final controller = ft.TiptapController(
      doc: schema.node(
        'doc',
        content: [
          schema.node('paragraph', content: [schema.node('text', text: 'abc')]),
          schema.node(
            'heading',
            attrs: {'level': 1},
            content: [schema.node('text', text: 'Heading')],
          ),
        ],
      ),
    );
    final focus = FocusNode();
    final key = GlobalKey<ft.TiptapEditorState>();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: ft.TiptapEditor(
          key: key,
          controller: controller,
          focusNode: focus,
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final from = key.currentState!.debugCaret.rect!;
    controller.setSelection(const ft.TextSelection(6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final middle = key.currentState!.debugCaret.rect!;
    await tester.pump(const Duration(milliseconds: 64));
    final end = key.currentState!.debugCaret.rect!;
    expect(middle.top, greaterThan(from.top));
    expect(middle.top, lessThan(end.top));
    expect(middle.height, greaterThan(from.height));
    expect(middle.height, lessThan(end.height));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'caret breathes on its own layer over 1M characters, rests on input and stops when hidden',
    (tester) async {
      final schema = ft.Schema.standard();
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [
            for (var i = 0; i < 1000; i++)
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'a' * 1000)],
              ),
          ],
        ),
      );
      final key = GlobalKey<ft.TiptapEditorState>();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var readOnly = false, ticker = true, reduced = false;
      Future<void> mount() async {
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: ticker,
                child: ft.TiptapEditor(
                  key: key,
                  controller: controller,
                  focusNode: focus,
                  readOnly: readOnly,
                  style: const ft.TiptapEditorStyle(
                    paragraph: TextStyle(fontSize: 17, height: 1.75),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await mount();
      expect(key.currentState!.debugCaret.timer, isFalse);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      final state = key.currentState!;
      expect(state.debugCaret.timer, isTrue);
      expect(state.debugCaret.rect!.height, lessThan(17 * 1.75));
      await tester.pump();
      await tester.pump();
      final paints = state.debugDocumentPaints;
      final layouts = controller.diagnostics.paragraphLayouts;
      await tester.pump(const Duration(milliseconds: 625));
      expect(state.debugCaret.opacity, greaterThan(.8));
      await tester.pump(const Duration(milliseconds: 125));
      expect(state.debugCaret.opacity, closeTo(.5, .06));
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.debugCaret.opacity, lessThan(.02));
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.debugCaret.opacity, inExclusiveRange(0, 1));
      expect(state.debugDocumentPaints, paints);
      expect(controller.diagnostics.paragraphLayouts, layouts);
      controller.exec('insertText', {'text': 'z'});
      await tester.pump();
      await tester.pump();
      expect(state.debugCaret.opacity, 1);
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.debugCaret.opacity, 1);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.debugCaret.opacity, lessThan(1));
      controller.setSelection(const ft.TextSelection(2, 4));
      await tester.pump();
      expect(state.debugCaret.timer, isFalse);
      controller.setSelection(const ft.TextSelection(3));
      await tester.pump();
      await tester.pump();
      expect(state.debugCaret.timer, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(state.debugCaret.timer, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      controller.setSelection(ft.NodeSelection(controller.state.doc, 0));
      await tester.pump();
      expect(state.debugCaret.timer, isFalse);
      controller.setSelection(const ft.TextSelection(3));
      await tester.pump();
      ticker = false;
      await mount();
      expect(state.debugCaret.timer, isFalse);
      ticker = true;
      reduced = true;
      await mount();
      await tester.pump(const Duration(milliseconds: 750));
      expect(state.debugCaret.opacity, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.debugCaret.opacity, 0);
      readOnly = true;
      await mount();
      expect(state.debugCaret.timer, isFalse);
      readOnly = false;
      await mount();
      focus.unfocus();
      await tester.pump();
      expect(state.debugCaret.timer, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'selection glides; typing, IME, swap, reduced motion, offscreen and style opt-out snap',
    (tester) async {
      final schema = ft.Schema.standard();
      ft.Node doc() => schema.node(
        'doc',
        content: [
          for (var i = 0; i < 100; i++)
            schema.node(
              'paragraph',
              content: [schema.node('text', text: 'a' * 80)],
            ),
        ],
      );
      final controller = ft.TiptapController(doc: doc());
      final focus = FocusNode();
      final key = GlobalKey<ft.TiptapEditorState>();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var animate = true, reduced = false;
      Future<void> mount() async {
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: ft.TiptapEditor(
                key: key,
                controller: controller,
                focusNode: focus,
                style: ft.TiptapEditorStyle(animateCaretMovement: animate),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await mount();
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      final state = key.currentState!;
      final from = state.debugCaret.rect!;
      controller.setSelection(const ft.TextSelection(15));
      await tester.pump();
      final target = state.geometry!.caretRect(15);
      expect(state.debugCaret.rect!.left, closeTo(from.left, .01));
      // The platform geometry remains at the real target throughout the glide.
      expect(state.geometry!.caretRect(15), target);
      await tester.pump(const Duration(milliseconds: 48));
      expect(state.debugCaret.rect!.left, greaterThan(from.left));
      expect(state.debugCaret.rect!.left, lessThan(target.left));
      await tester.pump(const Duration(milliseconds: 64));
      expect(state.debugCaret.rect!.left, closeTo(target.left, .01));
      controller.exec('insertText', {'text': 'q'});
      await tester.pump();
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(
          state.geometry!.caretRect(controller.state.selection.head).left,
          .01,
        ),
      );
      controller.exec('undo');
      await tester.pump();
      final undoTarget = state.geometry!.caretRect(
        controller.state.selection.head,
      );
      await tester.pump(const Duration(milliseconds: 112));
      expect(state.debugCaret.rect!.left, closeTo(undoTarget.left, .01));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 112));
      expect(
        state.debugCaret.rect!.left,
        closeTo(
          state.geometry!.caretRect(controller.state.selection.head).left,
          .01,
        ),
      );
      final oldValue = state.debugInputValue;
      final at = oldValue.selection.extentOffset;
      state.debugApplyDeltas([
        TextEditingDeltaNonTextUpdate(
          oldText: oldValue.text,
          selection: TextSelection.collapsed(offset: at + 2),
          composing: TextRange(start: at, end: at + 2),
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(
          state.geometry!.caretRect(controller.state.selection.head).left,
          .01,
        ),
      );
      final caretCalls = tester.testTextInput.log.where(
        (call) => call.method == 'TextInput.setCaretRect',
      );
      expect(caretCalls, isNotEmpty);
      expect(
        (caretCalls.last.arguments as Map)['x'],
        closeTo(
          state.geometry!.caretRect(controller.state.selection.head).left,
          .01,
        ),
      );
      state.finishComposition();
      controller.replaceDocument(doc());
      await tester.pump();
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(
          state.geometry!.caretRect(controller.state.selection.head).left,
          .01,
        ),
      );
      animate = false;
      await mount();
      controller.setSelection(const ft.TextSelection(4));
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(state.geometry!.caretRect(4).left, .01),
      );
      animate = true;
      reduced = true;
      await mount();
      controller.setSelection(const ft.TextSelection(8));
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(state.geometry!.caretRect(8).left, .01),
      );
      reduced = false;
      await mount();
      controller.setSelection(const ft.TextSelection(7500));
      await tester.pump();
      await tester.pump();
      expect(
        state.debugCaret.rect!.left,
        closeTo(state.geometry!.caretRect(7500).left, .01),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
