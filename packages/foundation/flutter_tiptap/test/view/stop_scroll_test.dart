import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';
import '../support/settle.dart';

void main() {
  final schema = ft.Schema.standard();
  final p = TestNodes(schema).p;
  for (final drag in [false, true]) {
    for (final mouse in [false, true]) {
      for (final target in [
        'text',
        'atom',
        'link',
        'chip',
        'checkbox',
        'host',
      ]) {
        testWidgets(
          '${drag ? 'drag' : 'ballistic'} ${mouse ? 'mouse' : 'touch'} press on $target stops scrolling only; idle tap works',
          (tester) async {
            final doc = schema.node(
              'doc',
              content: [
                for (var i = 0; i < 10; i++) p('before $i'),
                schema.node('image', attrs: {'src': 'asset'}),
                schema.node(
                  'paragraph',
                  content: [
                    schema.node(
                      'text',
                      text: 'link target',
                      marks: [
                        schema.mark('link', {'href': 'https://example.com'}),
                      ],
                    ),
                  ],
                ),
                schema.node(
                  'paragraph',
                  content: [
                    schema.node(
                      'diaryLink',
                      attrs: {'id': '42', 'label': 'Diary'},
                    ),
                  ],
                ),
                schema.node(
                  'taskList',
                  content: [
                    schema.node('taskItem', content: [p('task target')]),
                  ],
                ),
                for (var i = 0; i < 25; i++) p('after $i'),
              ],
            );
            final controller = ft.TiptapController(doc: doc),
                focus = FocusNode();
            addTearDown(controller.dispose);
            addTearDown(focus.dispose);
            var hostDown = 0, hostTaps = 0, links = 0, chips = 0;
            final key = GlobalKey<ft.TiptapEditorState>();
            await tester.pumpWidget(
              CupertinoApp(
                home: ScrollConfiguration(
                  behavior: const CupertinoScrollBehavior().copyWith(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                  ),
                  child: ft.TiptapEditor(
                    key: key,
                    controller: controller,
                    focusNode: focus,
                    readOnly: target == 'link',
                    style: const ft.TiptapEditorStyle(cacheExtent: 2000),
                    nodeHeightEstimator: (_, _) => 100,
                    nodeViews: {
                      'image': (_, _) => Listener(
                        onPointerDown: (_) => hostDown++,
                        child: GestureDetector(
                          onTap: target == 'host' ? () => hostTaps++ : null,
                          child: const SizedBox(
                            key: ValueKey('host-media'),
                            height: 100,
                            child: ColoredBox(color: Color(0xffdddddd)),
                          ),
                        ),
                      ),
                    },
                    onLinkTap: (_) => links++,
                    onReferenceTap: (_) => chips++,
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump();
            final geometry = key.currentState!.geometry!,
                scroll = key.currentState!.scrollController;
            final atom = doc.content.positionAt(10),
                link = doc.content.positionAt(11),
                chip = doc.content.positionAt(12),
                list = doc.content.positionAt(13);
            scroll.jumpTo(geometry.rowRect(atom).top - 80);
            await tester.pump();
            await tester.pump();
            final origin = tester.getTopLeft(find.byType(ft.TiptapEditor));
            final point = switch (target) {
              'atom' || 'host' =>
                tester.getRect(find.byKey(const ValueKey('host-media'))).center,
              'checkbox' =>
                origin + geometry.taskCheckboxRect(list + 2)!.center,
              'chip' =>
                origin +
                    geometry.selectionRects(chip + 1, chip + 2).single.center,
              _ =>
                origin +
                    geometry.caretRect(link + 2).center +
                    const Offset(1, 0),
            };
            expect((origin & geometry.viewportSize).contains(point), isTrue);
            final position = scroll.position as ScrollPositionWithSingleContext;
            if (drag) {
              // Trackpad drag activities do not always set shouldIgnorePointer;
              // the editor and host views must also honor isScrollingNotifier.
              position.drag(
                DragStartDetails(
                  globalPosition: point,
                  kind: PointerDeviceKind.trackpad,
                ),
                () {},
              );
            } else {
              position.goBallistic(100);
            }
            await tester.pump();
            expect(position.isScrollingNotifier.value, isTrue);
            final oldSelection = controller.state.selection;
            final clients = tester.testTextInput.log
                .where((call) => call.method == 'TextInput.setClient')
                .length;
            final stoppedOffset = position.pixels;
            final press = await tester.startGesture(
              point,
              kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
            );
            await tester.pump(const Duration(milliseconds: 32));
            expect(position.pixels, stoppedOffset);
            await press.up();
            await settleEditor(tester);
            expect(controller.state.selection, same(oldSelection));
            expect(controller.state.doc, same(doc));
            expect(focus.hasFocus, isFalse);
            expect(
              tester.testTextInput.log
                  .where((call) => call.method == 'TextInput.setClient')
                  .length,
              clients,
            );
            expect([hostDown, hostTaps, links, chips], [0, 0, 0, 0]);
            final idle = await tester.startGesture(
              point,
              kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
            );
            await idle.up();
            await tester.pump();
            await tester.pump();
            switch (target) {
              case 'text':
                expect(controller.state.selection, isA<ft.TextSelection>());
                expect(controller.state.selection.from, link + 2);
              case 'atom':
                expect(controller.state.selection, isA<ft.NodeSelection>());
                expect(controller.state.selection.from, atom);
              case 'link':
                expect(links, 1);
              case 'chip':
                expect(chips, 0);
                expect(controller.state.selection, isA<ft.TextSelection>());
              case 'checkbox':
                expect(
                  controller.state.doc.nodeAt(list + 1)!.attrs['checked'],
                  isTrue,
                );
              case 'host':
                expect(hostDown, 1);
                expect(hostTaps, 1);
            }
          },
          variant: const TargetPlatformVariant({TargetPlatform.iOS}),
        );
      }
    }
  }
  testWidgets(
    'stop-scroll tap preserves an existing editor focus and keyboard session',
    (tester) async {
      final controller = ft.TiptapController(
        doc: schema.node(
          'doc',
          content: [for (var i = 0; i < 50; i++) p('text $i')],
        ),
      );
      final focus = FocusNode(), key = GlobalKey<ft.TiptapEditorState>();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            focusNode: focus,
            autofocus: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      final scroll = key.currentState!.scrollController;
      scroll.jumpTo(200);
      await tester.pump();
      await tester.pump();
      final oldSelection = controller.state.selection;
      final before = tester.testTextInput.log
          .where(
            (call) =>
                call.method == 'TextInput.setClient' ||
                call.method == 'TextInput.show' ||
                call.method == 'TextInput.clearClient' ||
                call.method == 'TextInput.hide',
          )
          .length;
      (scroll.position as ScrollPositionWithSingleContext).goBallistic(300);
      await tester.pump();
      final press = await tester.startGesture(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 32));
      await press.up();
      await settleEditor(tester);
      expect(controller.state.selection, same(oldSelection));
      expect(focus.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester.testTextInput.log
            .where(
              (call) =>
                  call.method == 'TextInput.setClient' ||
                  call.method == 'TextInput.show' ||
                  call.method == 'TextInput.clearClient' ||
                  call.method == 'TextInput.hide',
            )
            .length,
        before,
      );
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      expect(controller.state.selection, isNot(oldSelection));
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
