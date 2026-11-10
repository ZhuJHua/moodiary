import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  final schema = ft.Schema.standard();
  ft.Node paragraph(String text) =>
      schema.node('paragraph', content: [schema.node('text', text: text)]);
  ft.Node document([List<ft.Node> prefix = const []]) => schema.node(
    'doc',
    content: [
      ...prefix,
      for (var index = 0; index < 500; index++)
        paragraph('row $index searchable text'),
    ],
  );

  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    ft.TiptapEditorStyle style = const ft.TiptapEditorStyle(
      tableFixedLayout: true,
      tableMinColumnWidth: 150,
    ),
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 480,
            child: ft.TiptapEditor(
              key: key,
              controller: controller,
              readOnly: true,
              style: style,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> traverse(
    WidgetTester tester,
    GlobalKey<ft.TiptapEditorState> key,
    ft.TiptapController controller,
  ) async {
    final scroll = key.currentState!.scrollController;
    for (
      var offset = 0.0;
      offset < scroll.position.maxScrollExtent;
      offset += 360
    ) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(64));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('LRU stays bounded and evicted rows paint and hit test again', (
    tester,
  ) async {
    final controller = ft.TiptapController(doc: document());
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    final node = controller.state.doc.child(8);
    final initialLayouts = controller.diagnostics.layoutsFor(node);
    expect(initialLayouts, 1);
    await traverse(tester, key, controller);
    final scans = controller.diagnostics.fullDocumentScans;
    final scroll = key.currentState!.scrollController;
    final extent = scroll.position.maxScrollExtent;
    await tester.pump();
    expect(scroll.position.maxScrollExtent, extent);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      controller.diagnostics.layoutsFor(node),
      greaterThan(initialLayouts),
    );
    final geometry = key.currentState!.geometry!;
    final position = geometry.positionForOffset(const Offset(40, 45));
    expect(position, inInclusiveRange(1, controller.state.doc.content.size));
    expect(geometry.caretRect(position).height, greaterThan(0));
    expect(controller.diagnostics.fullDocumentScans, scans);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(controller.diagnostics.cachedLayouts, 0);
    expect(controller.diagnostics.cachedTextLength, 0);
  });

  testWidgets('steady scrolling reuses offscreen selection endpoint layouts', (
    tester,
  ) async {
    final controller = ft.TiptapController(doc: document());
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    final doc = controller.state.doc;
    final anchor = doc.rowAt(1).position + 1;
    final head = doc.rowAt(499).position + 1;
    controller.setSelection(ft.TextSelection(anchor, head));
    await tester.pumpAndSettle();
    key.currentState!.geometry!.caretRect(anchor);
    key.currentState!.geometry!.caretRect(head);
    final anchorLayouts = controller.diagnostics.layoutsFor(doc.child(1));
    final headLayouts = controller.diagnostics.layoutsFor(doc.child(499));
    final scroll = key.currentState!.scrollController;
    for (var offset = 2000.0; offset < 8000; offset += 80) {
      final before = controller.diagnostics.blockLayouts;
      scroll.jumpTo(offset);
      await tester.pump();
      if (offset > 2000) {
        expect(
          controller.diagnostics.blockLayouts - before,
          lessThanOrEqualTo(4),
        );
      }
    }
    expect(controller.diagnostics.layoutsFor(doc.child(1)), anchorLayouts);
    expect(controller.diagnostics.layoutsFor(doc.child(499)), headLayouts);
    expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing selection copy and search survive eviction', (
    tester,
  ) async {
    final controller = ft.TiptapController(doc: document());
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    await traverse(tester, key, controller);
    final doc = controller.state.doc;
    controller.setSelection(
      ft.TextSelection(doc.rowAt(8).position + 2, doc.rowAt(10).position + 4),
    );
    await tester.pumpAndSettle();
    expect(
      key.currentState!.geometry!.selectionRects(
        controller.state.selection.from,
        controller.state.selection.to,
        visibleOnly: false,
      ),
      isNotEmpty,
    );
    controller.insertPlainText('edited searchable');
    await tester.pumpAndSettle();
    expect(controller.state.doc.textContent, contains('edited searchable'));
    controller.exec('selectAll');
    String? copied;
    await controller.copy(write: (text, html) async => copied = text);
    expect(copied, contains('row 499'));
    expect(copied, contains('edited searchable'));
    controller.startSearch('searchable');
    await tester.pumpAndSettle();
    expect(controller.searchStatus.value.complete, isTrue);
    key.currentState!.scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bound horizontal metrics reuse a block outside the window', (
    tester,
  ) async {
    final code = schema.node(
      'codeBlock',
      content: [schema.node('text', text: 'wide code ' * 40)],
    );
    final controller = ft.TiptapController(
      doc: document([paragraph('anchor'), code]),
    );
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    final codePosition = controller.state.doc.child(0).nodeSize;
    final geometry = key.currentState!.geometry!;
    await tester.dragFrom(
      geometry.horizontalScrollMetrics(codePosition)!.viewport.center,
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    final layouts = controller.diagnostics.layoutsFor(code);
    final scroll = key.currentState!.scrollController;
    for (var offset = 2000.0; offset < 8000; offset += 80) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(controller.diagnostics.layoutsFor(code), layouts);
    }
    expect(
      geometry.horizontalScrollMetrics(codePosition)!.offset,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide tables and long code retain offsets after eviction', (
    tester,
  ) async {
    final table = schema.node(
      'table',
      content: [
        for (var row = 0; row < 2; row++)
          schema.node(
            'tableRow',
            content: [
              for (var column = 0; column < 5; column++)
                schema.node(
                  'tableCell',
                  content: [paragraph('cell $row $column')],
                ),
            ],
          ),
      ],
    );
    final code = schema.node(
      'codeBlock',
      content: [schema.node('text', text: '${'wide code ' * 30}\n' * 20)],
    );
    final controller = ft.TiptapController(doc: document([table, code]));
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    final geometry = key.currentState!.geometry!;
    final codePosition = table.nodeSize;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: geometry.horizontalScrollMetrics(1)!.viewport.center,
        scrollDelta: const Offset(120, 0),
      ),
    );
    await tester.pumpAndSettle();
    final tableOffset = geometry.horizontalScrollMetrics(1)!.offset;
    expect(tableOffset, greaterThan(0));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position:
            geometry.horizontalScrollMetrics(codePosition)!.viewport.topLeft +
            const Offset(60, 30),
        scrollDelta: const Offset(100, 0),
      ),
    );
    await tester.pumpAndSettle();
    final codeOffset = geometry.horizontalScrollMetrics(codePosition)!.offset;
    expect(codeOffset, greaterThan(0));
    final before = controller.diagnostics.layoutsFor(code);
    final tableBefore = controller.diagnostics.layoutsFor(table.child(0));
    expect(
      controller.diagnostics.cachedLayouts,
      greaterThan(controller.diagnostics.visibleRows),
    );
    final end = controller.state.doc.content.size - 1;
    controller.setSelection(ft.TextSelection(end, end));
    await tester.pumpAndSettle();
    await traverse(tester, key, controller);
    key.currentState!.scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(geometry.horizontalScrollMetrics(1)!.offset, tableOffset);
    expect(geometry.horizontalScrollMetrics(codePosition)!.offset, codeOffset);
    expect(controller.diagnostics.layoutsFor(code), greaterThan(before));
    expect(
      controller.diagnostics.layoutsFor(table.child(0)),
      greaterThan(tableBefore),
    );
    expect(geometry.positionForOffset(const Offset(40, 45)), greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('revised chunks transfer paragraph ownership before eviction', (
    tester,
  ) async {
    final long = schema.node(
      'paragraph',
      content: [
        schema.node('text', text: 'chunk words. ' * 800),
        schema.node('diaryLink', attrs: {'id': '42', 'label': 'Diary'}),
        schema.node('text', text: 'suffix words. ' * 600),
      ],
    );
    final controller = ft.TiptapController(doc: document([long]));
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    for (var edit = 0; edit < 4; edit++) {
      controller.setSelection(const ft.TextSelection(4500, 4500));
      controller.insertPlainText('edit');
      await tester.pumpAndSettle();
    }
    final revised = controller.state.doc.child(0);
    final end = controller.state.doc.content.size - 1;
    controller.setSelection(ft.TextSelection(end, end));
    await tester.pumpAndSettle();
    await traverse(tester, key, controller);
    final before = controller.diagnostics.layoutsFor(revised);
    key.currentState!.scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(controller.diagnostics.layoutsFor(revised), greaterThan(before));
    expect(
      key.currentState!.geometry!.positionForOffset(const Offset(40, 45)),
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('text budget evicts a huge block with fewer than 64 entries', (
    tester,
  ) async {
    final code = schema.node(
      'codeBlock',
      content: [schema.node('text', text: 'long code line\n' * 3000)],
    );
    final controller = ft.TiptapController(doc: document([code]));
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    expect(controller.diagnostics.cachedTextLength, greaterThan(32768));
    final position = controller.state.doc.rowAt(15).position + 1;
    controller.setSelection(ft.TextSelection(position, position));
    await tester.pumpAndSettle();
    key.currentState!.scrollController.jumpTo(
      key.currentState!.scrollController.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(controller.diagnostics.cachedTextLength, lessThanOrEqualTo(32768));
    expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rowspans share cell layouts through edits and eviction', (
    tester,
  ) async {
    final shared = paragraph('shared cell');
    final table = schema.node(
      'table',
      content: [
        schema.node(
          'tableRow',
          content: [
            schema.node('tableCell', attrs: {'rowspan': 2}, content: [shared]),
            schema.node('tableCell', content: [paragraph('first cell')]),
          ],
        ),
        schema.node(
          'tableRow',
          content: [
            schema.node('tableCell', content: [paragraph('second cell')]),
          ],
        ),
      ],
    );
    final controller = ft.TiptapController(doc: document([table]));
    addTearDown(controller.dispose);
    final key = await mount(tester, controller);
    controller.setSelection(const ft.TextSelection(6, 6));
    controller.insertPlainText('edit');
    await tester.pumpAndSettle();
    expect(controller.state.doc.textContent, contains('edit'));
    final unchangedCell = controller.state.doc
        .child(0)
        .child(1)
        .child(0)
        .child(0);
    final end = controller.state.doc.content.size - 1;
    controller.setSelection(ft.TextSelection(end, end));
    await tester.pumpAndSettle();
    await traverse(tester, key, controller);
    final before = controller.diagnostics.paragraphLayouts;
    key.currentState!.scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(controller.diagnostics.paragraphLayouts, greaterThan(before));
    expect(key.currentState!.geometry!.cellRect(6), isNotNull);
    expect(unchangedCell.textContent, 'second cell');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(controller.diagnostics.cachedLayouts, 0);
  });

  testWidgets('controller replacement clears layouts and old diagnostics', (
    tester,
  ) async {
    final first = ft.TiptapController(doc: document());
    final second = ft.TiptapController(doc: document());
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final key = GlobalKey<ft.TiptapEditorState>();
    Future<void> show(ft.TiptapController controller) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(first);
    expect(first.diagnostics.cachedLayouts, greaterThan(0));
    await show(second);
    expect(first.diagnostics.cachedLayouts, 0);
    expect(second.diagnostics.cachedLayouts, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    expect(second.diagnostics.cachedLayouts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post-frame document replacement retires the old working set', (
    tester,
  ) async {
    final controller = ft.TiptapController(doc: document());
    addTearDown(controller.dispose);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      controller.replaceDocument(
        schema.node('doc', content: [paragraph('replacement')]),
      );
    });
    await mount(tester, controller);
    expect(controller.state.doc.textContent, 'replacement');
    expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
  });
}
