import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

final _schema = ft.Schema.standard();

ft.Node _paragraph(String text) => _schema.node(
  'paragraph',
  content: [if (text.isNotEmpty) _schema.node('text', text: text)],
);

Iterable<(ft.Node, int)> _nodes(ft.Node node, [int position = -1]) sync* {
  yield (node, position);
  var offset = position + 1;
  for (final child in node.content) {
    yield* _nodes(child, offset);
    offset += child.nodeSize;
  }
}

void main() {
  testWidgets(
    'equal media nodes keep independent measurements and stack origins',
    (tester) async {
      final doc = _schema.node(
        'doc',
        content: [
          _schema.node(
            'table',
            content: [
              _schema.node(
                'tableRow',
                content: [
                  _schema.node(
                    'tableCell',
                    content: [
                      _schema.node('image', attrs: {'src': 'same.png'}),
                      _schema.node('image', attrs: {'src': 'same.png'}),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final positions = [
        for (final (node, position) in _nodes(doc))
          if (node.type == 'image') position,
      ];
      final controller = ft.TiptapController(doc: doc),
          height = ValueNotifier(61.0),
          key = GlobalKey<ft.TiptapEditorState>();
      addTearDown(controller.dispose);
      addTearDown(height.dispose);
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            nodeViews: {
              'image': (_, view) => ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (_, value, child) => SizedBox(
                  height: view.position == positions.first ? value : 61,
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      height.value = 102;
      await tester.pumpAndSettle();
      final geometry = key.currentState!.geometry!;
      expect(geometry.rowRect(positions.first).height, 102);
      expect(geometry.rowRect(positions.last).height, 61);
      expect(
        geometry.rowRect(positions.last).top,
        greaterThanOrEqualTo(geometry.rowRect(positions.first).bottom),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a long table releases offscreen paragraph layouts after measuring rowspans',
    (tester) async {
      final table = _schema.node(
        'table',
        content: [
          for (var index = 0; index < 600; index++)
            _schema.node(
              'tableRow',
              content: [
                if (index != 1)
                  _schema.node(
                    'tableCell',
                    attrs: index == 0 ? {'rowspan': 2} : const {},
                    content: [_paragraph('row $index')],
                  ),
              ],
            ),
        ],
      );
      final controller = ft.TiptapController(
        doc: _schema.node('doc', content: [table]),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        CupertinoApp(home: ft.TiptapEditor(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(512));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('merged cells keep measured stacks aligned after media resize', (
    tester,
  ) async {
    final images = [
      for (var index = 0; index < 3; index++)
        _schema.node('image', attrs: {'src': '$index'}),
    ];
    final table = _schema.node(
      'table',
      content: [
        _schema.node(
          'tableRow',
          content: [
            _schema.node(
              'tableCell',
              attrs: {'rowspan': 2},
              content: [
                images[0],
                images[1],
                _paragraph('after stacked media'),
              ],
            ),
            _schema.node('tableCell', content: [_paragraph('short')]),
          ],
        ),
        _schema.node(
          'tableRow',
          content: [
            _schema.node(
              'tableCell',
              content: [images[2], _paragraph('unequal row')],
            ),
          ],
        ),
      ],
    );
    final controller = ft.TiptapController(
      doc: _schema.node('doc', content: [table]),
    );
    final key = GlobalKey<ft.TiptapEditorState>();
    final height = ValueNotifier(80.0);
    addTearDown(controller.dispose);
    addTearDown(height.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 390,
          child: ft.TiptapEditor(
            key: key,
            controller: controller,
            nodeViews: {
              'image': (_, view) => ValueListenableBuilder<double>(
                valueListenable: height,
                builder: (_, value, child) => SizedBox(
                  key: ValueKey(view.node.attrs['src']),
                  height: view.node.attrs['src'] == '2' ? 230 : value,
                ),
              ),
            },
          ),
        ),
      ),
    );
    final positions = {
      for (final (node, position) in _nodes(controller.state.doc))
        if (node.type == 'image') node.attrs['src']: position,
    };
    for (final next in [80.0, 180.0, 45.0]) {
      height.value = next;
      await tester.pumpAndSettle();
      final geometry = key.currentState!.geometry!;
      final first = geometry.rowRect(positions['0']!),
          second = geometry.rowRect(positions['1']!);
      expect(first.height, closeTo(next, .01));
      expect(second.top, greaterThanOrEqualTo(first.bottom));
      for (final entry in positions.entries) {
        final expected = geometry.rowRect(entry.value);
        final render = tester.renderObject<RenderBox>(
          find.byKey(ValueKey(entry.key)),
        );
        final editor = tester.renderObject<RenderBox>(
          find.byType(ft.TiptapEditor),
        );
        final painted =
            editor.globalToLocal(render.localToGlobal(Offset.zero)) &
            render.size;
        expect(painted.top, closeTo(expected.top, .01));
        expect(painted.bottom, closeTo(expected.bottom, .01));
        final cell = geometry.cellRect(entry.value)!;
        expect(expected.top, greaterThanOrEqualTo(cell.top));
        expect(expected.bottom, lessThanOrEqualTo(cell.bottom + .01));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'compact nested ordered markers keep full labels in their gutters',
    (tester) async {
      ft.Node list(ft.Node child) => _schema.node(
        'orderedList',
        attrs: {'start': 987654321},
        content: [
          _schema.node('listItem', content: [_paragraph('label'), child]),
        ],
      );
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [list(list(list(_paragraph('deep text'))))],
        ),
      );
      final key = GlobalKey<ft.TiptapEditorState>();
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(180, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(key: key, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      for (final (node, position) in _nodes(controller.state.doc)) {
        if (node.type != 'paragraph' || node.textContent != 'label') continue;
        final marker = key.currentState!.debugListMarker(position)!;
        final content = key.currentState!.geometry!.rowRect(position);
        expect(marker.bounds.left, greaterThanOrEqualTo(16 - .01));
        expect(marker.bounds.right, lessThanOrEqualTo(content.left));
        expect(content.width, greaterThanOrEqualTo(74));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'wrapped trailing whitespace has bounded reversible caret geometry',
    (tester) async {
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [_paragraph('abcdefghij     klmnop     ')],
        ),
      );
      final key = GlobalKey<ft.TiptapEditorState>();
      addTearDown(controller.dispose);
      await tester.binding.setSurfaceSize(const Size(180, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            style: const ft.TiptapEditorStyle(
              paragraph: TextStyle(fontSize: 17, height: 1.65),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final geometry = key.currentState!.geometry!, block = geometry.rowRect(0);
      for (
        var position = 1;
        position < controller.state.doc.child(0).nodeSize;
        position++
      ) {
        final caret = geometry.caretRect(position);
        expect(caret.left, greaterThanOrEqualTo(block.left - caret.width / 2));
        expect(caret.right, lessThanOrEqualTo(block.right + caret.width / 2));
        expect(
          geometry.positionForOffset(caret.center),
          position,
          reason: '$position',
        );
      }
      for (final rect in geometry.selectionRects(
        1,
        controller.state.doc.content.size - 1,
      )) {
        expect(block.contains(rect.topLeft), isTrue);
        expect(rect.right, lessThanOrEqualTo(block.right));
        expect(rect.bottom, lessThanOrEqualTo(block.bottom));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
