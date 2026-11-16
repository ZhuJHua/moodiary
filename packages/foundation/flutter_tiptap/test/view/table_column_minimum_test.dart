import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

final _schema = ft.Schema.standard();

final _paragraph = TestNodes(_schema).p;

ft.Node _cell(ft.Node content, {int colspan = 1, List<int>? colwidth}) =>
    TestNodes(_schema)
        .cell([content], attrs: {'colspan': colspan, 'colwidth': colwidth});

ft.Node _row(List<ft.Node> cells) => _schema.node('tableRow', content: cells);

ft.Node _list(String type, ft.Node child) => _schema.node(
  type,
  content: [
    _schema.node(
      type == 'taskList' ? 'taskItem' : 'listItem',
      content: [if (child.type != 'paragraph') _paragraph(''), child],
    ),
  ],
);

int _position(ft.Node doc, ft.Node target, [int start = -1]) {
  if (identical(doc, target)) return start;
  var position = start + 1;
  for (final child in doc.content) {
    final found = _position(child, target, position);
    if (found >= 0) return found;
    position += child.nodeSize;
  }
  return -1;
}

const _style = ft.TiptapEditorStyle(padding: EdgeInsets.zero);

Future<ft.TiptapGeometry> _mount(
  WidgetTester tester,
  ft.TiptapController controller, {
  double width = 390,
  ft.TiptapEditorStyle style = _style,
  Map<String, ft.TiptapNodeViewBuilder> views = const {},
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 600,
          child: ft.TiptapEditor(
            controller: controller,
            readOnly: true,
            style: style,
            nodeViews: views,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester
      .state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor))
      .geometry!;
}

void main() {
  testWidgets(
    'phone table widens code column, scrolls and preserves text geometry',
    (tester) async {
      final code = _schema.node(
        'codeBlock',
        attrs: {'language': 'a very long language label that must be clipped'},
        content: [
          _schema.node('text', text: List.filled(80, 'value').join(' ')),
        ],
      );
      final last = _paragraph('last column');
      final table = _schema.node(
        'table',
        content: [
          _row([_cell(code), _cell(_paragraph('middle')), _cell(last)]),
        ],
      );
      final controller = ft.TiptapController(
        doc: _schema.node('doc', content: [table]),
      );
      addTearDown(controller.dispose);
      final json = controller.json;
      final geometry = await _mount(tester, controller);
      final position = _position(controller.state.doc, code);
      final cell = geometry.cellRect(position)!;
      expect(
        cell.width,
        closeTo(240 + _style.tableCellPadding.horizontal, .01),
      );
      final tableBefore = geometry.horizontalScrollMetrics(1)!;
      expect(tableBefore.maxScrollExtent, closeTo(130, .01));
      expect(
        geometry.horizontalScrollMetrics(position)!.maxScrollExtent,
        greaterThan(0),
      );
      final caret = geometry.caretRect(position + 5);
      expect(geometry.positionForOffset(caret.center), position + 5);
      await tester.dragFrom(
        geometry.horizontalScrollMetrics(position)!.viewport.center,
        const Offset(-60, 0),
      );
      await tester.pumpAndSettle();
      final codeOffset = geometry.horizontalScrollMetrics(position)!.offset;
      expect(codeOffset, greaterThan(20));
      expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
      await tester.dragFrom(
        Offset(tableBefore.viewport.right - 10, tableBefore.viewport.center.dy),
        const Offset(-70, 0),
      );
      await tester.pump();
      expect(
        geometry.horizontalScrollMetrics(1)!.indicatorOpacity,
        greaterThan(0),
      );
      await tester.pumpAndSettle();
      expect(geometry.horizontalScrollMetrics(1)!.offset, greaterThan(20));
      expect(
        geometry.horizontalScrollMetrics(position)!.offset,
        closeTo(codeOffset, .01),
      );
      final lastPosition = _position(controller.state.doc, last) + 3;
      controller.setSelection(ft.TextSelection(lastPosition));
      await tester.pumpAndSettle();
      final revealed = geometry.caretRect(lastPosition);
      expect(revealed.center.dx, inInclusiveRange(0, 390));
      expect(geometry.positionForOffset(revealed.center), lastPosition);
      expect(
        geometry.selectionRects(lastPosition - 1, lastPosition + 2),
        isNotEmpty,
      );
      expect(controller.json, json);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'media, nested lists, tasks and quotes contribute their minimums',
    (tester) async {
      final image = _schema.node('image', attrs: {'src': 'image.png'}),
          nested = _list(
            'bulletList',
            _list('orderedList', _list('bulletList', _paragraph('nested'))),
          ),
          tasks = _list('taskList', _list('taskList', _paragraph('task'))),
          quote = _schema.node(
            'blockquote',
            content: [_schema.node('horizontalRule')],
          );
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _schema.node(
              'table',
              content: [
                _row([_cell(image), _cell(nested), _cell(tasks), _cell(quote)]),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      const style = ft.TiptapEditorStyle(
        padding: EdgeInsets.zero,
        listIndent: 30,
        taskIndent: 28,
        nestedTaskIndent: 8,
        quoteIndent: 22,
        tableMediaMinWidth: 190,
      );
      var imageWidth = 0.0;
      final geometry = await _mount(
        tester,
        controller,
        width: 150,
        style: style,
        views: {
          'image': (_, view) {
            imageWidth = view.width;
            return const SizedBox(height: 30);
          },
        },
      );
      double width(ft.Node node) =>
          geometry.cellRect(_position(controller.state.doc, node))!.width;
      expect(width(image), closeTo(210, .01));
      expect(imageWidth, closeTo(190, .01));
      final marker = TextPainter(
        text: TextSpan(text: '1.', style: style.paragraph),
        textDirection: TextDirection.ltr,
      )..layout();
      final orderedGutter = marker.maxIntrinsicWidth + 8;
      marker.dispose();
      expect(width(nested), closeTo(64 + 2 * 30 + orderedGutter, .01));
      expect(width(tasks), closeTo(64 + 2 * 28 + 8, .01));
      expect(width(quote), closeTo(64 + 22 + 24, .01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'spanned cell shortfall spreads evenly without changing colwidth',
    (tester) async {
      final code = _schema.node(
            'codeBlock',
            content: [_schema.node('text', text: 'code')],
          ),
          left = _paragraph('left'),
          right = _paragraph('right');
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _schema.node(
              'table',
              content: [
                _row([
                  _cell(code, colspan: 2, colwidth: [40, 80]),
                ]),
                _row([
                  _cell(left, colwidth: [40]),
                  _cell(right, colwidth: [80]),
                ]),
              ],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final before = controller.json;
      final geometry = await _mount(tester, controller, width: 100);
      double width(ft.Node node) =>
          geometry.cellRect(_position(controller.state.doc, node))!.width;
      expect(width(code), closeTo(260, .01));
      expect(width(left), closeTo(122, .01));
      expect(width(right), closeTo(138, .01));
      expect(controller.json, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('column cache follows viewport, style and changed cell content', (
    tester,
  ) async {
    final paragraph = _paragraph('change me');
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _schema.node(
            'table',
            content: [
              _row([
                _cell(paragraph),
                _cell(_paragraph('other')),
                _cell(_paragraph('last')),
              ]),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final position = _position(controller.state.doc, paragraph);
    var geometry = await _mount(tester, controller);
    expect(geometry.cellRect(position)!.width, closeTo(130, .01));
    controller.setSelection(ft.TextSelection(position + 1));
    expect(controller.exec('setCodeBlock'), isNotNull);
    await tester.pumpAndSettle();
    expect(geometry.cellRect(position)!.width, closeTo(260, .01));
    for (final width in [792.0, 450.0, 390.0]) {
      geometry = await _mount(tester, controller, width: width);
      expect(
        geometry.cellRect(position)!.width,
        closeTo(width == 792 ? 264 : 260, .01),
      );
    }
    geometry = await _mount(
      tester,
      controller,
      width: 150,
      style: const ft.TiptapEditorStyle(
        padding: EdgeInsets.zero,
        tableCodeMinWidth: 320,
      ),
    );
    expect(geometry.cellRect(position)!.width, closeTo(340, .01));
    geometry = await _mount(
      tester,
      controller,
      width: 150,
      style: const ft.TiptapEditorStyle(
        padding: EdgeInsets.zero,
        tableCodeMinWidth: 1,
      ),
    );
    expect(
      geometry.cellRect(position)!.width,
      closeTo(
        _style.codeBlockPadding.horizontal +
            64 +
            _style.tableCellPadding.horizontal,
        .01,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
