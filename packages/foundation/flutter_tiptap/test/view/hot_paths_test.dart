import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

class _CountedStyle extends ft.TiptapEditorStyle {
  _CountedStyle() : super(cacheExtent: 0);
  int hashes = 0;
  @override
  bool operator ==(Object other) => identical(this, other) || super == other;
  @override
  int get hashCode {
    hashes++;
    return super.hashCode;
  }
}

void main() {
  final schema = ft.Schema.standard();
  final nodes = TestNodes(schema);

  Future<GlobalKey<ft.TiptapEditorState>> mount(
    WidgetTester tester,
    ft.TiptapController controller, {
    Map<String, ft.TiptapNodeViewBuilder> views = const {},
    ft.TiptapEditorStyle style = const ft.TiptapEditorStyle(cacheExtent: 0),
    bool autofocus = false,
    bool readOnly = true,
  }) async {
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            height: 280,
            child: ft.TiptapEditor(
              key: key,
              controller: controller,
              style: style,
              nodeViews: views,
              readOnly: readOnly,
              autofocus: autofocus,
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump();
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
    return key;
  }

  testWidgets('unchanged custom nodes keep their widget across layout passes', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: nodes.doc([
        nodes.image('photo'),
        for (var index = 0; index < 30; index++) nodes.p('row $index'),
      ]),
    );
    controller.setSelection(const ft.TextSelection(2));
    var builds = 0;
    final views = <ft.TiptapNodeView>[];
    final key = await mount(
      tester,
      controller,
      readOnly: false,
      views: {
        'image': (context, view) {
          builds++;
          views.add(view);
          return const SizedBox(height: 90);
        },
      },
    );
    expect(builds, 1);
    final original = views.single;
    key.currentState!.scrollController.jumpTo(1);
    await tester.pump();
    controller.setSelection(const ft.TextSelection(3));
    await tester.pump();
    expect(builds, 1);
    expect(identical(views.single, original), isTrue);
    controller.setSelection(ft.NodeSelection(controller.state.doc, 0));
    await tester.pump();
    expect(builds, 2);
    expect(views.last.selected, isTrue);
  });

  testWidgets(
    'visible geometry reuses layouts and offscreen queries still lay out',
    (tester) async {
      final doc = nodes.doc([
        for (var index = 0; index < 100; index++) nodes.p('row $index'),
      ]);
      final controller = ft.TiptapController(doc: doc);
      final key = await mount(tester, controller);
      final geometry = key.currentState!.geometry!;
      final queries = controller.diagnostics.layoutQueries;
      for (var count = 0; count < 20; count++) {
        geometry.caretRect(2);
        geometry.rowRect(0);
        geometry.positionForOffset(const Offset(30, 30));
      }
      expect(controller.diagnostics.layoutQueries, queries);
      geometry.rowRect(doc.rowAt(99).position);
      expect(controller.diagnostics.layoutQueries, queries + 1);
    },
  );

  testWidgets('selection rectangles visit only rows touched by the range', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: nodes.doc([
        for (var index = 0; index < 30; index++) nodes.p('search row $index'),
      ]),
    );
    final key = await mount(tester, controller);
    controller.diagnostics.selectionRows = 0;
    expect(key.currentState!.geometry!.selectionRects(1, 4), isNotEmpty);
    expect(controller.diagnostics.selectionRows, 1);
    await tester.runAsync(() async {
      controller.startSearch('search');
      await controller.searchComplete;
    });
    await tester.pump();
    final scanned = controller.searchScannedBlocks;
    controller.clearSearch();
    await tester.pump();
    expect(controller.searchScannedBlocks, 0);
    expect(scanned, greaterThan(0));
  });

  testWidgets('inline decorations and list markers are reused during repaint', (
    tester,
  ) async {
    final inline = schema.node(
      'paragraph',
      content: [
        schema.node(
          'text',
          text: 'highlight',
          marks: [schema.mark('highlight')],
        ),
        schema.node('text', text: ' code ', marks: [schema.mark('code')]),
        schema.node(
          ft.referenceNodeType,
          attrs: {'id': 'entry', 'label': 'Entry'},
        ),
      ],
    );
    final controller = ft.TiptapController(
      doc: nodes.doc([
        nodes.list([
          nodes.item([inline]),
        ]),
        nodes.p('tail'),
      ]),
    );
    final key = await mount(tester, controller);
    final position = controller.state.doc.rows().first.position;
    key.currentState!.debugListMarker(position);
    final decorations = controller.diagnostics.decorationLayouts,
        markers = controller.diagnostics.markerLayouts,
        paragraphs = controller.diagnostics.paragraphLayouts;
    expect(decorations, greaterThan(0));
    expect(markers, greaterThan(0));
    for (var count = 0; count < 20; count++) {
      key.currentState!.debugListMarker(position);
      key.currentState!.geometry!.caretRect(position + 2);
    }
    controller.clearSearch();
    await tester.pump();
    expect(controller.diagnostics.decorationLayouts, decorations);
    expect(controller.diagnostics.markerLayouts, markers);
    expect(controller.diagnostics.paragraphLayouts, paragraphs);
  });

  testWidgets('list repaint reuses next rows and the last style gutter', (
    tester,
  ) async {
    final style = _CountedStyle();
    final controller = ft.TiptapController(
      doc: nodes.doc([
        schema.node(
          'orderedList',
          content: [
            for (var index = 0; index < 60; index++)
              nodes.textItem('item $index'),
          ],
        ),
      ]),
    );
    final key = await mount(tester, controller, style: style);
    controller.clearSearch();
    await tester.pump();
    ft.Node.debugRowLookups = 0;
    final hashes = style.hashes;
    controller.clearSearch();
    await tester.pump();
    expect(ft.Node.debugRowLookups, 0);
    key.currentState!.scrollController.jumpTo(350);
    await tester.pump();
    expect(style.hashes, hashes);
  });

  testWidgets('media measurement misses compare only matching source buckets', (
    tester,
  ) async {
    final controller = ft.TiptapController();
    final key = await mount(tester, controller);
    for (var index = 0; index < 520; index++) {
      key.currentState!.debugCacheMeasurement(
        nodes.image('media-$index'),
        120,
        Size(120, index + 1.0),
      );
    }
    controller.diagnostics.measurementComparisons = 0;
    expect(
      key.currentState!.debugMeasuredSize(nodes.image('media-300'), 120),
      const Size(120, 301),
    );
    expect(controller.diagnostics.measurementComparisons, 1);
    expect(
      key.currentState!.debugMeasuredSize(nodes.image('media-0'), 120),
      isNull,
    );
    final duplicate = nodes.image('media-300');
    key.currentState!.debugCacheMeasurement(
      duplicate,
      120,
      const Size(120, 999),
    );
    expect(
      key.currentState!.debugMeasuredSize(nodes.image('media-300'), 120),
      isNull,
    );
  });

  testWidgets('table content rows materialize once for repeated geometry', (
    tester,
  ) async {
    final code = schema.node(
      'codeBlock',
      content: [schema.node('text', text: 'a very long line ' * 20)],
    );
    final doc = nodes.doc([
      nodes.table([
        schema.node(
          'tableRow',
          content: [
            nodes.cell([code, nodes.p('cell')]),
            nodes.textCell('other'),
          ],
        ),
      ]),
      nodes.p('tail'),
    ]);
    final controller = ft.TiptapController(doc: doc);
    final key = await mount(tester, controller);
    var position = 0;
    doc.descendants((node, at, _, _) {
      if (identical(node, code)) position = at;
      return true;
    });
    final geometry = key.currentState!.geometry!;
    geometry.horizontalScrollMetrics(position + 1);
    final materializations = controller.diagnostics.cellRowMaterializations;
    for (var count = 0; count < 20; count++) {
      geometry.rowRect(position);
      geometry.caretRect(position + 1);
      geometry.horizontalScrollMetrics(position + 1);
    }
    expect(materializations, greaterThan(0));
    expect(controller.diagnostics.cellRowMaterializations, materializations);
  });

  testWidgets(
    'IME style updates are sent only for changed typography or a new connection',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );
      final doc = nodes.doc([
        nodes.p('body text'),
        schema.node(
          'heading',
          attrs: {'level': 1},
          content: [schema.node('text', text: 'Heading')],
        ),
      ]);
      final controller = ft.TiptapController(doc: doc);
      final key = await mount(
        tester,
        controller,
        readOnly: false,
        autofocus: true,
      );
      int styles() =>
          calls.where((call) => call.method == 'TextInput.setStyle').length;
      final before = styles();
      expect(before, greaterThan(0));
      controller.setSelection(const ft.TextSelection(4));
      await tester.pump();
      await tester.pump();
      expect(styles(), before);
      controller.setSelection(ft.TextSelection(doc.rowAt(1).position + 2));
      await tester.pump();
      await tester.pump();
      expect(styles(), before + 1);
      key.currentState!.debugMuteCaret(true);
    },
  );

  testWidgets('caret uses vsync and follows TickerMode', (tester) async {
    final controller = ft.TiptapController(doc: nodes.doc([nodes.p('body')]));
    final key = GlobalKey<ft.TiptapEditorState>();
    Widget app(bool enabled) => CupertinoApp(
      home: TickerMode(
        enabled: enabled,
        child: ft.TiptapEditor(
          key: key,
          controller: controller,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(key.currentState!.debugCaret.timer, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(key.currentState!.debugCaret.timer, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
