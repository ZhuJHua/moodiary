import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';
import '../support/settle.dart';

final _schema = ft.Schema.standard();
final _paragraph = TestNodes(_schema).p;
final _image = TestNodes(_schema).image;

Future<GlobalKey<ft.TiptapEditorState>> _mount(
  WidgetTester tester,
  ft.TiptapController controller, {
  required Map<String, ft.TiptapNodeViewBuilder> views,
  bool readOnly = true,
  double Function(ft.Node, double)? estimate,
}) async {
  final key = GlobalKey<ft.TiptapEditorState>();
  await tester.pumpWidget(
    CupertinoApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 360,
          child: ft.TiptapEditor(
            key: key,
            controller: controller,
            readOnly: readOnly,
            style: const ft.TiptapEditorStyle(
              cacheExtent: 0,
              padding: EdgeInsets.zero,
              blockSpacing: 0,
            ),
            nodeViews: views,
            nodeHeightEstimator: estimate ?? (_, _) => 200,
          ),
        ),
      ),
    ),
  );
  await settleEditor(tester);
  return key;
}

void main() {
  for (final table in [false, true]) {
    testWidgets(
      'growing straddling ${table ? 'table' : 'image'} anchors paint',
      (tester) async {
        final height = ValueNotifier(200.0);
        final block = table
            ? _schema.node(
                'table',
                content: [
                  _schema.node(
                    'tableRow',
                    content: [
                      _schema.node('tableCell', content: [_image('portrait')]),
                    ],
                  ),
                ],
              )
            : _image('portrait');
        final controller = ft.TiptapController(
          doc: _schema.node(
            'doc',
            content: [
              block,
              _schema.node('attachment', attrs: {'src': 'marker'}),
              for (var index = 0; index < 60; index++)
                _paragraph('Tail $index'),
            ],
          ),
        );
        addTearDown(controller.dispose);
        addTearDown(height.dispose);
        final key = await _mount(
          tester,
          controller,
          views: {
            'image': (_, _) => ValueListenableBuilder<double>(
              valueListenable: height,
              builder: (_, value, _) => SizedBox(height: value),
            ),
            'attachment': (_, _) =>
                const SizedBox(key: ValueKey('marker'), height: 40),
          },
        );
        final scroll = key.currentState!.scrollController;
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await settleEditor(tester);
        scroll.jumpTo(100);
        await settleEditor(tester);
        final before = tester.getTopLeft(find.byKey(const ValueKey('marker')));
        final offset = scroll.offset;
        height.value = 400;
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(const ValueKey('marker'))), before);
        expect(scroll.offset, closeTo(offset + 200, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('typing in a straddling paragraph preserves scroll offset', (
    tester,
  ) async {
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _paragraph('wrapped text ' * 60),
          for (var index = 0; index < 60; index++) _paragraph('Tail $index'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    controller.setSelection(const ft.TextSelection(100));
    final key = await _mount(tester, controller, views: {}, readOnly: false);
    final scroll = key.currentState!.scrollController;
    scroll.jumpTo(40);
    await settleEditor(tester);
    final geometry = key.currentState!.geometry!;
    final before = geometry.rowRect(1).height;
    controller.exec('insertText', {'text': 'more text ' * 2});
    await tester.pump();
    expect(geometry.rowRect(1).height, greaterThan(before));
    expect(scroll.offset, 40);
  });

  testWidgets('moving measured cloned media retains height above viewport', (
    tester,
  ) async {
    var estimates = 0;
    final controller = ft.TiptapController(
      doc: _schema.node(
        'doc',
        content: [
          _image('portrait'),
          _image('landscape'),
          for (var index = 0; index < 60; index++) _paragraph('Tail $index'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final key = await _mount(
      tester,
      controller,
      readOnly: false,
      views: {
        'image': (_, view) =>
            SizedBox(height: view.node.attrs['src'] == 'portrait' ? 240 : 80),
      },
      estimate: (_, _) {
        estimates++;
        return 40;
      },
    );
    final scroll = key.currentState!.scrollController;
    scroll.jumpTo(400);
    await settleEditor(tester);
    for (final command in ['moveBlockDown', 'moveBlockUp']) {
      final position = command == 'moveBlockDown' ? 0 : 1;
      controller.setSelection(ft.NodeSelection(controller.state.doc, position));
      final before = scroll.offset;
      final geometry = key.currentState!.geometry!;
      final movedTop = geometry.rowRect(position).top;
      final calls = estimates;
      controller.exec(command);
      await tester.pump();
      expect(
        scroll.offset,
        closeTo(before + (command == 'moveBlockDown' ? 80 : -80), .01),
      );
      expect(geometry.rowRect(1 - position).top, closeTo(movedTop, .01));
      expect(estimates, calls);
      final movedOffset = scroll.offset;
      final contentTop = geometry.rowRect(2).top;
      final original = controller.state.doc.nodeAt(1 - position)!;
      final cloned = _schema.fromJson(original.toJson());
      expect(identical(original, cloned), isFalse);
      final transaction = controller.state.tr;
      transaction.replace(
        1 - position,
        2 - position,
        ft.Slice(ft.Fragment([cloned]), 0, 0),
      );
      transaction.setSelection(ft.NodeSelection(transaction.doc, 1 - position));
      controller.apply(transaction);
      await tester.pump();
      expect(scroll.offset, closeTo(movedOffset, .01));
      expect(geometry.rowRect(2).top, closeTo(contentTop, .01));
      expect(estimates, calls);
    }
    expect(tester.takeException(), isNull);
  });
}
