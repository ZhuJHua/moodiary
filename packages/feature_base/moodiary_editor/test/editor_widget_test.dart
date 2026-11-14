// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_editor/src/toolbar/divider_picker.dart';
import 'package:moodiary_editor/src/toolbar/editor_toolbar_host.dart';
import 'package:moodiary_editor/src/toolbar/find_bar.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

import 'support/nodes.dart';
import 'support/settle.dart';

final _schema = ft.Schema.standard();
final _p = TestNodes(_schema).p;
String _json(List<ft.Node> nodes) =>
    jsonEncode(_schema.node('doc', attrs: {'v': 2}, content: nodes).toJson());
Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    TranslationProvider(
      child: MaterialApp(
        theme: buildMuiTheme(brightness: brightness),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        builder: (context, child) =>
            MaterialUiCompatibilityBridge(child: child!),
        home: Scaffold(body: child),
      ),
    );
ft.TiptapEditor _editor(WidgetTester tester) =>
    tester.widget(find.byType(ft.TiptapEditor));
ft.TiptapGeometry _geometry(WidgetTester tester) =>
    tester.state<ft.TiptapEditorState>(find.byType(ft.TiptapEditor)).geometry!;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  const htmlReadChannel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.moodiary_native.HtmlClipboardApi.read',
    HtmlClipboardApi.pigeonChannelCodec,
  );
  setUp(
    () => binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      htmlReadChannel,
      (_) async => [null],
    ),
  );
  tearDown(
    () => binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      htmlReadChannel,
      null,
    ),
  );

  setUp(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    ),
  );
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  setUp(() => getIt.registerSingleton<IKVStorage>(MemoryKVStorage()));
  tearDown(getIt.reset);

  const interactionPlatforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  });

  testWidgets(
    'Find shortcut focuses query, preserves diary, Escape restores source body or title',
    (tester) async {
      final c = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              ValueListenableBuilder(
                valueListenable: c.searchOpen,
                builder: (_, open, _) => open
                    ? EditorFindBar(controller: c, editable: true)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: MoodiaryEditor(
                  controller: c,
                  initialTitle: 'Title',
                  initialContent: _json([_p('Body text')]),
                ),
              ),
            ],
          ),
        ),
      );
      await settleEditor(tester);
      final editor = _editor(tester).controller;
      final mod =
          {
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform)
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      for (final title in [false, true]) {
        if (title) {
          await c.focusTitle();
        } else {
          await c.focus();
          editor.setSelection(const ft.TextSelection(2, 5));
        }
        await tester.pump();
        final before = editor.json;
        await tester.sendKeyDownEvent(mod);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(mod);
        await tester.pump();
        await tester.pump();
        expect(c.searchOpen.value, true);
        final query = find
            .descendant(
              of: find.byType(EditorFindBar),
              matching: find.byType(EditableText),
            )
            .first;
        expect(
          tester.widget<EditableText>(query).focusNode.hasPrimaryFocus,
          true,
        );
        await tester.enterText(query, 'Body');
        await tester.pump(const Duration(milliseconds: 250));
        expect(editor.json, before);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleEditor(tester);
        expect(c.searchOpen.value, false);
        expect(
          c.focusTarget.value,
          title ? EditorFocusTarget.title : EditorFocusTarget.editor,
        );
        if (!title) {
          expect(editor.state.selection, const ft.TextSelection(2, 5));
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
    variant: interactionPlatforms,
  );

  testWidgets(
    'title stays primary on keyboard re-show; visual arrows, Enter and Tab bridge surfaces',
    (tester) async {
      final c = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: c,
            initialTitle: 'Title',
            initialContent: _json([_p('Body text')]),
          ),
        ),
      );
      await settleEditor(tester);
      await c.focusTitle();
      await tester.pump();
      await c.imeTarget.suppressKeyboard(false);
      await tester.pump();
      await tester.pump();
      expect(c.focusTarget.value, EditorFocusTarget.title);
      expect(_editor(tester).focusNode!.hasPrimaryFocus, false);
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.tab,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(c.focusTarget.value, EditorFocusTarget.editor);
        expect(_editor(tester).controller.state.selection.head, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await settleEditor(tester);
        expect(c.focusTarget.value, EditorFocusTarget.title);
        final title = tester.widget<TextField>(
          find.byKey(const ValueKey('editor-title')),
        );
        expect(
          title.controller!.selection.extentOffset,
          title.controller!.text.length,
        );
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(c.focusTarget.value, EditorFocusTarget.editor);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleEditor(tester);
      expect(c.focusTarget.value, EditorFocusTarget.title);
      final body = _editor(tester).controller.json;
      final field = find.descendant(
        of: find.byKey(const ValueKey('editor-title')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, 'One\nTwo\r\nThree');
      expect(
        tester.widget<EditableText>(field).controller.text,
        'One Two Three',
      );
      expect(_editor(tester).controller.json, body);
      await tester.pumpWidget(const SizedBox());
    },
    variant: interactionPlatforms,
  );

  testWidgets(
    'Cmd/Ctrl K opens link editor and Escape returns body selection',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final c = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: c,
            initialContent: _json([_p('Body text')]),
          ),
        ),
      );
      await settleEditor(tester);
      await c.focus();
      final editor = _editor(tester).controller;
      editor.setSelection(const ft.TextSelection(1, 5));
      await tester.pump();
      final mod =
          {
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform)
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(mod);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(mod);
      await settleEditor(tester);
      expect(find.byType(MSheetScaffold<void>), findsOneWidget);
      expect(c.focusTarget.value, EditorFocusTarget.none);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleEditor(tester);
      expect(find.byType(MSheetScaffold<void>), findsNothing);
      expect(c.focusTarget.value, EditorFocusTarget.editor);
      expect(editor.state.selection, const ft.TextSelection(1, 5));
      await tester.pumpWidget(const SizedBox());
    },
    variant: interactionPlatforms,
  );

  testWidgets('toolbar follows content errors across document swaps', (
    tester,
  ) async {
    final controller = MoodiaryEditorController();
    await tester.pumpWidget(
      _app(
        EditorToolbarHost(
          controller: controller,
          editable: true,
          onInsertMedia: (_) async {},
          statusBar: const Text('editor status'),
          child: MoodiaryEditor(
            controller: controller,
            initialContent: '{broken',
          ),
        ),
      ),
    );
    await settleEditor(tester);
    expect(controller.state.value.contentError, isTrue);
    expect(_editor(tester).readOnly, isTrue);
    expect(find.text('editor status'), findsNothing);

    await controller.swapDocument(content: _json([_p('valid')]), title: '');
    await settleEditor(tester);
    expect(controller.state.value.contentError, isFalse);
    expect(_editor(tester).readOnly, isFalse);
    expect(find.text('editor status'), findsOneWidget);

    await controller.swapDocument(content: '{broken', title: '');
    await settleEditor(tester);
    expect(controller.state.value.contentError, isTrue);
    expect(_editor(tester).readOnly, isTrue);
    expect(find.text('editor status'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'divider caret exposes style picker without selecting the divider; Escape dismisses it',
    (tester) async {
      final c = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          EditorToolbarHost(
            controller: c,
            editable: true,
            onInsertMedia: (_) async {},
            child: MoodiaryEditor(
              controller: c,
              initialContent: _json([
                _p('before'),
                _schema.node('horizontalRule'),
                _p(''),
              ]),
            ),
          ),
        ),
      );
      await settleEditor(tester);
      await c.focus();
      final editor = _editor(tester).controller;
      final at = editor.state.doc.child(0).nodeSize;
      editor.setSelection(ft.TextSelection(at + 2));
      await settleEditor(tester);
      expect(c.state.value.selection, EditorSelectionKind.caret);
      expect(c.state.value.nodeType, EditorNodeType.horizontalRule);
      await tester.tap(find.text(l10n.editor.toolbar.style));
      await tester.pump();
      expect(find.byType(DividerPicker), findsOneWidget);
      await c.exec(EditorCommand.setHorizontalRule, {'variant': 'dotted'});
      await tester.pump();
      expect(editor.state.doc.nodeAt(at)!.attrs['variant'], 'dotted');
      expect(editor.state.selection, ft.TextSelection(at + 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(DividerPicker), findsNothing);
      expect(c.focusTarget.value, EditorFocusTarget.editor);
      expect(editor.state.selection, ft.TextSelection(at + 2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('style parameters preserve document tokens', () {
    final style = buildEditorStyle(
      colors: const ColorScheme.light(primary: Color(0xff123456)),
      brightness: Brightness.light,
      fontFamily: 'Custom',
      fontScale: 1.2,
      firstLineIndent: true,
    );
    expect(style.paragraph.fontSize, closeTo(17 * 1.2, .001));
    expect(style.paragraph.fontFamily, 'Custom');
    expect(style.paragraph.height, 1.65);
    expect(style.blockSpacing, closeTo(style.paragraph.fontSize! * .75, .001));
    expect(style.firstLineIndent, style.paragraph.fontSize! * 2);
    expect(style.headings.first.fontSize, style.paragraph.fontSize! * 1.5);
    expect(
      style.selectionColor,
      const Color(0xff123456).withValues(alpha: .28),
    );
    final dark = buildEditorStyle(brightness: Brightness.dark);
    expect(dark.marks['highlight']!.backgroundColor, const Color(0xff5c4b14));
    expect(dark.marks['highlight']!.color, const Color(0xfff6ebc8));
  });

  testWidgets(
    'HTML Pigeon writes both formats, pastes rich content and rejects stale reads',
    (tester) async {
      final messenger = binding.defaultBinaryMessenger;
      BasicMessageChannel<Object?> channel(String method) =>
          BasicMessageChannel<Object?>(
            'dev.flutter.pigeon.moodiary_native.HtmlClipboardApi.$method',
            HtmlClipboardApi.pigeonChannelCodec,
          );
      const imageRead = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.moodiary_native.ImageTransferApi.readClipboardImage',
        ImageTransferApi.pigeonChannelCodec,
      );
      messenger.setMockDecodedMessageHandler(imageRead, (_) async => [null]);
      addTearDown(
        () => messenger.setMockDecodedMessageHandler(imageRead, null),
      );
      HtmlClipboardContent? copied;
      final content = HtmlClipboardContent(
        text: 'external\ntext',
        html: '<h2>external</h2><p>text</p>',
      );
      Completer<HtmlClipboardContent>? pending;
      messenger.setMockDecodedMessageHandler(channel('write'), (message) async {
        copied = (message as List).first as HtmlClipboardContent;
        return [null];
      });
      messenger.setMockDecodedMessageHandler(
        channel('read'),
        (_) async => [pending == null ? content : await pending.future],
      );
      addTearDown(() {
        for (final method in ['read', 'write']) {
          messenger.setMockDecodedMessageHandler(channel(method), null);
        }
      });
      final controller = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialContent: _json([_p('Hello')]),
          ),
        ),
      );
      await settleEditor(tester);
      final editor = _editor(tester);
      editor.controller.setSelection(const ft.TextSelection(1, 6));
      await editor.controller.copy(write: editor.onCopyClipboard);
      expect(copied!.text, 'Hello');
      expect(copied!.html, contains('Hello'));
      expect(await editor.onPasteClipboard!(), true);
      await tester.pump();
      expect(editor.controller.state.doc.content.first.type, 'heading');
      expect(editor.controller.state.doc.textContent, contains('external'));
      content.html = null;
      content.text = 'promised plain text';
      editor.controller.exec('selectAll');
      expect(await editor.onPasteClipboard!(), true);
      await tester.pump();
      expect(editor.controller.state.doc.textContent, 'promised plain text');
      content.html = '<p># Title</p><p>body</p>';
      content.text = '# Title\n\nbody';
      editor.controller.exec('selectAll');
      expect(await editor.onPasteClipboard!(), true);
      await tester.pump();
      expect(editor.controller.state.doc.content.first.type, 'heading');
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      editor.controller.setSelection(const ft.TextSelection(1));
      await settleEditor(tester);
      expect(find.byIcon(LucideIcons.x), findsNothing);
      pending = Completer<HtmlClipboardContent>();
      final paste = editor.onPasteClipboard!();
      await controller.swapDocument(
        content: _json([_p('new diary')]),
        title: 'New',
      );
      pending.complete(content);
      await paste;
      await tester.pump();
      expect(editor.controller.state.doc.textContent, 'new diary');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('iOS system paste is taken over only while the body has focus', (
    tester,
  ) async {
    final messenger = binding.defaultBinaryMessenger;
    const setEnabled = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.SystemPasteApi.setEnabled',
      StandardMessageCodec(),
    );
    final enabled = <bool>[];
    messenger.setMockDecodedMessageHandler(setEnabled, (message) async {
      enabled.add((message as List).first as bool);
      return [null];
    });
    addTearDown(() => messenger.setMockDecodedMessageHandler(setEnabled, null));
    final controller = MoodiaryEditorController();
    await tester.pumpWidget(
      _app(
        MoodiaryEditor(
          controller: controller,
          initialContent: _json([_p('Hello')]),
        ),
      ),
    );
    await settleEditor(tester);
    expect(enabled, isEmpty);
    await controller.focus();
    await tester.pump();
    expect(enabled, [true]);
    await controller.focusTitle();
    await tester.pump();
    expect(enabled, [true, false]);
    await tester.pumpWidget(const SizedBox());
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('show keyboard reopens an attached input connection', (
    tester,
  ) async {
    final controller = MoodiaryEditorController();
    await tester.pumpWidget(
      _app(
        MoodiaryEditor(
          controller: controller,
          initialContent: _json([_p('Body')]),
        ),
      ),
    );
    await settleEditor(tester);
    await controller.focus();
    await tester.pump();
    final before = tester.testTextInput.log
        .where((call) => call.method == 'TextInput.show')
        .length;
    expect(tester.testTextInput.setClientArgs!['viewId'], tester.view.viewId);
    await controller.imeTarget.suppressKeyboard(false);
    await tester.pump();
    expect(
      tester.testTextInput.log
          .where((call) => call.method == 'TextInput.show')
          .length,
      greaterThan(before),
    );
    await controller.blur();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'autosave between Pinyin keystrokes preserves the IME marked range',
    (tester) async {
      final controller = MoodiaryEditorController(), saved = <String>[];
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialContent: _json([_p('')]),
            onChanged: saved.add,
          ),
        ),
      );
      await settleEditor(tester);
      await controller.focus();
      await tester.pump();
      final engine = _editor(tester).controller;
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '​n',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(engine.composing, const TextRange(start: 1, end: 2));
      expect(saved, hasLength(1));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '​ni',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 1, end: 3),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(engine.composing, const TextRange(start: 1, end: 3));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '​你',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(engine.state.doc.textContent, '你');
      expect(saved.last, contains('你'));
      expect(saved.last, isNot(contains('ni')));
      await controller.flush();
    },
  );

  testWidgets(
    'default line height contains nested task checkboxes without drifting later blocks',
    (tester) async {
      final task = _schema.node(
        'taskList',
        content: [
          _schema.node(
            'taskItem',
            content: [
              _p('outer'),
              _schema.node(
                'taskList',
                content: [
                  _schema.node(
                    'taskItem',
                    attrs: {'checked': true},
                    content: [_p('inner')],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        _app(MoodiaryEditor(initialContent: _json([task]))),
      );
      await settleEditor(tester);
      final geometry = _geometry(tester);
      expect(geometry.rowRect(2).height, closeTo(17 * 1.65, .001));
      expect(geometry.rowRect(11).height, closeTo(17 * 1.65, .001));
      expect(geometry.taskCheckboxRect(2)!.left, closeTo(16, .001));
      expect(
        geometry.taskCheckboxRect(11)!.left,
        closeTo(16 + 17 * 1.2 + 10 + 17 * .2, .001),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('attachment title, metadata and extension fit table cells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ft.Node attachment(String name, String src) => _schema.node(
      'attachment',
      attrs: {'src': src, 'name': name, 'size': 25},
    );
    final doc = _json([
      attachment('Top title.txt', 'top.txt'),
      _schema.node(
        'table',
        content: [
          _schema.node(
            'tableRow',
            content: [
              _schema.node(
                'tableCell',
                content: [_p(''), attachment('file-m5.txt', 'cell.txt')],
              ),
              _schema.node('tableCell', content: [_p('Other')]),
            ],
          ),
        ],
      ),
    ]);
    for (final scale in [1.0, 1.3]) {
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(readOnly: true, fontScale: scale, initialContent: doc),
        ),
      );
      await settleEditor(tester);
      final top = tester.widget<Text>(find.text('Top title.txt'));
      final cell = tester.widget<Text>(find.text('file-m5.txt'));
      for (final text in [top, cell]) {
        expect(text.style!.fontSize, 15 * scale);
        expect(text.style!.height, 1.35);
        expect(text.style!.fontWeight, FontWeight.w500);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
      for (final f in find.text('25 B').evaluate()) {
        final text = f.widget as Text;
        expect(text.style!.fontSize, 12 * scale);
        expect(text.style!.height, 1.3);
      }
      for (final f in find.text('TXT').evaluate()) {
        final text = f.widget as Text;
        expect(text.style!.fontSize, 11 * scale);
        expect(text.style!.letterSpacing, closeTo(.22 * scale, .00001));
      }
      final topParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Top title.txt'),
          matching: find.byType(RichText),
        ),
      );
      final cellParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('file-m5.txt'),
          matching: find.byType(RichText),
        ),
      );
      expect(topParagraph.didExceedMaxLines, false);
      expect(cellParagraph.didExceedMaxLines, true);
      expect(topParagraph.size.height, closeTo(15 * scale * 1.35, .01));
      expect(cellParagraph.size.height, closeTo(topParagraph.size.height, .01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('video, audio and attachment cards fit narrow table cells', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final doc = _schema.node(
      'table',
      content: [
        _schema.node(
          'tableRow',
          content: [
            for (final type in ['video', 'audio', 'attachment'])
              _schema.node(
                'tableCell',
                content: [
                  _p(''),
                  _schema.node(
                    type,
                    attrs: {
                      'src': '$type-test.mp4',
                      'name': 'Long media display name',
                      'size': 1024,
                    },
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(MoodiaryEditor(initialContent: _json([doc, _p('')]))),
    );
    await settleEditor(tester);
    expect(find.byTooltip(l10n.ui.play), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pigeon clipboard images are saved on paste', (tester) async {
    final messenger = binding.defaultBinaryMessenger;
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.ImageTransferApi.readClipboardImage',
      ImageTransferApi.pigeonChannelCodec,
    );
    final image = TransferredImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      mime: 'image/jpeg',
      name: 'photo.jpg',
    );
    messenger.setMockDecodedMessageHandler(channel, (_) async => [image]);
    addTearDown(() => messenger.setMockDecodedMessageHandler(channel, null));
    final controller = MoodiaryEditorController(), saved = <String>[];
    await tester.pumpWidget(
      _app(
        MoodiaryEditor(
          controller: controller,
          initialContent: _json([_p('First')]),
          onSaveImage: (data, name) async {
            saved.add('$name:$data');
            return 'image-${saved.length}.jpg';
          },
        ),
      ),
    );
    await settleEditor(tester);
    expect(await _editor(tester).onPasteClipboard!(), true);
    await settleEditor(tester);
    expect(saved, ['photo.jpg:data:image/jpeg;base64,AQID']);
    expect(
      _editor(tester).controller.state.doc.content.map((n) => n.type),
      contains('image'),
    );
    await controller.flush();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'metadata popovers stay anchored, update places live and dispatch every inline action',
    (tester) async {
      final controller = MoodiaryEditorController(), calls = <String>[];
      final meta = ValueNotifier<Map<String, dynamic>>({
        'dateText': 'Today',
        'subText': '12:34',
        'tags': ['test'],
        'mood': 'happy',
        'moods': [
          {'value': 'happy', 'label': 'Happy', 'color': '#ffaa00'},
          {'value': 'sad', 'label': 'Sad', 'color': '#112233'},
        ],
        'weatherOptions': [
          {'code': '100', 'label': 'Sunny'},
          {'code': '101', 'label': 'Cloudy'},
        ],
        'weather': {'icon': '100', 'text': 'Clear'},
        'weatherAutoLabel': 'Fetch weather',
        'weatherClearLabel': 'Clear weather',
        'position': 'Home',
        'positionId': 'home',
        'places': [],
        'positionAutoLabel': 'Locate',
        'positionNewPlaceLabel': 'New place',
        'positionManageLabel': 'Manage',
        'positionClearLabel': 'Clear place',
        'deleteLabel': 'Remove tag',
      });
      addTearDown(meta.dispose);
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: meta,
            builder: (context, value, _) => MoodiaryEditor(
              controller: controller,
              initialContent: _json([_p('Body')]),
              metaJson: jsonEncode(value),
              onChangeMood: (v) => calls.add('mood:$v'),
              onChangeWeather: (v) => calls.add('weather:$v'),
              onFetchWeather: () => calls.add('weather:auto'),
              onClearWeather: () => calls.add('weather:clear'),
              onLocateForPlaces: () => calls.add('locate'),
              onPickPlace: (id) => calls.add('place:$id'),
              onFetchPosition: () => calls.add('place:auto'),
              onNewPlace: () => calls.add('place:new'),
              onManagePlaces: () => calls.add('place:manage'),
              onClearPosition: () => calls.add('place:clear'),
              onRemoveTag: (index) => calls.add('tag:$index'),
            ),
          ),
        ),
      );
      await settleEditor(tester);
      await tester.tap(find.text('Happy'));
      await settleEditor(tester);
      final mood = find.byKey(const ValueKey('meta-mood'));
      expect(mood, findsOneWidget);
      expect(tester.getSize(mood).width, 300);
      expect(tester.getTopLeft(mood).dy, lessThan(200));
      await tester.tap(find.text('Sad'));
      await settleEditor(tester);
      expect(calls, ['mood:sad']);
      await tester.tap(find.text('Clear'));
      await settleEditor(tester);
      await tester.tap(find.text('Cloudy'));
      await settleEditor(tester);
      expect(calls.last, 'weather:101');
      for (final label in ['Fetch weather', 'Clear weather']) {
        await tester.tap(find.text('Clear'));
        await settleEditor(tester);
        await tester.tap(find.text(label));
        await settleEditor(tester);
      }
      expect(calls, containsAll(['weather:auto', 'weather:clear']));
      await tester.tap(find.text('Home'));
      await settleEditor(tester);
      expect(calls.last, 'locate');
      meta.value = {
        ...meta.value,
        'places': [
          {
            'id': 'cafe',
            'name': 'Nearby cafe',
            'icon': 'coffee',
            'distance': '20m',
          },
        ],
      };
      await settleEditor(tester);
      expect(find.text('20m'), findsOneWidget);
      await tester.tap(find.text('Nearby cafe'));
      await settleEditor(tester);
      expect(calls.last, 'place:cafe');
      for (final (label, expected) in [
        ('Locate', 'auto'),
        ('New place', 'new'),
        ('Manage', 'manage'),
        ('Clear place', 'clear'),
      ]) {
        await tester.tap(find.text('Home'));
        await settleEditor(tester);
        await tester.tap(find.text(label));
        await settleEditor(tester);
        expect(calls.last, 'place:$expected');
      }
      await tester.tap(find.text('#test'));
      await settleEditor(tester);
      await tester.tap(find.text('Remove tag'));
      await settleEditor(tester);
      expect(calls.last, 'tag:0');
      expect(find.byKey(const ValueKey('meta-tag')), findsNothing);
    },
  );

  testWidgets(
    'title commits through TextInput channel, body API, panel and engine remain stable',
    (tester) async {
      final controller = MoodiaryEditorController(),
          titles = <String>[],
          saved = <String>[];
      Widget content() => _app(
        MoodiaryEditor(
          key: const ValueKey('editor'),
          controller: controller,
          initialContent: _json([_p('Body')]),
          onTitleChanged: titles.add,
          onChanged: saved.add,
        ),
      );
      await tester.pumpWidget(content());
      await settleEditor(tester);
      await tester.tap(find.byKey(const ValueKey('editor-title')));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Title',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();
      expect(titles, isEmpty);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Title',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(titles, ['Title']);
      final bodyBefore = _editor(tester).controller.json;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_editor(tester).controller.json, bodyBefore);
      expect(_editor(tester).controller.state.storedMarks, isNull);
      expect(controller.focusTarget.value, EditorFocusTarget.title);
      await controller.focus();
      await tester.pump();
      final ftController = _editor(tester).controller;
      ftController.setSelection(const ft.TextSelection(1, 5));
      await controller.holdSelection();
      await controller.imeTarget.suppressKeyboard(true);
      await tester.pump();
      expect(_editor(tester).keyboardEnabled, false);
      expect(_editor(tester).focusNode!.hasFocus, true);
      await controller.exec(EditorCommand.toggleBold);
      await controller.flush();
      expect(saved, hasLength(1));
      expect(controller.state.value.has(EditorMark.bold), true);
      await controller.imeTarget.suppressKeyboard(false);
      await tester.pumpWidget(content());
      await tester.pump();
      expect(_editor(tester).controller, same(ftController));
      expect(_editor(tester).keyboardEnabled, true);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'suspension holds the selection range and restores body focus after a sheet',
    (tester) async {
      final controller = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialContent: _json([_p('Body')]),
          ),
        ),
      );
      await settleEditor(tester);
      await controller.focus();
      await tester.pump();
      final editor = _editor(tester).controller;
      editor.setSelection(const ft.TextSelection(1, 5));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final suspension = controller.suspendInput();
      await suspension.ready;
      await tester.pump();
      expect(controller.focusTarget.value, EditorFocusTarget.none);
      editor.setSelection(const ft.TextSelection(1));
      await suspension.resume();
      await tester.pump();
      expect(controller.focusTarget.value, EditorFocusTarget.editor);
      expect(editor.state.selection, const ft.TextSelection(1, 5));
      await controller.exec(EditorCommand.toggleItalic);
      await controller.flush();
      expect(editor.state.doc.child(0).child(0).marks.single.type, 'italic');
    },
  );

  testWidgets(
    'rich image content from the input channel is saved before insertion',
    (tester) async {
      final controller = MoodiaryEditorController(), received = <String>[];
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialContent: _json([_p('')]),
            onSaveImage: (data, name) async {
              received.add('$name:$data');
              return 'image-saved.png';
            },
          ),
        ),
      );
      await settleEditor(tester);
      await controller.focus();
      await tester.pump();
      final call = tester.testTextInput.log.lastWhere(
        (call) => call.method == 'TextInput.setClient',
      );
      final client = (call.arguments as List).first;
      expect(
        tester.testTextInput.setClientArgs!['contentCommitMimeTypes'],
        contains('image/png'),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.performAction', [
            client,
            'TextInputAction.commitContent',
            const {
              'mimeType': 'image/png',
              'uri': 'content://keyboard/image',
              'data': [1, 2, 3],
            },
          ]),
        ),
        (_) {},
      );
      await settleEditor(tester);
      expect(received, ['image.png:data:image/png;base64,AQID']);
      expect(
        _editor(tester).controller.state.doc.child(0).attrs['src'],
        'image-saved.png',
      );
      await controller.flush();
    },
  );

  testWidgets(
    'metadata callbacks and title scroll together with body; scroll restore and TOC',
    (tester) async {
      var dates = 0, categories = 0, tags = 0;
      final controller = MoodiaryEditorController();
      final meta = jsonEncode({
        'dateText': '2026-11-07',
        'subText': '12:34',
        'category': 'Personal',
        'tags': ['hello'],
        'moods': [],
      });
      final nodes = <ft.Node>[
        _schema.node(
          'heading',
          attrs: {'level': 1},
          content: [_schema.node('text', text: 'First')],
        ),
        for (var i = 0; i < 30; i++) _p('Paragraph $i'),
        _schema.node(
          'heading',
          attrs: {'level': 2},
          content: [_schema.node('text', text: 'Last')],
        ),
        _p('end'),
      ];
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialTitle: 'Diary',
            initialContent: _json(nodes),
            metaJson: meta,
            onPickDate: () => dates++,
            onPickCategory: () => categories++,
            onAddTag: () => tags++,
          ),
        ),
      );
      await settleEditor(tester);
      expect(_editor(tester).scrollController!.positions, hasLength(1));
      await tester.tap(find.text('2026-11-07'));
      await tester.tap(find.text('Personal'));
      await tester.tap(find.byIcon(LucideIcons.hash));
      expect([dates, categories, tags], [1, 1, 1]);
      final titleTop = tester
          .getTopLeft(find.byKey(const ValueKey('editor-title')))
          .dy;
      final before = _geometry(tester).rowRect(0).top;
      controller.setScrollY(70);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('editor-title'))).dy,
        closeTo(titleTop - 70, .01),
      );
      expect(_geometry(tester).rowRect(0).top, closeTo(before - 70, .01));
      expect(controller.getScrollY(), 70);
      await controller.scrollToHeading(1);
      await tester.pump();
      expect(controller.getScrollY(), greaterThan(700));
      await controller.swapDocument(
        content: _json(nodes),
        title: 'Next',
        scrollY: 100,
      );
      await tester.pump();
      await tester.pump();
      expect(controller.getScrollY(), closeTo(100, .01));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('editor-title')))
            .controller!
            .text,
        'Next',
      );
    },
  );

  testWidgets(
    'duplicate diary images use absolute node-view positions in every container',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ft.Node image() => _schema.node(
        'image',
        attrs: {'src': 'duplicate.png', 'widthPercent': 25},
      );
      final nodes = [
        image(),
        _schema.node(
          'bulletList',
          content: [
            _schema.node('listItem', content: [_p(''), image()]),
          ],
        ),
        _schema.node('blockquote', content: [image()]),
        _schema.node(
          'table',
          content: [
            _schema.node(
              'tableRow',
              content: [
                _schema.node('tableCell', content: [image()]),
                _schema.node(
                  'tableCell',
                  content: [
                    _schema.node('blockquote', content: [image()]),
                  ],
                ),
              ],
            ),
            _schema.node(
              'tableRow',
              content: [
                _schema.node('tableCell', content: [_p(''), image()]),
                _schema.node('tableCell', content: [_p('')]),
              ],
            ),
          ],
        ),
      ];
      const positions = [0, 5, 9, 14, 18, 26];
      List<String>? openedImages;
      List<Object>? openedTags;
      var openedIndex = -1;
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            readOnly: true,
            initialContent: _json(nodes),
            onImageTap: (images, index, tags) {
              openedImages = images;
              openedIndex = index;
              openedTags = tags;
            },
          ),
        ),
      );
      await settleEditor(tester);
      final doc = _editor(tester).controller.state.doc;
      for (final position in positions) {
        expect(doc.nodeAt(position)?.type, 'image');
      }
      final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
      for (final hero in heroes) {
        expect(hero.child, isA<ClipRRect>());
        expect(hero.flightShuttleBuilder, isNotNull);
      }
      final tags = heroes.map((hero) => hero.tag).toList();
      expect(tags.toSet(), hasLength(positions.length));
      expect(
        tags.map((tag) => (tag as (MoodiaryEditorHost, int)).$2),
        positions,
      );
      final host = (tags.first as (MoodiaryEditorHost, int)).$1;
      for (var i = 0; i < tags.length; i++) {
        expect(
          identical((tags[i] as (MoodiaryEditorHost, int)).$1, host),
          isTrue,
        );
        await tester.tap(find.byWidget(heroes[i]));
        await tester.pump(const Duration(milliseconds: 350));
        expect(openedIndex, i);
        expect(openedImages, List.filled(positions.length, 'duplicate.png'));
        expect(openedTags, tags);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'stacked diary hosts have distinct image tags and exclude data URIs',
    (tester) async {
      final content = _json([
        _schema.node(
          'image',
          attrs: {'src': 'duplicate.png', 'widthPercent': 25},
        ),
        _schema.node(
          'image',
          attrs: {'src': 'data:image/png;base64,', 'widthPercent': 25},
        ),
      ]);
      await tester.pumpWidget(
        _app(
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: MoodiaryEditor(
                    readOnly: true,
                    initialContent: content,
                  ),
                ),
            ],
          ),
        ),
      );
      await settleEditor(tester);
      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(tags, hasLength(2));
      expect(tags.toSet(), hasLength(2));
      final first = tags[0] as (MoodiaryEditorHost, int);
      final second = tags[1] as (MoodiaryEditorHost, int);
      expect(first.$2, second.$2);
      expect(identical(first.$1, second.$1), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'read-only metadata, linked diaries and gallery/attachment callbacks',
    (tester) async {
      final opened = <String>[], gallery = <String>[];
      var index = -1, graph = 0, dates = 0;
      final nodes = [
        _schema.node(
          'image',
          attrs: {'src': 'image-one.png', 'widthPercent': 25},
        ),
        _schema.node(
          'image',
          attrs: {'src': 'image-two.png', 'widthPercent': 25},
        ),
        _schema.node(
          'attachment',
          attrs: {
            'src': 'attachment-test.pdf',
            'name': 'Report',
            'mime': 'application/pdf',
            'size': 2048,
          },
        ),
        _p(''),
      ];
      final controller = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            readOnly: true,
            initialTitle: 'Read only',
            initialContent: _json(nodes),
            metaJson: jsonEncode({
              'dateText': 'Today',
              'subText': '',
              'moods': [],
            }),
            linksJson: jsonEncode({
              'title': 'Links',
              'outgoingLabel': 'Outgoing',
              'incomingLabel': 'Incoming',
              'outgoing': [
                {'id': 'other', 'title': 'Related', 'subtitle': 'Yesterday'},
              ],
              'incoming': [],
            }),
            onOpenDiaryLink: opened.add,
            onOpenGraph: () => graph++,
            onPickDate: () => dates++,
            onImageTap: (images, at, heroTags) {
              gallery.addAll(images);
              index = at;
            },
            onAttachmentTap: (src, name, mime) =>
                opened.add('$src:$name:$mime'),
          ),
        ),
      );
      await settleEditor(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('editor-title')))
            .readOnly,
        true,
      );
      await tester.tap(find.text('Today'));
      expect(dates, 0);
      final ftController = _editor(tester).controller;
      ftController.setSelection(
        ft.NodeSelection(ftController.state.doc, nodes[0].nodeSize),
      );
      await controller.exec(EditorCommand.previewImage);
      expect(gallery, ['image-one.png', 'image-two.png']);
      expect(index, 1);
      controller.setScrollY(10000);
      await settleEditor(tester);
      await tester.tap(find.text('Report'));
      await tester.pump(const Duration(milliseconds: 350));
      await settleEditor(tester);
      expect(opened, contains('attachment-test.pdf:Report:application/pdf'));
      await tester.tap(find.text('Related'));
      expect(opened, contains('other'));
      await tester.tap(find.byIcon(LucideIcons.waypoints));
      expect(graph, 1);
    },
  );

  for (final readOnly in [false, true]) {
    testWidgets(
      'phone table code header ellipsizes and copies with readOnly=$readOnly',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final language = List.filled(20, 'long language').join(' ');
        const source = 'const value = 21;';
        await tester.pumpWidget(
          _app(
            MoodiaryEditor(
              readOnly: readOnly,
              initialContent: _json([
                _schema.node(
                  'table',
                  content: [
                    _schema.node(
                      'tableRow',
                      content: [
                        _schema.node(
                          'tableCell',
                          content: [
                            _schema.node(
                              'codeBlock',
                              attrs: {'language': language},
                              content: [_schema.node('text', text: source)],
                            ),
                          ],
                        ),
                        _schema.node('tableCell', content: [_p('middle')]),
                        _schema.node('tableCell', content: [_p('last')]),
                      ],
                    ),
                  ],
                ),
              ]),
            ),
          ),
        );
        await settleEditor(tester);
        final editor = _editor(tester), geometry = _geometry(tester);
        final cell = geometry.cellRect(4)!;
        expect(
          cell.width - editor.style.tableCellPadding.horizontal,
          closeTo(240, .01),
        );
        final label = tester.widget<Text>(find.text(language));
        expect(label.maxLines, 1);
        expect(label.overflow, TextOverflow.ellipsis);
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(language))
              .didExceedMaxLines,
          isTrue,
        );
        final copy = find.text(l10n.editor.content.codeCopy);
        expect(tester.getRect(copy).right, lessThanOrEqualTo(cell.right + 1));
        await tester.tap(copy);
        await tester.pump(const Duration(milliseconds: 350));
        expect((await Clipboard.getData('text/plain'))?.text, source);
        expect(find.text(l10n.editor.content.codeCopied), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'media width preview changes box only, node selection, code copy header',
    (tester) async {
      final controller = MoodiaryEditorController();
      await tester.pumpWidget(
        _app(
          MoodiaryEditor(
            controller: controller,
            initialContent: _json([
              _schema.node(
                'image',
                attrs: {'src': 'image-test.png', 'widthPercent': 50},
              ),
              _schema.node(
                'audio',
                attrs: {'src': 'audio-test.m4a', 'name': 'Voice'},
              ),
              _schema.node(
                'codeBlock',
                attrs: {'language': 'dart'},
                content: [_schema.node('text', text: 'const value = 21;')],
              ),
              _p(''),
            ]),
          ),
        ),
      );
      await settleEditor(tester);
      final editor = _editor(tester), geometry = _geometry(tester);
      final rect = geometry.rowRect(0);
      expect(rect.width, closeTo((800 - 32) * .5, .01));
      expect(rect.center.dx, closeTo(400, .01));
      await tester.tapAt(
        tester.getTopLeft(find.byType(ft.TiptapEditor)) + rect.center,
      );
      await settleEditor(tester);
      expect(controller.state.value.node?.type, EditorNodeType.image);
      final before = editor.controller.json;
      await controller.exec(EditorCommand.previewMediaWidth, {'percent': 25});
      await tester.pump();
      expect(editor.controller.json, before);
      expect(geometry.rowRect(0).width, closeTo(768 * .25, .01));
      await controller.exec(EditorCommand.previewMediaWidth, {'percent': null});
      await tester.pump();
      expect(geometry.rowRect(0).width, closeTo(384, .01));
      expect(find.text('Voice'), findsOneWidget);
      controller.setScrollY(10000);
      await settleEditor(tester);
      expect(find.text('dart'), findsOneWidget);
      await tester.tap(find.text(l10n.editor.content.codeCopy));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(find.text(l10n.editor.content.codeCopied), findsOneWidget);
      expect(
        (await Clipboard.getData('text/plain'))?.text,
        'const value = 21;',
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text(l10n.editor.content.codeCopy), findsOneWidget);
    },
  );

  testWidgets(
    'first-line indentation changes geometry only on first line of top-level paragraphs',
    (tester) async {
      final style = buildEditorStyle(
        brightness: Brightness.light,
        firstLineIndent: true,
      );
      final controller = ft.TiptapController(
        doc: _schema.node(
          'doc',
          content: [
            _p('A long paragraph ${'word ' * 70}'),
            _schema.node('blockquote', content: [_p('Quote')]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      final key = GlobalKey<ft.TiptapEditorState>();
      await tester.pumpWidget(
        _app(
          ft.TiptapEditor(
            key: key,
            controller: controller,
            style: style,
            readOnly: true,
          ),
        ),
      );
      await tester.pump();
      final g = key.currentState!.geometry!;
      expect(g.caretRect(1).left, closeTo(16 + 34, .01));
      final second = g.positionForOffset(
        Offset(25, g.caretRect(1).bottom + 10),
      );
      expect(g.caretRect(second).left, lessThan(40));
      expect(g.positionForOffset(g.caretRect(5).center), 5);
      final first = controller.state.doc.child(0);
      expect(
        g.caretRect(first.nodeSize + 2).left,
        closeTo(16 + style.quoteIndent, .01),
      );
    },
  );

  testWidgets('body pixels match plain Text at body size and line height', (
    tester,
  ) async {
    final style = buildEditorStyle(
      colors: const ColorScheme.light(onSurface: Color(0xff000000)),
      brightness: Brightness.light,
    );
    final controller = ft.TiptapController(
      doc: _schema.node('doc', content: [_p('Heading bold mark 中文 family')]),
    );
    addTearDown(controller.dispose);
    final editorKey = GlobalKey(), textKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            RepaintBoundary(
              key: editorKey,
              child: SizedBox(
                width: 400,
                height: 100,
                child: ColoredBox(
                  color: Colors.white,
                  child: ft.TiptapEditor(
                    controller: controller,
                    readOnly: true,
                    style: style,
                  ),
                ),
              ),
            ),
            RepaintBoundary(
              key: textKey,
              child: Container(
                width: 400,
                height: 100,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: const Text(
                  'Heading bold mark 中文 family',
                  style: TextStyle(
                    inherit: false,
                    color: Colors.black,
                    fontSize: 17,
                    height: 1.65,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    Future<List<int>> pixels(GlobalKey key) async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      return result;
    }

    final images = await tester.runAsync(
      () async => [await pixels(editorKey), await pixels(textKey)],
    );
    expect(images![0], images[1]);
  });
}
