// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final schema = ft.Schema.standard();
  HtmlClipboardContent? clipboard;
  const writeChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.moodiary_native.HtmlClipboardApi.write',
    HtmlClipboardApi.pigeonChannelCodec,
  );
  const platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  });

  setUp(() {
    clipboard = null;
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler(writeChannel, (
      message,
    ) async {
      clipboard = (message as List).first as HtmlClipboardContent;
      return [null];
    });
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      writeChannel,
      null,
    );
    await getIt.reset();
  });

  Future<(ft.TiptapController, MaterialLocalizations)> openMenu(
    WidgetTester tester, {
    bool selected = true,
    bool readOnly = false,
  }) async {
    final doc = schema.node(
      'doc',
      attrs: {'v': 2},
      content: [
        schema.node(
          'paragraph',
          content: [schema.node('text', text: 'hello world')],
        ),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: Brightness.light),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          builder: (context, child) =>
              MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: MoodiaryEditor(
              initialContent: jsonEncode(doc.toJson()),
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor));
    final controller = editor.controller;
    controller.setSelection(
      selected ? const ft.TextSelection(1, 6) : const ft.TextSelection(3),
    );
    await tester.pump();
    final geometry = tester
        .state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor))
        .geometry!;
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(ft.TiptapEditor)) +
          geometry.caretRect(3).center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    final labels = MaterialLocalizations.of(
      tester.element(find.byType(ft.TiptapEditor)),
    );
    return (controller, labels);
  }

  testWidgets('fallback menu cuts rich clipboard text with one-step undo', (
    tester,
  ) async {
    final (controller, labels) = await openMenu(tester);
    final actions = [
      labels.cutButtonLabel,
      labels.copyButtonLabel,
      labels.pasteButtonLabel,
      labels.selectAllButtonLabel,
    ];
    for (final action in actions) {
      expect(find.text(action), findsOneWidget);
    }
    for (var index = 1; index < actions.length; index++) {
      expect(
        tester.getCenter(find.text(actions[index - 1])).dx,
        lessThan(tester.getCenter(find.text(actions[index])).dx),
      );
    }
    final before = controller.state;
    await tester.tap(find.text(labels.cutButtonLabel));
    await tester.pumpAndSettle();
    expect(clipboard?.text, 'hello');
    expect(clipboard?.html, contains('hello'));
    expect(controller.state.doc.textContent, ' world');
    expect(controller.state.selection, const ft.TextSelection(1));
    expect(find.text(labels.cutButtonLabel), findsNothing);
    controller.exec('undo');
    expect(controller.state.doc.toJson(), before.doc.toJson());
    expect(controller.state.selection, before.selection);
    expect(controller.state.history.canUndo, isFalse);
    await tester.pumpWidget(const SizedBox());
  }, variant: platforms);

  testWidgets('fallback menu omits Cut and Copy for a caret', (tester) async {
    final (_, labels) = await openMenu(tester, selected: false);
    expect(find.text(labels.cutButtonLabel), findsNothing);
    expect(find.text(labels.copyButtonLabel), findsNothing);
    expect(find.text(labels.pasteButtonLabel), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: platforms);

  testWidgets('read-only fallback menu omits Cut and Paste', (tester) async {
    final (controller, labels) = await openMenu(tester, readOnly: true);
    expect(find.text(labels.cutButtonLabel), findsNothing);
    expect(find.text(labels.pasteButtonLabel), findsNothing);
    expect(find.text(labels.copyButtonLabel), findsOneWidget);
    expect(controller.state.doc.textContent, 'hello world');
    await tester.pumpWidget(const SizedBox());
  }, variant: platforms);
}
