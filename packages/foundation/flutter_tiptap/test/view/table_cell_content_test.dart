import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_lint/testing.dart';

final _schema = ft.Schema.standard();

ft.Node _paragraph(String text) => _schema.node(
  'paragraph',
  content: [if (text.isNotEmpty) _schema.node('text', text: text)],
);

ft.Node _list(String type, List<ft.Node> blocks) => _schema.node(
  type,
  content: [
    for (final block in blocks)
      _schema.node(
        type == 'taskList' ? 'taskItem' : 'listItem',
        content: [if (block.type != 'paragraph') _paragraph(''), block],
      ),
  ],
);

ft.Node _table(
  List<ft.Node> blocks, {
  bool header = false,
  bool second = false,
}) => _schema.node(
  'table',
  content: [
    _schema.node(
      'tableRow',
      content: [
        _schema.node(header ? 'tableHeader' : 'tableCell', content: blocks),
        if (second)
          _schema.node('tableCell', content: [_paragraph('other cell')]),
      ],
    ),
  ],
);

Iterable<(ft.Node, int)> _nodes(ft.Node node, [int start = -1]) sync* {
  yield (node, start);
  var position = start + 1;
  for (final child in node.content) {
    yield* _nodes(child, position);
    position += child.nodeSize;
  }
}

int _position(ft.TiptapController controller, String text) =>
    _nodes(controller.state.doc)
        .firstWhere(
          (entry) => entry.$1.isTextblock && entry.$1.textContent == text,
        )
        .$2;

const _style = ft.TiptapEditorStyle(
  padding: EdgeInsets.zero,
  tableFixedLayout: true,
  tableMinColumnWidth: 120,
  tableMinRowHeight: 0,
  blockSpacing: 4,
  listIndent: 24,
  paragraph: TextStyle(fontSize: 16, height: 1.25, color: Color(0xff000000)),
  codeBlock: TextStyle(fontSize: 16, height: 1.25, color: Color(0xff000000)),
  markerColor: Color(0xffff0000),
  quoteBorderColor: Color(0xff0000ff),
  ruleColor: Color(0xffff00ff),
  codeBackground: Color(0xff00ff00),
  selectionColor: Color(0xff8800ff),
  composingColor: Color(0xff00ffff),
  caretColor: Color(0xffff8800),
  overflowFadeWidth: 0,
);

Future<GlobalKey<ft.TiptapEditorState>> _mount(
  WidgetTester tester,
  ft.TiptapController controller, {
  double width = 420,
  bool readOnly = true,
  GlobalKey? boundary,
  ft.TiptapNodeViewBuilder? header,
  Map<String, ft.TiptapNodeViewBuilder> views = const {},
  ft.TiptapNodeHeightEstimator? estimator,
  ft.TiptapCodeHighlighter? highlighter,
  ft.TiptapEditorStyle style = _style,
}) async {
  final key = GlobalKey<ft.TiptapEditorState>();
  await tester.pumpWidget(
    CupertinoApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xffffffff),
            child: SizedBox(
              width: width,
              height: 600,
              child: ft.TiptapEditor(
                key: key,
                controller: controller,
                readOnly: readOnly,
                autofocus: !readOnly,
                style: style,
                codeBlockHeader: header,
                nodeViews: views,
                nodeHeightEstimator: estimator,
                codeHighlighter: highlighter,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

List<ft.Node> _richBlocks() => [
  _schema.node(
    'bulletList',
    content: [
      _schema.node(
        'listItem',
        content: [
          _paragraph('bullet'),
          _list('bulletList', [_paragraph('nested bullet')]),
        ],
      ),
    ],
  ),
  _schema.node(
    'orderedList',
    attrs: {'start': 7},
    content: [
      _schema.node('listItem', content: [_paragraph('ordered one')]),
      _schema.node('listItem', content: [_paragraph('ordered two')]),
    ],
  ),
  _list('taskList', [_paragraph('task')]),
  _schema.node(
    'blockquote',
    content: [
      _list('bulletList', [_paragraph('quoted bullet')]),
    ],
  ),
  _list('bulletList', [
    _schema.node(
      'codeBlock',
      attrs: {'language': 'dart'},
      content: [_schema.node('text', text: 'value = 1;')],
    ),
  ]),
  _schema.node('horizontalRule'),
  _schema.node('image', attrs: {'src': 'test.png', 'widthPercent': 50}),
];

Future<int> _pixels(
  WidgetTester tester,
  GlobalKey boundary,
  Color color, {
  Rect? region,
  int tolerance = 0,
}) async => (await tester.runAsync(() async {
  final image =
      await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  var count = 0;
  for (var vertical = 0; vertical < image.height; vertical++) {
    for (var horizontal = 0; horizontal < image.width; horizontal++) {
      if (region != null &&
          !region.contains(
            Offset(horizontal.toDouble(), vertical.toDouble()),
          )) {
        continue;
      }
      final offset = (vertical * image.width + horizontal) * 4;
      if ((bytes[offset] - color.r * 255).abs() <= tolerance &&
          (bytes[offset + 1] - color.g * 255).abs() <= tolerance &&
          (bytes[offset + 2] - color.b * 255).abs() <= tolerance &&
          bytes[offset + 3] == 255) {
        count++;
      }
    }
  }
  image.dispose();
  return count;
}))!;

void main() {
  testWidgets('deleting spanning rows refreshes geometry through undo redo', (
    tester,
  ) async {
    ft.Node cell(String text, {int rowspan = 1}) => _schema.node(
      'tableCell',
      attrs: {'rowspan': rowspan},
      content: [_paragraph(text)],
    );
    ft.Node row(List<ft.Node> cells) =>
        _schema.node('tableRow', content: cells);
    final table = _schema.node(
      'table',
      content: [
        row([cell('first left'), cell('first right')]),
        row([cell('spanning left', rowspan: 3), cell('second right')]),
        row([cell('spanning right', rowspan: 2)]),
        row([]),
      ],
    );
    final controller = ft.TiptapController(
      doc: _schema.node('doc', content: [table, _paragraph('trailing')]),
    );
    addTearDown(controller.dispose);
    var key = await _mount(tester, controller, readOnly: false);
    final originalDoc = controller.state.doc.toJson();
    List<Rect> geometry() => [
      for (final (node, position) in _nodes(controller.state.doc))
        if (node.isTextblock) ...[
          key.currentState!.geometry!.rowRect(position),
          ?key.currentState!.geometry!.cellRect(position + 1),
          key.currentState!.geometry!.caretRect(position + 1),
        ],
    ];

    final originalGeometry = geometry();
    final selection = _position(controller, 'spanning right') + 2;
    controller.setSelection(ft.TextSelection(selection, selection));
    await tester.pumpAndSettle();
    controller.exec('deleteRow');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final editedTable = controller.state.doc.child(0);
    expect(editedTable.childCount, 2);
    expect(identical(editedTable.child(0), table.child(0)), isTrue);
    expect(ft.TableMap.get(editedTable).hasRowspan, isFalse);
    final editedDoc = controller.state.doc.toJson();
    final editedGeometry = geometry();

    for (var iteration = 0; iteration < 2; iteration++) {
      controller.exec('undo');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.state.doc.toJson(), originalDoc);
      expect(geometry(), originalGeometry);
      controller.exec('redo');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.state.doc.toJson(), editedDoc);
      expect(geometry(), editedGeometry);
    }

    key = await _mount(tester, controller, readOnly: false);
    expect(geometry(), editedGeometry);
    for (final text in [
      'first left',
      'first right',
      'spanning left',
      'trailing',
    ]) {
      final position = _position(controller, text) + 2;
      final caret = key.currentState!.geometry!.caretRect(position);
      expect(
        key.currentState!.geometry!.positionForOffset(caret.center),
        position,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('font notifications remeasure retained rowspan geometry', (
    tester,
  ) async {
    const family = 'TiptapRowspanLateFont';
    const style = ft.TiptapEditorStyle(
      padding: EdgeInsets.zero,
      tableFixedLayout: true,
      tableMinColumnWidth: 120,
      tableMinRowHeight: 0,
      blockSpacing: 4,
      paragraph: TextStyle(
        fontFamily: family,
        fontSize: 16,
        height: 1.25,
        color: Color(0xff000000),
      ),
    );
    final texts = [
      '${'little words in spanning cells ' * 4}end',
      '${'right column first row ' * 2}end',
      '${'right column second row ' * 2}end',
    ];
    ft.Node cell(int index, {int rowspan = 1}) => _schema.node(
      'tableCell',
      attrs: {'rowspan': rowspan},
      content: [_paragraph(texts[index])],
    );
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _schema.node(
            'table',
            content: [
              _schema.node('tableRow', content: [cell(0, rowspan: 2), cell(1)]),
              _schema.node('tableRow', content: [cell(2)]),
            ],
          ),
          _paragraph('trailing'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final boundary = GlobalKey();
    var key = await _mount(
      tester,
      controller,
      width: 320,
      boundary: boundary,
      style: style,
    );
    List<Rect> geometry() => [
      for (final text in texts) ...[
        key.currentState!.geometry!.cellRect(_position(controller, text) + 1)!,
        key.currentState!.geometry!.rowRect(_position(controller, text)),
      ],
      key.currentState!.geometry!.rowRect(_position(controller, 'trailing')),
    ];
    final fallback = geometry();
    final fallbackLines = key.currentState!.geometry!
        .selectionRects(
          _position(controller, texts[0]) + 1,
          _position(controller, texts[0]) + texts[0].length + 1,
        )
        .length;
    await tester.runAsync(() async {
      final loader = FontLoader(family);
      loader.addFont(
        File('$repoRoot/packages/foundation/mui/assets/fonts/Dosis.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    });
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pumpAndSettle();
    final loaded = geometry();
    expect(loaded.first.width, fallback.first.width);
    expect(loaded[1].height, lessThan(fallback[1].height));
    expect(loaded.first.height, lessThan(fallback.first.height));
    expect(loaded[2].height, lessThan(fallback[2].height));
    expect(loaded[4].top, lessThan(fallback[4].top));
    expect(loaded.last.top, lessThan(fallback.last.top));

    for (final text in texts) {
      final position = _position(controller, text);
      final geometry = key.currentState!.geometry!;
      final cell = geometry.cellRect(position + 1)!;
      final rects = geometry.selectionRects(
        position + 1,
        position + text.length + 1,
      );
      if (text == texts.first) expect(rects.length, lessThan(fallbackLines));
      for (final rect in rects) {
        expect(cell.inflate(.01).contains(rect.topLeft), isTrue);
        expect(cell.inflate(.01).contains(rect.bottomRight), isTrue);
      }
      for (final offset in [1, text.length ~/ 2, text.length]) {
        final caret = geometry.caretRect(position + offset);
        expect(cell.inflate(.01).contains(caret.center), isTrue);
        expect(geometry.positionForOffset(caret.center), position + offset);
      }
      expect(
        await _pixels(
          tester,
          boundary,
          const Color(0xff000000),
          region: rects.last,
          tolerance: 80,
        ),
        greaterThan(0),
      );
    }

    key = await _mount(
      tester,
      controller,
      width: 320,
      boundary: boundary,
      style: style,
    );
    expect(geometry(), loaded);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rowspan keeps right column hit testing in grid order', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node(
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
                    attrs: {'rowspan': 2},
                    content: [_paragraph('A')],
                  ),
                  _schema.node('tableCell', content: [_paragraph('B')]),
                ],
              ),
              _schema.node(
                'tableRow',
                content: [
                  _schema.node('tableCell', content: [_paragraph('C')]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = await _mount(tester, controller, readOnly: false);
    final position = _position(controller, 'C') + 1;
    final caret = key.currentState!.geometry!.caretRect(position);
    expect(
      key.currentState!.geometry!.positionForOffset(caret.center),
      position,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide nested tables reveal and scroll their own cells', (
    tester,
  ) async {
    final nested = _schema.node(
      'table',
      content: [
        _schema.node(
          'tableRow',
          content: [
            for (var column = 0; column < 4; column++)
              _schema.node(
                'tableCell',
                content: [_paragraph('column $column')],
              ),
          ],
        ),
      ],
    );
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _table([_paragraph('outer'), nested]),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = await _mount(tester, controller, readOnly: false);
    final geometry = key.currentState!.geometry!;
    final position = _nodes(controller.state.doc)
        .firstWhere((entry) => identical(entry.$1, nested))
        .$2;
    final before = geometry.horizontalScrollMetrics(position)!;
    expect(before.maxScrollExtent, greaterThan(0));
    await tester.dragFrom(before.viewport.center, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(geometry.horizontalScrollMetrics(position)!.offset, greaterThan(20));
    controller.setSelection(
      ft.TextSelection(_position(controller, 'column 3') + 9),
    );
    await tester.pumpAndSettle();
    final caret = geometry.caretRect(controller.state.selection.head);
    expect(caret.right, lessThanOrEqualTo(410));
    expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nested tables reuse rich rows, media measurements and local code scrolling',
    (tester) async {
      final source = List.filled(60, 'nested code').join(' ');
      final nested = _table([
        _list('bulletList', [_paragraph('nested item')]),
        _list('taskList', [_paragraph('nested task')]),
        _schema.node(
          'codeBlock',
          attrs: {'language': 'dart'},
          content: [_schema.node('text', text: source)],
        ),
        _schema.node('image', attrs: {'src': 'nested.png'}),
      ]);
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _table([_paragraph('outer'), nested, _paragraph('outer end')]),
            _paragraph('after'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      var height = 40.0;
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);
      final key = await _mount(
        tester,
        controller,
        readOnly: false,
        views: {
          'image': (_, view) => ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (_, value, child) =>
                SizedBox(width: view.width, height: height),
          ),
        },
      );
      final state = key.currentState!, geometry = state.geometry!;
      final item = _position(controller, 'nested item');
      expect(state.debugListMarker(item), isNotNull);
      for (final label in ['nested item', 'nested task', source, 'outer end']) {
        final position = _position(controller, label) + 2;
        final caret = geometry.caretRect(position);
        expect(geometry.positionForOffset(caret.center), position);
        expect(geometry.selectionRects(position - 1, position + 1), isNotEmpty);
        expect(
          geometry.wordBoundary(position).start,
          greaterThanOrEqualTo(position - 1),
        );
      }
      final code = _position(controller, source);
      final metrics = geometry.horizontalScrollMetrics(code)!;
      await tester.dragFrom(metrics.viewport.center, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(geometry.horizontalScrollMetrics(code)!.offset, greaterThan(20));
      final checkbox = geometry.taskCheckboxRect(
        _position(controller, 'nested task'),
      )!;
      await tester.tapAt(checkbox.center);
      await tester.pump();
      expect(
        _nodes(controller.state.doc)
            .firstWhere((entry) => entry.$1.type == 'taskItem')
            .$1
            .attrs['checked'],
        isTrue,
      );
      final image = _nodes(controller.state.doc)
          .firstWhere((entry) => entry.$1.type == 'image')
          .$2;
      final before = geometry.rowRect(_position(controller, 'after')).top;
      final cell = geometry.cellRect(image)!;
      expect(cell.contains(geometry.rowRect(image).center), isTrue);
      height = 90;
      rebuild.value++;
      await tester.pumpAndSettle();
      expect(geometry.rowRect(image).height, 90);
      expect(
        geometry.rowRect(_position(controller, 'after')).top - before,
        closeTo(50, .01),
      );
      expect(geometry.cellRect(image)!.height - cell.height, closeTo(50, .01));
      final json = controller.state.doc.toJson();
      expect(_schema.fromJson(json).toJson(), json);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'cell rows share body indents, markers, code chrome and text geometry',
    (tester) async {
      final blocks = _richBlocks();
      final body = ft.TiptapController(
        doc: _schema.node('doc', content: blocks),
      );
      final cell = ft.TiptapController(
        doc: _schema.node('doc', content: [_table(blocks)]),
      );
      addTearDown(body.dispose);
      addTearDown(cell.dispose);
      final bodyKey = await _mount(
        tester,
        body,
        width: 400,
        views: {'image': (_, view) => SizedBox(width: view.width, height: 40)},
      );
      final reference = <String, (Rect, Rect, Rect?, String?)>{};
      for (final (node, position) in _nodes(body.state.doc)) {
        if (!node.isTextblock) continue;
        final geometry = bodyKey.currentState!.geometry!;
        final marker = bodyKey.currentState!.debugListMarker(position);
        reference[node.textContent] = (
          geometry.rowRect(position),
          geometry.caretRect(position + (node.content.isEmpty ? 1 : 2)),
          marker?.bounds,
          marker?.kind,
        );
      }
      final boundary = GlobalKey();
      final key = await _mount(
        tester,
        cell,
        boundary: boundary,
        views: {'image': (_, view) => SizedBox(width: view.width, height: 40)},
      );
      final geometry = key.currentState!.geometry!;
      for (final (node, position) in _nodes(cell.state.doc)) {
        if (!node.isTextblock) continue;
        final expected = reference[node.textContent]!;
        final row = geometry.rowRect(position),
            caret = geometry.caretRect(
              position + (node.content.isEmpty ? 1 : 2),
            );
        expect(
          row.left - 10,
          closeTo(expected.$1.left, .01),
          reason: node.textContent,
        );
        expect(row.width, closeTo(expected.$1.width, .01));
        expect(row.height, closeTo(expected.$1.height, .01));
        expect(
          caret.top - row.top,
          closeTo(expected.$2.top - expected.$1.top, .01),
        );
        expect(
          caret.left - row.left,
          closeTo(expected.$2.left - expected.$1.left, .01),
        );
        expect(
          geometry.positionForOffset(caret.center),
          position + (node.content.isEmpty ? 1 : 2),
        );
        final marker = key.currentState!.debugListMarker(position);
        expect(marker?.kind, expected.$4);
        if (marker != null) {
          expect(
            marker.bounds.left - row.left,
            closeTo(expected.$3!.left - expected.$1.left, .01),
          );
          expect(marker.baseline, closeTo(marker.textBaseline, .01));
        }
        if (!node.content.isEmpty) {
          expect(
            geometry.selectionRects(position + 1, position + node.nodeSize - 1),
            isNotEmpty,
          );
        }
        final at = position + (node.content.isEmpty ? 1 : 2);
        final word = geometry.wordBoundary(at),
            line = geometry.lineBoundary(at);
        expect(word.start, greaterThanOrEqualTo(position + 1));
        expect(word.end, lessThanOrEqualTo(position + node.nodeSize - 1));
        expect(line.start, position + 1);
      }
      for (final color in [
        const Color(0xffff0000),
        const Color(0xff0000ff),
        const Color(0xffff00ff),
        const Color(0xff00ff00),
      ]) {
        expect(
          await _pixels(
            tester,
            boundary,
            color,
            tolerance: color == const Color(0xffff00ff) ? 130 : 0,
          ),
          greaterThan(0),
          reason: '$color',
        );
      }
      final rule = _nodes(cell.state.doc)
          .firstWhere((entry) => entry.$1.type == 'horizontalRule')
          .$2;
      expect(geometry.positionForOffset(geometry.rowRect(rule).center), rule);
      expect(geometry.selectionRects(rule, rule + 1), isNotEmpty);
      final json = cell.state.doc.toJson();
      expect(_schema.fromJson(json).toJson(), json);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cell task checkbox paints, toggles by tap and exposes semantics',
    (tester) async {
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _table([
              _list('taskList', [_paragraph('task')]),
            ], header: true),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      final key = await _mount(tester, controller, readOnly: false);
      final checkbox = key.currentState!.geometry!.taskCheckboxRect(
        _position(controller, 'task'),
      )!;
      expect(checkbox.left, 10);
      final labels = <String>[];
      void collect(SemanticsNode node) {
        labels.add(node.label);
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(
        tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(labels, contains('task'));
      await tester.tapAt(
        tester.getTopLeft(find.byType(ft.TiptapEditor)) + checkbox.center,
      );
      await tester.pump();
      expect(
        _nodes(controller.state.doc)
            .firstWhere((entry) => entry.$1.type == 'taskItem')
            .$1
            .attrs['checked'],
        isTrue,
      );
      expect(controller.cellPosition, isNotNull);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('spanning task cells expose one complete checkbox semantic', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node(
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
                    attrs: {'rowspan': 2},
                    content: [
                      _list('taskList', [_paragraph('spanning task')]),
                    ],
                  ),
                ],
              ),
              _schema.node('tableRow'),
            ],
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    final key = await _mount(tester, controller, readOnly: false);
    final matches = <SemanticsNode>[];
    void collect(SemanticsNode node) {
      if (node.label == 'spanning task') matches.add(node);
      node.visitChildren((child) {
        collect(child);
        return true;
      });
    }

    collect(
      tester
          .binding
          .renderViews
          .single
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(matches, hasLength(1));
    final checkbox = key.currentState!.geometry!.taskCheckboxRect(
      _position(controller, 'spanning task'),
    )!;
    expect(matches.single.rect, checkbox);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'cell selections, search, composing underline and caret paint over chrome',
    (tester) async {
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _table([
              _schema.node(
                'blockquote',
                content: [
                  _list('bulletList', [_paragraph('search words')]),
                ],
              ),
              _schema.node(
                'codeBlock',
                attrs: {'language': 'dart'},
                content: [_schema.node('text', text: 'search code')],
              ),
            ], header: true),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final boundary = GlobalKey();
      final key = await _mount(
        tester,
        controller,
        boundary: boundary,
        readOnly: false,
      );
      final state = key.currentState!, geometry = state.geometry!;
      final start = _position(controller, 'search words') + 1;
      controller.setSelection(ft.TextSelection(start, start + 6));
      await tester.pump();
      expect(
        await _pixels(tester, boundary, _style.selectionColor),
        greaterThan(0),
      );
      controller.startSearch('search');
      await tester.pumpAndSettle();
      expect(controller.searchStatus.value.total, 2);
      expect(state.debugSearchHighlightRects.length, 2);
      for (final rect in state.debugSearchHighlightRects) {
        expect(geometry.cellRect(start)!.contains(rect.center), isTrue);
      }
      controller.clearSearch();
      controller.setSelection(ft.TextSelection(start));
      await tester.pump();
      final input = state.debugInputValue,
          at = state.debugInputValue.selection.extentOffset;
      state.debugApplyDeltas([
        TextEditingDeltaNonTextUpdate(
          oldText: input.text,
          selection: TextSelection.collapsed(offset: at + 3),
          composing: TextRange(start: at, end: at + 3),
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(controller.composing, TextRange(start: start, end: start + 3));
      expect(
        await _pixels(tester, boundary, _style.composingColor, tolerance: 100),
        greaterThan(0),
      );
      expect(
        state.debugCaret.rect!.top,
        closeTo(state.debugCaretMetrics!.rect.top, .01),
      );
      expect(
        state.debugCaret.rect!.left,
        closeTo(geometry.caretRect(start + 3).left, .01),
      );
      expect(
        await _pixels(tester, boundary, _style.caretColor),
        greaterThan(0),
      );
      final code = geometry.rowRect(_position(controller, 'search code'));
      expect(
        await _pixels(
          tester,
          boundary,
          _style.markerColor,
          region: Rect.fromLTWH(
            code.left,
            code.top,
            code.width,
            _style.codeBlockPadding.top,
          ),
        ),
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      'cell code scrolls independently with a fixed header on $platform',
      (tester) async {
        final source = List.filled(80, 'long').join(' ');
        final controller = ft.TiptapController(
          doc: _schema.node(
            'doc',
            content: [
              _table([
                _schema.node(
                  'codeBlock',
                  attrs: {'language': 'dart'},
                  content: [_schema.node('text', text: source)],
                ),
              ]),
            ],
          ),
        );
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
        var headerWidth = 0.0, highlighted = false;
        final key = await _mount(
          tester,
          controller,
          boundary: boundary,
          header: (_, view) {
            headerWidth = view.width;
            return const Text('Dart header');
          },
          highlighter: (_, text) {
            highlighted = true;
            return TextSpan(
              text: text,
              style: const TextStyle(color: Color(0xffff00ff)),
            );
          },
        );
        final geometry = key.currentState!.geometry!,
            position = _position(controller, source);
        final before = geometry.horizontalScrollMetrics(position)!;
        expect(before.maxScrollExtent, greaterThan(500));
        expect(headerWidth, 400);
        expect(find.text('Dart header'), findsOneWidget);
        final headerOrigin = tester.getTopLeft(find.text('Dart header'));
        final start = geometry.caretRect(position + 1);
        final word = geometry.wordBoundary(position + 3);
        expect(word.start, position + 1);
        expect(word.end, position + 5);
        expect(highlighted, isTrue);
        expect(
          await _pixels(
            tester,
            boundary,
            const Color(0xffff00ff),
            region: before.viewport,
          ),
          greaterThan(0),
        );
        await tester.dragFrom(before.viewport.center, const Offset(-120, 0));
        await tester.pumpAndSettle();
        final after = geometry.horizontalScrollMetrics(position)!;
        expect(after.offset, greaterThan(30));
        expect(geometry.horizontalScrollMetrics(1)!.offset, 0);
        expect(
          geometry.caretRect(position + 1).left,
          closeTo(start.left - after.offset, .01),
        );
        expect(tester.getTopLeft(find.text('Dart header')), headerOrigin);
        final hit = geometry.positionForOffset(after.viewport.center);
        expect(
          hit,
          inInclusiveRange(position + 1, position + source.length + 1),
        );
        expect(
          geometry.caretRect(hit).center.dx,
          closeTo(after.viewport.center.dx, 10),
        );
        controller.setSelection(ft.TextSelection(hit));
        await tester.pump();
        controller.exec('insertText', {'text': 'X'});
        await tester.pumpAndSettle();
        final updated = _nodes(controller.state.doc)
            .firstWhere((entry) => entry.$1.type == 'codeBlock')
            .$2;
        expect(
          geometry.horizontalScrollMetrics(updated)!.offset,
          closeTo(after.offset, .01),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets('nested media measures cell height with list and quote indents', (
    tester,
  ) async {
    var measuredHeight = 35.0;
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _table([
            _schema.node(
              'blockquote',
              content: [
                _list('bulletList', [
                  _schema.node('image', attrs: {'src': 'nested.png'}),
                ]),
              ],
            ),
          ], second: true),
          _paragraph('after table'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    final key = await _mount(
      tester,
      controller,
      estimator: (_, _) => 90,
      views: {
        'image': (_, view) => ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (_, value, child) =>
              SizedBox(width: view.width, height: measuredHeight),
        ),
      },
    );
    final geometry = key.currentState!.geometry!;
    final image = _nodes(controller.state.doc)
        .firstWhere((entry) => entry.$1.type == 'image')
        .$2;
    final rect = geometry.rowRect(image),
        before = geometry.rowRect(_position(controller, 'after table'));
    expect(rect.left, 10 + _style.quoteIndent + _style.listIndent);
    expect(rect.height, measuredHeight);
    expect(geometry.positionForOffset(rect.center), image);
    expect(
      geometry.cellRect(image)!.height,
      rect.bottom -
          geometry.cellRect(image)!.top +
          _style.tableCellPadding.bottom,
    );
    measuredHeight = 120;
    rebuild.value++;
    await tester.pumpAndSettle();
    expect(geometry.rowRect(image).height, measuredHeight);
    expect(
      geometry.rowRect(_position(controller, 'after table')).top - before.top,
      closeTo(85, .01),
    );
    expect(
      geometry.cellRect(image)!.height,
      geometry.rowRect(image).bottom -
          geometry.cellRect(image)!.top +
          _style.tableCellPadding.bottom,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows navigate nested rows within cells and leave the table', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _table([
            _list('bulletList', [_paragraph('first'), _paragraph('last')]),
          ]),
          _paragraph('outside'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = await _mount(tester, controller, readOnly: false);
    final first = _position(controller, 'first') + 2,
        last = _position(controller, 'last') + 2;
    controller.setSelection(ft.TextSelection(first));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.state.selection.head, last);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.state.selection.head, first);
    controller.setSelection(ft.TextSelection(last));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.cellPosition, isNull);
    expect(
      controller.state.doc
          .resolve(controller.state.selection.head)
          .parent
          .textContent,
      'outside',
    );
    for (final point in [const Offset(-100, -100), const Offset(2000, 2000)]) {
      expect(
        key.currentState!.geometry!.positionForOffset(point),
        inInclusiveRange(0, controller.state.doc.content.size),
      );
    }
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('Tab and Shift Tab indent lists before navigating table cells', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _table([
            _list('bulletList', [_paragraph('first'), _paragraph('second')]),
            _paragraph('plain'),
          ], second: true),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await _mount(tester, controller, readOnly: false);
    controller.setSelection(
      ft.TextSelection(_position(controller, 'second') + 1),
    );
    await tester.pump();
    final cell = controller.cellPosition;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.cellPosition, cell);
    expect(
      controller.state.doc.resolve(controller.state.selection.head).depth,
      8,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      controller.state.doc.resolve(controller.state.selection.head).depth,
      6,
    );
    controller.setSelection(
      ft.TextSelection(_position(controller, 'first') + 1),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.cellPosition, cell);
    controller.setSelection(
      ft.TextSelection(_position(controller, 'plain') + 1),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.cellPosition, isNot(cell));
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));

  for (final (input, type) in [
    ('- ', 'bulletList'),
    ('1. ', 'orderedList'),
    ('[] ', 'taskList'),
    ('> ', 'blockquote'),
    ('```dart ', 'codeBlock'),
  ]) {
    testWidgets('input rule $type renders and edits inside a cell', (
      tester,
    ) async {
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _table([_paragraph('')]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final key = await _mount(tester, controller, readOnly: false);
      controller.setSelection(const ft.TextSelection(4));
      controller.exec('insertText', {'text': input});
      await tester.pump();
      expect(
        _nodes(controller.state.doc).any((entry) => entry.$1.type == type),
        isTrue,
      );
      controller.exec('insertText', {'text': 'value'});
      await tester.pump();
      final head = controller.state.selection.head;
      expect(
        key.currentState!.geometry!.positionForOffset(
          key.currentState!.geometry!.caretRect(head).center,
        ),
        head,
      );
      controller.exec('splitBlock');
      await tester.pump();
      expect(controller.cellPosition, isNotNull);
      if (type == 'codeBlock') {
        controller.exec('splitBlock');
        controller.exec('splitBlock');
        await tester.pump();
        expect(
          controller.state.doc
              .resolve(controller.state.selection.head)
              .parent
              .type,
          'paragraph',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
