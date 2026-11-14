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
    WidgetTester tester,
  ) async {
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
            body: MoodiaryEditor(initialContent: jsonEncode(doc.toJson())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor));
    final controller = editor.controller;
    controller.setSelection(const ft.TextSelection(1, 6));
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

  testWidgets('Cut writes rich clipboard text through HtmlClipboardApi', (
    tester,
  ) async {
    final (_, labels) = await openMenu(tester);
    await tester.tap(find.text(labels.cutButtonLabel));
    await tester.pumpAndSettle();
    expect(clipboard?.text, 'hello');
    expect(clipboard?.html, contains('hello'));
    await tester.pumpWidget(const SizedBox());
  }, variant: platforms);
}
