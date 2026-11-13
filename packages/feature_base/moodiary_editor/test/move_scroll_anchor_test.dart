import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:mui/mui.dart';

final _schema = ft.Schema.standard();

ft.Node _paragraph(String text) =>
    _schema.node('paragraph', content: [_schema.node('text', text: text)]);

ft.Node _image(int index) =>
    _schema.node('image', attrs: {'src': 'image-$index'});

ft.Node _table(List<ft.Node> content) => _schema.node(
  'table',
  content: [
    _schema.node(
      'tableRow',
      content: [
        _schema.node('tableCell', content: content),
        _schema.node('tableCell', content: [_paragraph('Second column')]),
      ],
    ),
    _schema.node(
      'tableRow',
      content: [
        _schema.node('tableCell', content: [_paragraph('Second row')]),
        _schema.node('tableCell', content: [_paragraph('Last cell')]),
      ],
    ),
  ],
);

ft.Node _block(String type) => switch (type) {
  'paragraph' => _paragraph('Selected paragraph with enough text to wrap.'),
  'table' => _table([_paragraph('Selected table'), _image(99)]),
  'codeBlock' => _schema.node(
    type,
    content: [
      _schema.node('text', text: 'first line\nsecond line\nthird line'),
    ],
  ),
  'bulletList' || 'orderedList' || 'taskList' => _schema.node(
    type,
    content: [
      for (final text in ['Selected list item', 'Another item'])
        _schema.node(
          type == 'taskList' ? 'taskItem' : 'listItem',
          content: [_paragraph(text)],
        ),
    ],
  ),
  _ => _schema.node(type, attrs: {'src': 'image-99'}),
};

int _position(ft.Node document, ft.Node target) {
  int? visit(ft.Node parent, int start) {
    var position = start;
    for (final child in parent.content) {
      if (identical(child, target)) return position;
      final nested = visit(child, position + 1);
      if (nested != null) return nested;
      position += child.nodeSize;
    }
    return null;
  }

  return visit(document, 0) ?? (throw StateError('Missing target'));
}

class _MediaSizes {
  final sizes = <String, ValueNotifier<double>>{};
  final timers = <Timer>[];
  var generation = 0;

  ValueNotifier<double> resolve(String source, double width) =>
      sizes.putIfAbsent(source, () {
        final value = ValueNotifier(width / 1.5);
        final index = int.parse(source.split('-').last);
        timers.add(
          Timer(const Duration(milliseconds: 35), () {
            value.value = width / [1.8, .75, 1.2][index % 3];
          }),
        );
        return value;
      });

  Widget build(BuildContext context, ft.TiptapNodeView view) {
    final source = view.node.attrs['src'] as String;
    return ValueListenableBuilder<double>(
      valueListenable: resolve(source, view.width),
      builder: (_, height, _) => SizedBox(
        key: ValueKey(source),
        height: height,
        child: const ColoredBox(color: Color(0xff90a4ae)),
      ),
    );
  }

  void resizeLater() {
    generation++;
    timers.add(
      Timer(const Duration(milliseconds: 35), () {
        for (final entry in sizes.entries) {
          final index = int.parse(entry.key.split('-').last);
          entry.value.value = [190.0, 430.0, 275.0][(index + generation) % 3];
        }
      }),
    );
  }

  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    for (final value in sizes.values) {
      value.dispose();
    }
  }
}

class _Harness {
  _Harness(this.controller, this.editor, this.media, this.target);
  final ft.TiptapController controller;
  final ft.TiptapEditorState editor;
  final _MediaSizes media;
  final ft.Node target;

  int get position => _position(controller.state.doc, target);
  Rect get rect => editor.geometry!.rowRect(position);

  Future<void> command(WidgetTester tester, String command) async {
    final top = rect.top;
    final transaction = controller.exec(command);
    expect(transaction.blockMove, isNotNull);
    media.resizeLater();
    await tester.pump();
    check(tester, top);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    check(tester, top);
  }

  void check(WidgetTester tester, double top) {
    final scroll = editor.scrollController.position;
    if ((rect.top - top).abs() > .5) {
      expect(
        scroll.pixels == scroll.minScrollExtent ||
            scroll.pixels == scroll.maxScrollExtent,
        isTrue,
        reason: 'top=$top actual=${rect.top} offset=${scroll.pixels}',
      );
    } else {
      expect(rect.top, closeTo(top, .5));
    }
    expect(rect.bottom, greaterThan(0));
    expect(rect.top, lessThan(editor.geometry!.viewportSize.height));
    final selection = controller.state.selection;
    if (target.type == 'paragraph') {
      expect(selection, isA<ft.TextSelection>());
      expect(selection.head, position + 1);
    } else {
      expect(selection, isA<ft.NodeSelection>());
      expect(selection.from, position);
    }
    if (target.type == 'image') {
      expect(
        tester
            .getTopLeft(find.byKey(ValueKey(target.attrs['src'] as String)))
            .dy,
        closeTo(rect.top, .5),
      );
    }
    expect(tester.takeException(), isNull);
  }
}

Future<_Harness> _mount(
  WidgetTester tester,
  String type, {
  String? wrapper,
  String? boundary,
  double screenTop = 300,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final target = _block(type);
  final siblings = [
    for (var index = 0; index < 7; index++) ...[
      _paragraph('Before $index with enough text to wrap on a phone screen.'),
      _image(index),
    ],
    target,
    for (var index = 7; index < 14; index++) ...[
      _image(index),
      _paragraph('After $index with enough text to wrap on a phone screen.'),
    ],
  ];
  final content = switch (wrapper) {
    'blockquote' => [_schema.node('blockquote', content: siblings)],
    'bulletList' => [
      _schema.node(
        'bulletList',
        content: [_schema.node('listItem', content: siblings)],
      ),
    ],
    'table' => [_table(siblings)],
    _ => siblings,
  };
  final documentContent = switch (boundary) {
    'start' => [
      _paragraph('First paragraph'),
      target,
      ...siblings.where((node) => !identical(node, target)),
    ],
    'end' => [
      ...siblings.where((node) => !identical(node, target)),
      target,
      _paragraph('Last paragraph'),
    ],
    _ => [
      for (var index = 0; index < 20; index++)
        _paragraph('Leading paragraph $index'),
      _block('bulletList'),
      _table([_paragraph('Leading table')]),
      ...content,
      for (var index = 0; index < 60; index++)
        _paragraph('Trailing paragraph $index'),
    ],
  };
  final controller = ft.TiptapController(
    doc: _schema.node('doc', content: documentContent),
  );
  final key = GlobalKey<ft.TiptapEditorState>();
  final media = _MediaSizes();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    media.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: ft.TiptapEditor(
        key: key,
        controller: controller,
        style: buildEditorStyle(brightness: Brightness.light),
        nodeViews: {
          for (final type in ['image', 'video', 'audio', 'attachment'])
            type: media.build,
        },
        nodeHeightEstimator: (_, width) => width / 1.5,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final harness = _Harness(controller, key.currentState!, media, target);
  controller.setSelection(
    type == 'paragraph'
        ? ft.TextSelection(harness.position + 1)
        : ft.NodeSelection(controller.state.doc, harness.position),
  );
  await tester.pumpAndSettle();
  for (var pass = 0; pass < 3; pass++) {
    harness.editor.scrollController.jumpTo(
      (harness.editor.scrollController.offset + harness.rect.top - screenTop)
          .clamp(0.0, harness.editor.scrollController.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  if (boundary == null) expect(harness.rect.top, closeTo(screenTop, .5));
  return harness;
}

void main() {
  for (final type in [
    'image',
    'paragraph',
    'table',
    'video',
    'audio',
    'attachment',
    'codeBlock',
    'bulletList',
    'orderedList',
    'taskList',
  ]) {
    testWidgets('$type stays on screen through repeated moves and history', (
      tester,
    ) async {
      final harness = await _mount(tester, type);
      for (final command in ['moveBlockUp', 'moveBlockDown']) {
        for (var count = 0; count < 5; count++) {
          await harness.command(tester, command);
        }
      }
      for (var count = 0; count < 5; count++) {
        await harness.command(tester, 'undo');
      }
      for (var count = 0; count < 5; count++) {
        await harness.command(tester, 'redo');
      }
    });
  }

  for (final wrapper in ['blockquote', 'bulletList', 'table']) {
    testWidgets('nested image in $wrapper keeps its screen position', (
      tester,
    ) async {
      final harness = await _mount(tester, 'image', wrapper: wrapper);
      for (final command in ['moveBlockUp', 'moveBlockDown', 'undo', 'redo']) {
        for (var count = 0; count < 5; count++) {
          await harness.command(tester, command);
        }
      }
    });
  }

  for (final screenTop in [-50.0, 10.0, 700.0]) {
    testWidgets('partially visible image at $screenTop keeps its position', (
      tester,
    ) async {
      final harness = await _mount(tester, 'image', screenTop: screenTop);
      await harness.command(tester, 'moveBlockUp');
      await harness.command(tester, 'moveBlockDown');
    });
  }

  testWidgets('user scrolling releases the move anchor', (tester) async {
    final harness = await _mount(tester, 'image');
    await harness.command(tester, 'moveBlockUp');
    final before = harness.rect.top;
    final scroll = harness.editor.scrollController;
    scroll.jumpTo(scroll.offset + 100);
    await tester.pumpAndSettle();
    expect(harness.rect.top, closeTo(before - 100, .5));
    final top = harness.rect.top;
    harness.media.resizeLater();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(harness.rect.top, closeTo(top, .5));
    await harness.command(tester, 'moveBlockDown');
  });

  for (final boundary in ['start', 'end']) {
    testWidgets('move clamps at the $boundary scroll extent', (tester) async {
      final harness = await _mount(
        tester,
        boundary == 'end' ? 'paragraph' : 'image',
        boundary: boundary,
      );
      final scroll = harness.editor.scrollController;
      scroll.jumpTo(
        boundary == 'start' ? 5 : scroll.position.maxScrollExtent - 5,
      );
      await tester.pumpAndSettle();
      final top = harness.rect.top;
      final transaction = harness.controller.exec(
        boundary == 'start' ? 'moveBlockUp' : 'moveBlockDown',
      );
      expect(transaction.blockMove, isNotNull);
      await tester.pumpAndSettle();
      expect(
        scroll.offset,
        boundary == 'start'
            ? scroll.position.minScrollExtent
            : scroll.position.maxScrollExtent,
      );
      expect((harness.rect.top - top).abs(), greaterThan(.5));
      harness.check(tester, top);
      final clampedTop = harness.rect.top;
      await harness.command(tester, 'undo');
      expect(harness.rect.top, closeTo(clampedTop, .5));
    });
  }

  testWidgets('typing after a move reveals the caret and has its own undo', (
    tester,
  ) async {
    final harness = await _mount(tester, 'paragraph');
    await harness.command(tester, 'moveBlockUp');
    final movedPosition = harness.position;
    harness.controller.exec('insertText', {'text': 'Typing ' * 500});
    await tester.pumpAndSettle();
    final caret = harness.editor.geometry!.caretRect(
      harness.controller.state.selection.head,
    );
    expect(caret.top, greaterThanOrEqualTo(0));
    expect(caret.bottom, lessThanOrEqualTo(844));
    final undo = harness.controller.exec('undo');
    expect(undo.blockMove, isNull);
    expect(
      harness.controller.state.doc.nodeAt(movedPosition)!.eq(harness.target),
      isTrue,
    );
    await tester.pumpAndSettle();
    final moveUndo = harness.controller.exec('undo');
    expect(moveUndo.blockMove, isNotNull);
    await tester.pumpAndSettle();
  });
}
