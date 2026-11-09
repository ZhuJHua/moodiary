import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/large_doc.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  setUp(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  final schema = ft.Schema.standard();
  ft.Node p(String text) => schema.node(
    'paragraph',
    content: [if (text.isNotEmpty) schema.node('text', text: text)],
  );
  ft.Node doc(List<ft.Node> nodes) => schema.node('doc', content: nodes);
  const commands = ft.EditorCommands(trailingParagraph: true);

  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    Map<String, ft.TiptapNodeViewBuilder> views = const {},
    ft.TiptapNodeHeightEstimator? estimate,
    ValueChanged<String>? onReference,
    ValueChanged<String>? onLink,
    bool readOnly = false,
    bool autofocus = false,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: ft.TiptapEditor(
          key: key,
          controller: controller,
          nodeViews: views,
          nodeHeightEstimator: estimate,
          onReferenceTap: onReference,
          onLinkTap: onLink,
          readOnly: readOnly,
          autofocus: autofocus,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(controller.dispose);
    return key;
  }

  test('media normalisation and safe hrefs', () {
    expect(
      schema.fromJson({
        'type': 'image',
        'attrs': {
          'src': 'a',
          'alt': 'old',
          'width': 12,
          'height': 20,
          'widthPercent': 1,
        },
      }).attrs,
      {'src': 'a', 'name': 'old', 'widthPercent': 25},
    );
    expect(
      schema.fromJson({
        'type': 'video',
        'attrs': {'filename': 'old.mp4'},
      }).attrs,
      {'src': 'old.mp4', 'name': null, 'widthPercent': null},
    );
    expect(
      schema.fromJson({
        'type': 'diaryLink',
        'attrs': {'id': '1', 'mentionSuggestionChar': '[['},
      }).attrs,
      {'id': '1', 'label': null},
    );
    expect(
      ft.normalizeHref('example.com:8080/path'),
      'https://example.com:8080/path',
    );
    expect(ft.normalizeHref('javascript:alert(1)'), '');
    expect(
      schema.fromJson({'type': 'futureTable', 'content': []}).isOpaque,
      isTrue,
    );
    expect(schema.fromJson({'type': 'table', 'content': []}).isOpaque, isFalse);
  });

  test(
    'suggestion match is limited to the preceding text node and UTF16 query',
    () {
      for (final trigger in ['[[', '【【', '「「']) {
        final node = doc([p('a $trigger hello')]);
        final match = ft.findReferenceMatch(node, node.content.size - 1)!;
        expect(match.from, 3);
        expect(match.query, ' hello');
      }
      for (final query in ['x' * 41, 'end]', 'end】', 'end」', 'end\n']) {
        final node = doc([p('[[$query')]);
        expect(ft.findReferenceMatch(node, node.content.size - 1), isNull);
      }
      final split = doc([
        schema.node(
          'paragraph',
          content: [
            schema.node('text', text: '[[old'),
            schema.node('text', text: 'query', marks: [schema.mark('bold')]),
          ],
        ),
      ]);
      expect(ft.findReferenceMatch(split, split.content.size - 1), isNull);
    },
  );

  test(
    'linkAt touches either edge and spans adjacent differently marked nodes',
    () {
      final link = schema.mark('link', {'href': 'https://a.com'});
      final node = doc([
        schema.node(
          'paragraph',
          content: [
            schema.node('text', text: 'one', marks: [link]),
            schema.node(
              'text',
              text: 'two',
              marks: [link, schema.mark('bold')],
            ),
            schema.node('text', text: ' tail'),
          ],
        ),
      ]);
      for (final position in [1, 2, 4, 7]) {
        final range = ft.linkAt(node, position)!;
        expect((range.from, range.to, range.href), (1, 7, 'https://a.com'));
      }
      expect(ft.linkAt(node, 8), isNull);
    },
  );

  testWidgets(
    'real node children virtualise 1M chars and 1000 images, height arrival anchors scrolling',
    (tester) async {
      final original = generateLargeDocument(1000000);
      final blocks = <ft.Node>[];
      var inserted = 0;
      for (final block in original.content) {
        blocks.add(block);
        if (inserted < 1000) {
          blocks.add(schema.node('image', attrs: {'src': '${inserted++}'}));
        }
      }
      while (inserted < 1000) {
        blocks.add(schema.node('image', attrs: {'src': '${inserted++}'}));
      }
      blocks.add(p('end'));
      final controller = ft.TiptapController(doc: doc(blocks));
      final height = ValueNotifier(200.0);
      addTearDown(height.dispose);
      var builds = 0;
      final key = await mount(
        tester,
        controller,
        estimate: (_, _) => 200,
        views: {
          'image': (_, view) {
            builds++;
            return ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (_, value, _) => SizedBox(
                key: ValueKey('image-${view.node.attrs['src']}'),
                height: value,
              ),
            );
          },
        },
      );
      expect(builds, lessThan(25));
      expect(find.byType(ValueListenableBuilder<double>), findsWidgets);
      final firstImage = blocks.indexWhere((n) => n.type == 'image');
      final imagePosition = controller.state.doc.content.positionAt(firstImage);
      final geometry = key.currentState!.geometry!;
      final imageY = geometry.rowRect(imagePosition).top;
      key.currentState!.scrollController.jumpTo(imageY + 100);
      await tester.pump();
      await tester.pump();
      final anchor = geometry.positionForOffset(const Offset(20, 300));
      final old = geometry.rowRect(anchor).top;
      height.value = 300;
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The first partially visible image remains pinned at the same top pixel.
      expect(geometry.rowRect(imagePosition).top, closeTo(-100, 1));
      expect(geometry.rowRect(anchor).top, greaterThanOrEqualTo(old - 1));
      expect(
        find.byType(ValueListenableBuilder<double>).evaluate().length,
        lessThan(12),
      );
      final layouts = controller.diagnostics.blockLayouts;
      controller.exec('insertText', {'text': 'x'});
      await tester.pump();
      expect(controller.diagnostics.blockLayouts - layouts, lessThan(5));
      expect(builds, lessThan(100));
    },
  );

  testWidgets(
    'tap selects an atom without opening input; attrs, toolbar geometry and enter work',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([
          schema.node('image', attrs: {'src': 'a'}),
          p(''),
        ]),
      );
      ft.TiptapNodeView? view;
      final key = await mount(
        tester,
        controller,
        views: {
          'image': (_, next) {
            view = next;
            return const SizedBox(height: 120, child: Text('host-image'));
          },
        },
      );
      await tester.tap(find.text('host-image'));
      await tester.pump();
      await tester.pump();
      expect(controller.state.selection, isA<ft.NodeSelection>());
      expect(tester.testTextInput.isVisible, isFalse);
      expect(controller.selectedNode.value!.type, 'image');
      expect(
        controller.selectedNode.value!.rect.height,
        greaterThanOrEqualTo(120),
      );
      view!.updateAttrs({'name': 'changed'});
      await tester.pump();
      expect(controller.state.doc.child(0).attrs['name'], 'changed');
      controller.exec('splitBlock');
      await tester.pump();
      expect(controller.state.doc.childCount, 2);
      expect(controller.state.selection, const ft.TextSelection(2));
      expect(key.currentState!.geometry!.rowCount, 2);
    },
  );

  testWidgets(
    'selected atom accepts hardware typing without opening the keyboard on tap',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([schema.node('image'), p('')]),
      );
      await mount(
        tester,
        controller,
        views: {
          'image': (_, _) => const SizedBox(height: 100, child: Text('atom')),
        },
      );
      await tester.tap(find.text('atom'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.pump();
      expect(controller.state.doc.child(0).type, 'image');
      expect(controller.state.doc.child(1).textContent, 'a');
      expect(controller.state.selection, const ft.TextSelection(3));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'visible node view state survives attrs updates and block moves',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([
          p('before'),
          schema.node('video', attrs: {'src': 'movie'}),
          p(''),
        ]),
      );
      await mount(
        tester,
        controller,
        views: {
          'video': (_, _) => StatefulBuilder(
            key: const ValueKey('probe'),
            builder: (_, _) => const SizedBox(height: 80),
          ),
        },
      );
      final state = tester.state(find.byKey(const ValueKey('probe')));
      controller.exec('setNodeSelection', {'position': 8});
      controller.exec('setMediaName', {'name': 'new name'});
      await tester.pump();
      expect(tester.state(find.byKey(const ValueKey('probe'))), same(state));
      controller.exec('moveBlockUp');
      await tester.pump();
      expect(tester.state(find.byKey(const ValueKey('probe'))), same(state));
      expect(controller.state.doc.child(0).type, 'video');
    },
  );

  testWidgets(
    'selecting a tall atom does not scroll to the paragraph after it',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([schema.node('image'), p('')]),
      );
      final key = await mount(
        tester,
        controller,
        views: {
          'image': (_, _) =>
              const SizedBox(height: 1200, child: Text('tall-atom')),
        },
      );
      await tester.tapAt(const Offset(100, 200));
      await tester.pump();
      await tester.pump();
      expect(controller.state.selection, isA<ft.NodeSelection>());
      expect(key.currentState!.scrollController.offset, 0);
    },
  );

  testWidgets(
    'inline chip is a measured placeholder, hit-tests and deletes as one unit',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([
          schema.node(
            'paragraph',
            content: [
              schema.node('text', text: 'a '),
              schema.node('diaryLink', attrs: {'id': '42', 'label': 'A diary'}),
              schema.node('text', text: ' end'),
            ],
          ),
        ]),
      );
      String? tapped;
      final key = await mount(
        tester,
        controller,
        onReference: (id) => tapped = id,
      );
      final box = key.currentState!.geometry!.selectionRects(3, 4).single;
      expect(box.width, greaterThan(20));
      final editor = tester.getTopLeft(find.byType(ft.TiptapEditor));
      await tester.tapAt(editor + box.center);
      await tester.pump();
      expect(tapped, isNull);
      controller.setSelection(const ft.TextSelection(4));
      controller.exec('deleteBackward');
      expect(
        controller.state.doc.child(0).content.any((n) => n.type == 'diaryLink'),
        isFalse,
      );
      expect(controller.state.doc.child(0).textContent, 'a  end');
    },
  );

  testWidgets(
    'readonly links invoke the host while editable taps only place the caret',
    (tester) async {
      final controller = ft.TiptapController(
        doc: doc([
          schema.node(
            'paragraph',
            content: [
              schema.node(
                'text',
                text: 'example',
                marks: [
                  schema.mark('link', {'href': 'https://example.com'}),
                ],
              ),
            ],
          ),
        ]),
      );
      String? tapped;
      final key = await mount(
        tester,
        controller,
        readOnly: true,
        onLink: (href) => tapped = href,
      );
      final rect = key.currentState!.geometry!.selectionRects(1, 8).single;
      await tester.tapAt(
        tester.getTopLeft(find.byType(ft.TiptapEditor)) + rect.center,
      );
      await tester.pump();
      expect(tapped, 'https://example.com');
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );

  testWidgets(
    'suggestions debounce, cancel stale requests and allow keyboard insertion/dismissal',
    (tester) async {
      final requests =
          <
            (
              String,
              ft.TiptapCancellation,
              Completer<List<ft.TiptapReferenceItem>>,
            )
          >[];
      final controller = ft.TiptapController(
        doc: doc([p('')]),
        referenceCandidates: (query, cancellation) {
          final result = Completer<List<ft.TiptapReferenceItem>>();
          requests.add((query, cancellation, result));
          return result.future;
        },
      );
      await mount(tester, controller, autofocus: true);
      controller.exec('insertText', {'text': '[[a'});
      await tester.pump(const Duration(milliseconds: 199));
      expect(requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.single.$1, 'a');
      controller.exec('insertText', {'text': 'b'});
      await tester.pump(const Duration(milliseconds: 200));
      expect(requests[0].$2.cancelled, isTrue);
      requests[0].$3.complete([
        const ft.TiptapReferenceItem(id: 'stale', label: 'stale'),
      ]);
      await tester.pump();
      expect(controller.suggestion.value!.items, isEmpty);
      requests[1].$3.complete([
        const ft.TiptapReferenceItem(id: '42', label: 'Diary'),
      ]);
      await tester.pump();
      expect(controller.suggestion.value!.caretRect.height, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.state.doc.child(0).child(0).type, 'diaryLink');
      expect(controller.suggestion.value, isNull);
      controller.exec('insertText', {'text': '[['});
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.suggestion.value, isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'structured clipboard keeps marks, lists, media and reference chips across editors',
    (tester) async {
      final source = ft.TiptapController(
        doc: doc([
          schema.node(
            'bulletList',
            content: [
              schema.node(
                'listItem',
                content: [
                  schema.node(
                    'paragraph',
                    content: [
                      schema.node(
                        'text',
                        text: 'bold',
                        marks: [schema.mark('bold')],
                      ),
                      schema.node(
                        'diaryLink',
                        attrs: {'id': '42', 'label': 'Diary'},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          schema.node('image', attrs: {'src': 'asset'}),
          p(''),
        ]),
      );
      source.setSelection(ft.AllSelection(source.state.doc));
      await source.copy();
      final target = ft.TiptapController(doc: doc([p('')]));
      addTearDown(source.dispose);
      addTearDown(target.dispose);
      await target.paste();
      expect(target.state.doc.toJson(), source.state.doc.toJson());
      expect(
        target.state.doc.child(0).child(0).child(0).child(0).marks.single.type,
        'bold',
      );
      expect(target.state.doc.child(1).attrs['src'], 'asset');
      var calls = 0;
      await target.paste(
        text: '# title\ntext',
        onPasteText: (text) {
          calls++;
          return {
            'type': 'doc',
            'content': [
              {
                'type': 'heading',
                'attrs': {'level': 1},
                'content': [
                  {'type': 'text', 'text': 'title'},
                ],
              },
              {
                'type': 'paragraph',
                'content': [
                  {'type': 'text', 'text': 'text'},
                ],
              },
            ],
          };
        },
      );
      expect(calls, 1);
      expect(target.state.doc.content.any((n) => n.type == 'heading'), isTrue);
      expect(jsonDecode(target.json), target.state.doc.toJson());
    },
  );

  testWidgets(
    'plain paste splits paragraphs, code bypasses the markdown hook and cut is undoable',
    (tester) async {
      final controller = ft.TiptapController(doc: doc([p('ab')]));
      addTearDown(controller.dispose);
      controller.setSelection(const ft.TextSelection(2));
      await controller.paste(text: 'one\n\ntwo');
      expect(controller.state.doc.content.map((n) => n.textContent), [
        'aone',
        'twob',
      ]);
      controller.setSelection(ft.AllSelection(controller.state.doc));
      await controller.copy(cut: true);
      expect(controller.state.doc.textContent, '');
      controller.exec('undo');
      expect(controller.state.doc.textContent, 'aonetwob');
      controller.replaceDocument(
        doc([
          schema.node(
            'codeBlock',
            content: [schema.node('text', text: 'code')],
          ),
          p(''),
        ]),
      );
      controller.setSelection(const ft.TextSelection(5));
      var calls = 0;
      await controller.paste(
        text: '\n# literal',
        onPasteText: (_) {
          calls++;
          return null;
        },
      );
      expect(calls, 0);
      expect(controller.state.doc.child(0).textContent, 'code\n# literal');
    },
  );

  testWidgets(
    'an async host paste is cancelled when editing becomes unavailable',
    (tester) async {
      final controller = ft.TiptapController(doc: doc([p('')]));
      addTearDown(controller.dispose);
      final result = Completer<Map<String, dynamic>?>();
      var allowed = true;
      final paste = controller.paste(
        text: '# title\ntext',
        canPaste: () => allowed,
        onPasteText: (_) => result.future,
      );
      allowed = false;
      result.complete({
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'late'},
            ],
          },
        ],
      });
      await paste;
      expect(controller.state.doc.textContent, '');
    },
  );

  test('selected media typing, deletion and moving list/task units retain valid documents', () {
    for (final list in ['bulletList', 'taskList']) {
      final item = list == 'taskList' ? 'taskItem' : 'listItem';
      final node = doc([
        schema.node(
          list,
          content: [
            schema.node(item, content: [p('one'), schema.node('image')]),
            schema.node(item, content: [p('two')]),
          ],
        ),
        p(''),
      ]);
      var state = ft.EditorState(
        doc: node,
        selection: const ft.TextSelection(13),
      );
      state = state.apply(commands.execute(state, 'moveBlockUp'));
      expect(state.doc.child(0).child(0).child(0).textContent, 'two');
      expect(schema.validContent('doc', state.doc.content), isTrue);
    }
  });
}
