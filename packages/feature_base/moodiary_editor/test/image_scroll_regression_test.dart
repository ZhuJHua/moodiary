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

ft.Node _document() => _schema.node(
  'doc',
  content: [
    for (var index = 0; index < 20; index++) ...[
      _paragraph(
        'Paragraph $index with enough text to wrap on a phone screen.',
      ),
      _image(index),
      if (index % 4 == 0)
        _schema.node(
          'bulletList',
          content: [
            _schema.node('listItem', content: [_paragraph('List $index')]),
          ],
        )
      else
        _paragraph('Following image $index'),
    ],
    _schema.node(
      'table',
      content: [
        _schema.node(
          'tableRow',
          content: [
            _schema.node('tableCell', content: [_paragraph('Table content')]),
            _schema.node('tableCell', content: [_paragraph('Second column')]),
          ],
        ),
      ],
    ),
    _paragraph('End of document'),
  ],
);

class _MediaResolver {
  final sizes = <String, ValueNotifier<Size?>>{};
  final timers = <Timer>[];

  ValueNotifier<Size?> resolve(ft.Node node) {
    final source = node.attrs['src'] as String;
    return sizes.putIfAbsent(source, () {
      final value = ValueNotifier<Size?>(null);
      final index = int.parse(source.split('-').last);
      timers.add(
        Timer(const Duration(milliseconds: 35), () {
          value.value = Size(300, [180.0, 420.0, 270.0][index % 3]);
        }),
      );
      return value;
    });
  }

  Widget build(BuildContext context, ft.TiptapNodeView view) =>
      ValueListenableBuilder<Size?>(
        valueListenable: resolve(view.node),
        builder: (_, size, _) => SizedBox(
          height: size == null
              ? view.width / 1.5
              : view.width / size.aspectRatio,
          child: const ColoredBox(color: Color(0xff90a4ae)),
        ),
      );

  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    for (final value in sizes.values) {
      value.dispose();
    }
  }
}

int _firstVisible(ft.TiptapController controller, ft.TiptapGeometry geometry) {
  for (final row in controller.state.doc.rows()) {
    final rect = geometry.rowRect(row.position);
    if (rect.top >= 0 && rect.bottom <= geometry.viewportSize.height) {
      return row.position;
    }
  }
  throw StateError('No fully visible row');
}

Future<void> _scroll(
  WidgetTester tester,
  ft.TiptapController controller,
  ft.TiptapEditorState editor,
  double delta,
) async {
  final geometry = editor.geometry!;
  final anchor = _firstVisible(controller, geometry);
  final before = geometry.rowRect(anchor).top;
  final scroll = editor.scrollController;
  final target = (scroll.offset + delta).clamp(
    0.0,
    scroll.position.maxScrollExtent,
  );
  final requested = target - scroll.offset;
  scroll.jumpTo(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pump();
  expect(
    geometry.rowRect(anchor).top,
    closeTo(before - requested, .1),
    reason: 'anchor=$anchor, delta=$requested',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final readOnly in [false, true]) {
    for (final wrapper in ['blockquote', 'bulletList', 'table']) {
      testWidgets('nested image anchor $wrapper readOnly=$readOnly', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final resolver = _MediaResolver();
        final content = [_paragraph('Before image'), _image(0)];
        final container = _schema.node(
          wrapper,
          content: switch (wrapper) {
            'bulletList' => [_schema.node('listItem', content: content)],
            'table' => [
              _schema.node(
                'tableRow',
                content: [
                  _schema.node(
                    'tableCell',
                    attrs: {'rowspan': 2},
                    content: content,
                  ),
                  _schema.node('tableCell', content: [_paragraph('Row one')]),
                ],
              ),
              _schema.node(
                'tableRow',
                content: [
                  _schema.node('tableCell', content: [_paragraph('Row two')]),
                ],
              ),
            ],
            _ => content,
          },
        );
        final controller = ft.TiptapController(
          doc: _schema.node(
            'doc',
            content: [
              container,
              for (var index = 0; index < 60; index++)
                _paragraph('Tail paragraph $index'),
            ],
          ),
        );
        final key = GlobalKey<ft.TiptapEditorState>();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          resolver.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              readOnly: readOnly,
              style: buildEditorStyle(brightness: Brightness.light),
              nodeViews: {'image': resolver.build},
              nodeHeightEstimator: (_, width) => width / 1.5,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = key.currentState!;
        final geometry = editor.geometry!;
        final imagePosition = wrapper == 'table'
            ? 3 + content.first.nodeSize
            : (wrapper == 'bulletList' ? 2 : 1) + content.first.nodeSize;
        final imageTop = geometry.rowRect(imagePosition).top;
        editor.scrollController.jumpTo(imageTop + 60);
        await tester.pumpAndSettle();
        final anchor = _firstVisible(controller, geometry);
        final anchorTop = geometry.rowRect(anchor).top;
        resolver.sizes['image-0']!.value = const Size(300, 420);
        await tester.pumpAndSettle();
        expect(geometry.rowRect(anchor).top, closeTo(anchorTop, .1));
        final measured = geometry.rowRect(imagePosition).height;
        while (editor.scrollController.offset <
            editor.scrollController.position.maxScrollExtent) {
          await _scroll(tester, controller, editor, 350);
        }
        final visible = _firstVisible(controller, geometry);
        final visibleTop = geometry.rowRect(visible).top;
        final transaction = controller.state.tr.replace(
          0,
          container.nodeSize,
          ft.Slice(
            ft.Fragment([
              _schema.fromJson(container.toJson()),
              _paragraph('Inserted'),
            ]),
            0,
            0,
          ),
        );
        final mapped = transaction.mapping.map(visible);
        transaction.setSelection(ft.NodeSelection(transaction.doc, mapped));
        controller.apply(transaction);
        await tester.pumpAndSettle();
        expect(geometry.rowRect(mapped).top, closeTo(visibleTop, .1));
        expect(geometry.rowRect(imagePosition).height, closeTo(measured, .1));
        while (editor.scrollController.offset > 0) {
          await _scroll(tester, controller, editor, -290);
        }
      });
    }
    for (final recreate in [false, true]) {
      testWidgets('phone image scrolling readOnly=$readOnly recreate=$recreate', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final resolver = _MediaResolver();
        final controller = ft.TiptapController(doc: _document());
        final key = GlobalKey<ft.TiptapEditorState>();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          resolver.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: ft.TiptapEditor(
              key: key,
              controller: controller,
              readOnly: readOnly,
              style: buildEditorStyle(brightness: Brightness.light),
              nodeViews: {'image': resolver.build},
              nodeHeightEstimator: (_, width) => width / 1.5,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = key.currentState!;
        final scroll = editor.scrollController;
        while (scroll.offset < scroll.position.maxScrollExtent) {
          await _scroll(tester, controller, editor, 380);
        }
        for (var step = 0; step < 12; step++) {
          await _scroll(tester, controller, editor, -290);
        }
        if (recreate) {
          final original = controller.state.doc.child(1);
          final position = controller.state.doc.content.positionAt(1);
          final rect = editor.geometry!.rowRect(position);
          final height = rect.height;
          expect(resolver.sizes['image-0']!.value, const Size(300, 180));
          final replacement = _schema.fromJson(original.toJson());
          expect(replacement, isNot(same(original)));
          expect(replacement.eq(original), isTrue);
          final transaction = controller.state.tr.replace(
            position,
            position + original.nodeSize,
            ft.Slice(ft.Fragment([replacement, _paragraph('Inserted')]), 0, 0),
          );
          transaction.setSelection(ft.NodeSelection(transaction.doc, position));
          controller.apply(transaction);
          await tester.pumpAndSettle();
          expect(
            editor.geometry!.rowRect(position).height,
            closeTo(height, .1),
            reason: 'An equal offscreen image retains its measured size',
          );
        }
        for (final withinViewport in [false, true]) {
          final doc = controller.state.doc;
          final candidates = doc.rows().where((row) {
            if (row.node.type != 'image') return false;
            final rect = editor.geometry!.rowRect(row.position);
            return withinViewport
                ? rect.top >= 0 && rect.top < 600
                : rect.bottom < 0;
          }).toList();
          expect(
            candidates,
            isNotEmpty,
            reason:
                'within=$withinViewport offset=${scroll.offset} '
                'images=${doc.rows().where((row) => row.node.type == 'image').length}',
          );
          final position = candidates.first.position;
          controller.apply(
            controller.state.tr.setSelection(ft.NodeSelection(doc, position)),
          );
          for (final command in ['moveBlockUp', 'moveBlockDown']) {
            final anchor = _firstVisible(controller, editor.geometry!);
            final before = editor.geometry!.rowRect(anchor).top;
            final transaction = controller.exec(command);
            await tester.pumpAndSettle();
            if (!withinViewport) {
              expect(
                editor.geometry!.rowRect(transaction.mapping.map(anchor)).top,
                closeTo(before, .1),
              );
            }
            await _scroll(tester, controller, editor, -120);
            await _scroll(tester, controller, editor, 120);
          }
        }
        while (scroll.offset > 0) {
          await _scroll(tester, controller, editor, -290);
        }
        expect(resolver.sizes.length, 20);
        expect(controller.diagnostics.cachedLayouts, lessThanOrEqualTo(64));
      });
    }
  }
}
