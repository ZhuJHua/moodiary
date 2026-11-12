import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

void main() {
  final schema = ft.Schema.standard();
  String? clipboard;
  final calls = <MethodCall>[];
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  });

  setUp(() {
    clipboard = null;
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<ft.TiptapController> openMenu(
    WidgetTester tester, {
    bool readOnly = false,
    bool selected = true,
    bool systemMenu = false,
    ft.Node? doc,
    ft.Selection? selection,
    int menuPosition = 3,
    Future<void> Function(String text, String html)? onCopyClipboard,
  }) async {
    final controller = ft.TiptapController(
      doc:
          doc ??
          schema.node(
            'doc',
            content: [
              schema.node(
                'paragraph',
                content: [schema.node('text', text: 'hello world')],
              ),
            ],
          ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(supportsShowingSystemContextMenu: systemMenu),
          child: child!,
        ),
        home: ft.TiptapEditor(
          controller: controller,
          autofocus: !readOnly,
          readOnly: readOnly,
          onCopyClipboard: onCopyClipboard,
        ),
      ),
    );
    await tester.pump();
    controller.setSelection(
      selection ??
          (selected ? const ft.TextSelection(1, 6) : const ft.TextSelection(3)),
    );
    await tester.pump();
    final geometry = tester
        .state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor))
        .geometry!;
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(ft.TiptapEditor)) +
          geometry.caretRect(menuPosition).center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    return controller;
  }

  testWidgets('selection menu cuts to clipboard and undoes in one step', (
    tester,
  ) async {
    final controller = await openMenu(tester);
    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CupertinoTextSelectionToolbar),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();
    expect(labels, ['Cut', 'Copy', 'Paste', 'Select all']);
    final before = controller.state;
    await tester.tap(find.text('Cut'));
    await tester.pumpAndSettle();
    expect(clipboard, 'hello');
    expect(controller.state.doc.textContent, ' world');
    expect(controller.state.selection, const ft.TextSelection(1));
    expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);
    controller.exec('undo');
    expect(controller.state.doc.toJson(), before.doc.toJson());
    expect(controller.state.selection, before.selection);
    expect(controller.state.history.canUndo, isFalse);
  }, variant: platforms);

  testWidgets('collapsed selection menu has no Cut or Copy', (tester) async {
    await openMenu(tester, selected: false);
    expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
  }, variant: platforms);

  for (final cells in [
    ['a', '', '01234567890123456789'],
    ['keep', 'left', 'right'],
  ]) {
    for (final action in ['Cut', 'Copy']) {
      testWidgets(
        'Android menu $action collapses a partial cell selection safely: $cells',
        (tester) async {
          final doc = schema.node(
            'doc',
            content: [
              schema.node(
                'table',
                content: [
                  schema.node(
                    'tableRow',
                    content: [
                      for (final text in cells)
                        schema.node(
                          'tableCell',
                          content: [
                            schema.node(
                              'paragraph',
                              content: [
                                if (text.isNotEmpty)
                                  schema.node('text', text: text),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ],
          );
          final map = ft.TableMap.get(doc.child(0));
          final selection = ft.CellSelection(
            doc,
            map.map[1] + 1,
            map.map[2] + 1,
          );
          final controller = await openMenu(
            tester,
            doc: doc,
            selection: selection,
            menuPosition: selection.headCell + 2,
          );
          final before = controller.state;
          expect(before.selection, isA<ft.CellSelection>());
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(clipboard, '${cells[1]}\n\n${cells[2]}');
          expect(controller.state.selection.empty, isTrue);
          expect(
            controller.state.selection.to,
            lessThanOrEqualTo(controller.state.doc.content.size),
          );
          expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);
          if (action == 'Cut') {
            final row = controller.state.doc.child(0).child(0);
            expect(row.content.map((cell) => cell.textContent), [
              cells[0],
              '',
              '',
            ]);
            expect(
              selection.to,
              greaterThan(controller.state.doc.content.size),
            );
            controller.exec('undo');
            expect(controller.state.doc.toJson(), before.doc.toJson());
            expect(controller.state.selection, before.selection);
            expect(controller.state.history.canUndo, isFalse);
          } else {
            expect(controller.state.doc.toJson(), before.doc.toJson());
            expect(controller.state.selection.to, selection.to - 1);
          }
        },
        variant: const TargetPlatformVariant({TargetPlatform.android}),
      );
    }
  }

  for (final action in ['Cut', 'Copy']) {
    for (final change in ['selection', 'document', 'selection round trip']) {
      testWidgets(
        'Android menu $action preserves $change during clipboard write',
        (tester) async {
          final write = Completer<void>();
          var writes = 0;
          final controller = await openMenu(
            tester,
            onCopyClipboard: (text, html) {
              clipboard = text;
              writes++;
              return write.future;
            },
          );
          final selection = controller.state.selection;
          await tester.tap(find.text(action));
          await tester.pump();
          expect(writes, 1);
          if (change == 'document') {
            controller.exec('toggleMark', {'type': 'bold'});
          } else {
            controller.setSelection(const ft.TextSelection(2, 5));
            if (change == 'selection round trip') {
              controller.setSelection(selection);
            }
          }
          final before = controller.state;
          final revision = controller.revision;
          write.complete();
          await tester.pumpAndSettle();
          expect(clipboard, 'hello');
          expect(tester.takeException(), isNull);
          expect(controller.state.doc.toJson(), before.doc.toJson());
          expect(controller.state.selection, before.selection);
          expect(controller.revision, revision);
          expect(find.byType(CupertinoTextSelectionToolbar), findsNothing);
        },
        variant: const TargetPlatformVariant({TargetPlatform.android}),
      );
    }
  }

  testWidgets('read-only selection menu has Copy but no Cut or Paste', (
    tester,
  ) async {
    final controller = await openMenu(tester, readOnly: true);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Paste'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(controller.state.doc.textContent, 'hello world');
  }, variant: platforms);

  testWidgets('iOS system selection menu includes Cut before Copy and Paste', (
    tester,
  ) async {
    await openMenu(tester, systemMenu: true);
    final call = calls.lastWhere(
      (call) => call.method == 'ContextMenu.showSystemContextMenu',
    );
    final arguments = call.arguments as Map;
    final items = (arguments['items'] as List).cast<Map>();
    expect(items.map((item) => item['title'] ?? item['type']), [
      'Cut',
      'Copy',
      'paste',
      'Select all',
    ]);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));
}
