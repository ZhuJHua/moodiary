import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/src/ime/ime_height.dart';
import 'package:moodiary_editor/src/ime/ime_panel.dart';
import 'package:moodiary_editor/src/moodiary_editor.dart';
import 'package:moodiary_editor/src/toolbar/context_items.dart';
import 'package:moodiary_editor/src/toolbar/editor_state.dart';
import 'package:moodiary_editor/src/toolbar/editor_toolbar.dart';
import 'package:moodiary_editor/src/toolbar/editor_toolbar_host.dart';
import 'package:moodiary_editor/src/toolbar/floating_bars.dart';
import 'package:moodiary_editor/src/toolbar/format_panel.dart';
import 'package:moodiary_editor/src/toolbar/panel_parts.dart';
import 'package:moodiary_editor/src/toolbar/toolbar_button.dart';
import 'package:moodiary_editor/src/toolbar/toolbar_tools.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

class _FakeTarget implements ImeTarget {
  final focusedNotifier = ValueNotifier(false);
  final calls = <String>[];

  @override
  ValueListenable<bool> get focused => focusedNotifier;

  @override
  Future<bool> suppressKeyboard(bool suppressed) async {
    calls.add('suppress:$suppressed');
    return true;
  }

  @override
  Future<void> dismiss() async {
    calls.add('dismiss');
    focusedNotifier.value = false;
  }
}

KeyboardEvent _event({required bool visible, required bool start}) =>
    KeyboardEvent(
      visible: visible,
      height: visible ? 300 : 0,
      durationMs: 250,
      isStart: start,
      floating: false,
    );

void main() {
  group('mergeOrder', () {
    test('新默认项插到它默认位置前一个邻居之后', () {
      expect(mergeOrder(['a', 'b', 'c', 'd'], ['c', 'a', 'd']), [
        'c',
        'a',
        'b',
        'd',
      ]);
    });

    test('没有前邻居时插到最前', () {
      expect(mergeOrder(['a', 'b'], ['b']), ['a', 'b']);
    });

    test('用户移除过的默认项不再补回', () {
      expect(mergeOrder(['a', 'b', 'c'], ['c', 'a'], skip: {'b'}), ['c', 'a']);
    });
  });

  group('resolveToolbar', () {
    test('没有存过配置时用默认顺序', () {
      expect(resolveToolbar(null, {}), ToolbarTool.defaults);
      expect(resolveToolbar(const [], {}), ToolbarTool.defaults);
    });

    test('丢弃不认识的 id', () {
      final tools = resolveToolbar(
        ['bold', 'gone', 'image'],
        {'insert', 'format', 'task', 'link', 'diaryLink'},
      );
      expect(tools, [ToolbarTool.bold, ToolbarTool.image]);
    });

    test('全部移除后保持为空，不回落到默认', () {
      expect(
        resolveToolbar(const [], {
          for (final t in ToolbarTool.defaults) t.name,
        }),
        isEmpty,
      );
    });

    test('自选的非默认项保留，未移除的默认项按邻居补回', () {
      final tools = resolveToolbar(['insert', 'bold', 'format'], {'task'});
      expect(tools, [
        ToolbarTool.insert,
        ToolbarTool.bold,
        ToolbarTool.format,
        ToolbarTool.image,
        ToolbarTool.link,
        ToolbarTool.diaryLink,
      ]);
    });
  });

  testWidgets('选区工具在 360dp 宽的屏上一屏放下', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: MuiTheme(
          data: buildMuiTheme(brightness: .light),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: .bottomCenter,
                child: EditorToolbar(
                  contextKind: .text,
                  tools: ToolbarTool.selection,
                  toneOf: (_) => .plain,
                  enabledOf: (_) => true,
                  onTool: (_) {},
                  keyboardShown: true,
                  onKeyboardToggle: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Finder button(IconData icon) => find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(ToolbarIconButton),
    );
    final toggle = tester.getTopLeft(button(LucideIcons.chevronDown)).dx;
    for (final tool in ToolbarTool.selection) {
      expect(
        tester.getTopRight(button(tool.icon)).dx,
        lessThanOrEqualTo(toggle),
      );
    }
  });

  testWidgets('媒体名称标签显示名称，没有名称时显示类型，点击触发重命名', (tester) async {
    var renames = 0;
    Future<void> mount(EditorNodeType type, String? name) => tester.pumpWidget(
      TranslationProvider(
        child: MuiTheme(
          data: buildMuiTheme(brightness: .light),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: .bottomCenter,
                child: Builder(
                  builder: (context) {
                    final toolbar = buildToolbarContext(
                      context,
                      state: EditorState(
                        selection: .node,
                        node: (
                          type: type,
                          attrs: {'src': 'audio-1.m4a', 'name': name},
                        ),
                      ),
                      exec: (_, [_]) {},
                      popover: null,
                      onTogglePopover: (_) {},
                      onRenameMedia: () => renames++,
                    );
                    return EditorToolbar(
                      contextKind: toolbar.kind,
                      contextItems: toolbar.items,
                      tools: const [],
                      toneOf: (_) => .plain,
                      enabledOf: (_) => true,
                      onTool: (_) {},
                      keyboardShown: true,
                      onKeyboardToggle: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final chip = find.byType(ToolbarNameChip);
    Finder chipText(String text) =>
        find.descendant(of: chip, matching: find.text(text));

    await mount(.audio, '晨跑 录音');
    expect(chipText('晨跑 录音'), findsOneWidget);
    await tester.tap(chip);
    expect(renames, 1);

    await mount(.audio, null);
    expect(chipText(l10n.editor.toolbar.audio), findsOneWidget);

    await mount(.image, '  ');
    expect(chipText(l10n.editor.toolbar.image), findsOneWidget);

    await mount(.attachment, 'quarterly report final version (2).pdf' * 3);
    expect(tester.getSize(chip).width, lessThanOrEqualTo(160));
  });

  testWidgets('格式面板切换段落样式时选中底色立即换位，旧选项不淡出', (tester) async {
    final state = ValueNotifier(const EditorState());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: MuiTheme(
          data: buildMuiTheme(brightness: .light),
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: state,
                builder: (_, s, _) => FormatPanel(state: s, exec: (_, [_]) {}),
              ),
            ),
          ),
        ),
      ),
    );
    BoxDecoration? decorationOf(int index) =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(PanelSegment).at(index),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration?;
    final colors = tester.element(find.byType(FormatPanel)).theme.colors;
    expect(decorationOf(0)?.color, colors.secondaryContainer);

    state.value = const EditorState(block: .heading1);
    await tester.pump();
    expect(decorationOf(0)?.boxShadow, isNull);
    expect(decorationOf(0)?.color, isNull);
    expect(decorationOf(1)?.color, colors.secondaryContainer);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '选中态切换不该有过渡动画');
  });

  for (final brightness in Brightness.values) {
    testWidgets('工具栏随页面，选中态柔和且分组内外一致：${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        TranslationProvider(
          child: MuiTheme(
            data: buildMuiTheme(brightness: brightness),
            child: MaterialApp(
              theme: buildMuiTheme(brightness: brightness),
              home: Scaffold(
                body: Align(
                  alignment: .bottomCenter,
                  child: EditorToolbar(
                    contextKind: .table,
                    contextItems: [
                      ToolbarIconButton(
                        icon: LucideIcons.tableProperties,
                        tooltip: 'grouped',
                        tone: .on,
                        onTap: () {},
                      ),
                    ],
                    tools: const [ToolbarTool.insert, ToolbarTool.bold],
                    toneOf: (tool) => tool == .insert ? .on : .active,
                    enabledOf: (_) => true,
                    onTool: (_) {},
                    keyboardShown: true,
                    onKeyboardToggle: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final toolbar = tester.element(find.byType(EditorToolbar));
      final colors = toolbar.theme.colors;
      final selected = colors.secondaryContainer;
      final foreground = colors.onSecondaryContainer;
      BoxDecoration decorationOf(String tooltip) =>
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byWidgetPredicate(
                        (w) => w is ToolbarIconButton && w.tooltip == tooltip,
                      ),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      final barDecoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(EditorToolbar),
                      matching: find.byWidgetPredicate(
                        (w) => w is Container && w.constraints?.maxHeight == 52,
                      ),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(barDecoration.color, colors.surface);
      expect(
        (barDecoration.border! as Border).top.color,
        colors.outlineVariant,
      );
      expect((barDecoration.border! as Border).top.width, 1);
      expect((barDecoration.border! as Border).bottom, BorderSide.none);
      for (final divider in tester.widgetList<VerticalDivider>(
        find.descendant(
          of: find.byType(EditorToolbar),
          matching: find.byType(VerticalDivider),
        ),
      )) {
        expect(divider.thickness, 1);
        expect(divider.color, colors.outlineVariant);
      }
      expect(decorationOf('grouped').color, selected);
      expect(decorationOf('grouped').boxShadow, isNull);
      final tool = ToolbarTool.insert.label(toolbar);
      expect(decorationOf(tool).color, selected);
      expect(decorationOf(tool).boxShadow, isNull);
      expect(decorationOf(ToolbarTool.bold.label(toolbar)).color, selected);
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.plus)).color,
        foreground,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.bold)).color,
        foreground,
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('后台收键盘保留焦点时安全区随工具栏，只有展开面板使用面板色：${brightness.name}', (
      tester,
    ) async {
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      addTearDown(getIt.reset);
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      tester.view.viewPadding = const FakeViewPadding(bottom: 60);
      addTearDown(tester.view.reset);
      const channel =
          'dev.flutter.pigeon.moodiary_native.EditorKeyboardEvents.keyboardEvents';
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channel, pigeonMethodCodec),
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel(channel, pigeonMethodCodec),
          null,
        ),
      );
      final controller = MoodiaryEditorController();
      final focus = controller.focusTarget as ValueNotifier<EditorFocusTarget>;
      final theme = buildMuiTheme(
        brightness: brightness,
        accent: const MuiAccent.seeded(Color(0xFF4F794A)),
      );
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: EditorToolbarHost(
                controller: controller,
                editable: true,
                onInsertMedia: (_) async {},
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      ImePanelContainer<EditorPanel> container() =>
          tester.widget(find.byType(ImePanelContainer<EditorPanel>));
      expect(container().backgroundColor, theme.colorScheme.surface);
      focus.value = .editor;
      await tester.pump();
      expect(controller.panel.type, ImePanelType.keyboard);
      expect(container().backgroundColor, theme.colorScheme.surface);

      tester.binding.handleAppLifecycleStateChanged(.paused);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(.resumed),
      );
      await messenger.handlePlatformMessage(
        channel,
        pigeonMethodCodec.encodeSuccessEnvelope(
          _event(visible: false, start: true),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(controller.panel.type, ImePanelType.none);
      expect(focus.value, EditorFocusTarget.editor);
      expect(find.byType(EditorToolbar), findsOneWidget);
      expect(container().backgroundColor, theme.colorScheme.surface);
      expect(
        tester.getSize(find.byType(ImePanelContainer<EditorPanel>)).height,
        20,
      );

      tester.binding.handleAppLifecycleStateChanged(.resumed);
      for (final panel in [EditorPanel.format, EditorPanel.insert]) {
        controller.panel.showPanel(panel);
        await tester.pumpAndSettle();
        expect(
          container().backgroundColor,
          theme.colorScheme.surfaceContainerLow,
        );
      }
      controller.panel.showPanel(.block);
      await tester.pumpAndSettle();
      expect(container().backgroundColor, theme.colorScheme.surface);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('宽度弹层：吸附 ±3 并预览，按住拖动只在松手提交一次，点轨道和读屏步进立即提交', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previews = <int>[];
    final picks = <int?>[];
    Future<void> mount(int? current) => tester.pumpWidget(
      TranslationProvider(
        child: MuiTheme(
          data: buildMuiTheme(brightness: .light),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: WidthPicker(
                  current: current,
                  onPreview: previews.add,
                  onPick: picks.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    double thumb() => tester.widget<Slider>(find.byType(Slider)).value;
    Offset at(double percent) {
      final track = tester.getRect(find.byType(Slider));
      return Offset(
        track.left + (percent - 25) / 75 * track.width,
        track.center.dy,
      );
    }

    void step({required bool up}) {
      final props = tester
          .widget<Semantics>(
            find
                .byWidgetPredicate(
                  (w) => w is Semantics && (w.properties.slider ?? false),
                )
                .first,
          )
          .properties;
      (up ? props.onIncrease : props.onDecrease)!();
    }

    final t = l10n.editor.toolbar;

    await mount(null);
    expect(thumb(), 100);
    expect(find.text(t.originalSize), findsOneWidget);
    await tester.tap(find.text(t.original));
    await tester.tap(find.text('50%'));
    expect(picks, [50]);

    final drag = await tester.startGesture(at(47.6));
    await tester.pump(const Duration(milliseconds: 200));
    await drag.moveTo(at(55));
    await tester.pump();
    await drag.moveTo(at(61.4));
    await tester.pump();
    expect(picks, [50]);
    await drag.up();
    await tester.pump();
    expect(previews.last, 61);
    expect(picks, [50, 61]);
    expect(thumb(), 61);
    expect(find.text('61%'), findsOneWidget);

    await mount(61);
    await tester.tapAt(at(75.4));
    await tester.pump();
    expect(picks, [50, 61, 75]);

    final back = await tester.startGesture(at(75));
    await back.moveTo(at(63));
    await tester.pump();
    await back.moveTo(at(60.6));
    await tester.pump();
    await back.up();
    await tester.pump();
    expect(picks, [50, 61, 75]);
    expect(thumb(), 61);

    step(up: true);
    await tester.pump();
    expect(picks, [50, 61, 75, 62]);

    await tester.tap(find.text(t.original));
    expect(picks, [50, 61, 75, 62, null]);

    await mount(100);
    step(up: false);
    await tester.pump();
    await mount(75);
    step(up: true);
    await tester.pump();
    expect(picks, [50, 61, 75, 62, null, 99, 76]);
  });

  group('EditorState.fromJson', () {
    test('解析完整状态', () {
      final state = EditorState.fromJson({
        'marks': {'bold': true, 'italic': false, 'link': true},
        'block': 'heading2',
        'list': 'task',
        'canIndent': true,
        'canOutdent': false,
        'canUndo': true,
        'canRedo': false,
        'selection': 'node',
        'node': {
          'type': 'image',
          'attrs': {'src': 'image-1.png', 'widthPercent': 50},
        },
        'inTable': false,
        'link': {'href': 'https://example.com', 'text': 'ex'},
        'selectedText': '',
      });
      expect(state.marks, {EditorMark.bold, EditorMark.link});
      expect(state.block, EditorBlock.heading2);
      expect(state.block.headingLevel, 2);
      expect(state.list, EditorList.task);
      expect(state.nodeType, EditorNodeType.image);
      expect(state.node?.attrs['widthPercent'], 50);
      expect(state.link?.href, 'https://example.com');
      expect(state.canUndo, isTrue);
    });

    test('缺字段或未知枚举值回落到默认', () {
      final state = EditorState.fromJson({
        'block': 'mystery',
        'selection': 'node',
        'node': {'type': 'mystery'},
      });
      expect(state.block, EditorBlock.paragraph);
      expect(state.node, isNull);
      expect(state.nodeType, isNull);
      expect(state.list, isNull);
      expect(state.marks, isEmpty);
    });

    test('非节点选区不报告选中节点类型', () {
      final state = EditorState.fromJson({
        'selection': 'caret',
        'node': {'type': 'image', 'attrs': {}},
      });
      expect(state.nodeType, isNull);
    });
  });

  group('IME 高度', () {
    test('无效高度回落到默认值', () {
      expect(resolveImeHeight(null), defaultImeHeight);
      expect(resolveImeHeight(0), defaultImeHeight);
      expect(resolveImeHeight(280), 280);
    });

    test('面板高度不超过屏高一半减 48', () {
      expect(resolveImePanelHeight(400, 600), 252);
      expect(resolveImePanelHeight(240, 900), 240);
      expect(maxImePanelHeight(40), 0);
    });
  });

  group('ImePanelContainer', () {
    late _FakeTarget target;
    late ImePanelController<String> controller;
    late StreamController<KeyboardEvent> events;

    setUp(() {
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
      target = _FakeTarget();
      controller = ImePanelController<String>();
      events = StreamController<KeyboardEvent>.broadcast();
    });

    tearDown(() async {
      await events.close();
      await getIt.reset();
    });

    Future<void> mount(WidgetTester tester, {double insets = 0}) =>
        tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              viewInsets: .only(bottom: insets),
              viewPadding: const .only(bottom: 20),
            ),
            child: Directionality(
              textDirection: .ltr,
              child: Align(
                alignment: .bottomCenter,
                child: ImePanelContainer<String>(
                  controller: controller,
                  target: target,
                  keyboardEvents: events.stream,
                  compact: (panel) => panel == 'block',
                  panelBuilder: (_, panel) => SizedBox(key: ValueKey(panel)),
                ),
              ),
            ),
          ),
        );

    double height(WidgetTester tester) =>
        tester.getSize(find.byType(ImePanelContainer<String>)).height;

    Future<void> keyboardUp(WidgetTester tester) async {
      await mount(tester, insets: 300);
      target.focusedNotifier.value = true;
      events.add(_event(visible: true, start: true));
      await tester.pumpAndSettle();
    }

    testWidgets('聚焦后键盘位跟随键盘高度', (tester) async {
      await keyboardUp(tester);
      expect(controller.type, ImePanelType.keyboard);
      expect(height(tester), 300);
    });

    testWidgets('面板沿用量到的键盘高度并收起键盘', (tester) async {
      await keyboardUp(tester);
      controller.showPanel('format');
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.custom);
      expect(controller.panel, 'format');
      expect(target.calls, contains('suppress:true'));
      expect(height(tester), 300);
    });

    testWidgets('收起事件之前的可见事件是过时的，之后的才切回键盘', (tester) async {
      await keyboardUp(tester);
      controller.showPanel('format');
      await tester.pumpAndSettle();
      events.add(_event(visible: true, start: true));
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.custom);

      events.add(_event(visible: false, start: false));
      events.add(_event(visible: true, start: true));
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.keyboard);
      expect(target.calls.last, 'suppress:false');
    });

    testWidgets('紧凑面板只留安全区高度', (tester) async {
      await keyboardUp(tester);
      controller.showPanel('block');
      await tester.pumpAndSettle();
      expect(height(tester), 20);
    });

    testWidgets('容器卸载时面板状态复位并恢复键盘', (tester) async {
      await keyboardUp(tester);
      controller.showPanel('format');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(controller.type, ImePanelType.none);
      expect(target.calls.last, 'suppress:false');
    });

    testWidgets('小窗下键盘不占 viewInsets，从面板切回后退回 none 且焦点保留', (tester) async {
      await keyboardUp(tester);
      controller.showPanel('format');
      await tester.pumpAndSettle();
      await mount(tester);
      controller.showKeyboard();
      await tester.pump();
      expect(height(tester), greaterThan(20));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.none);
      expect(target.calls, isNot(contains('dismiss')));
      expect(height(tester), 20);
    });

    testWidgets('悬浮键盘下面板照常可开', (tester) async {
      await mount(tester);
      target.focusedNotifier.value = true;
      events.add(
        KeyboardEvent(
          visible: true,
          height: 0,
          durationMs: 0,
          isStart: true,
          floating: true,
        ),
      );
      await tester.pump();
      controller.showPanel('format');
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.custom);
    });

    testWidgets('hide 让输入目标失焦', (tester) async {
      await keyboardUp(tester);
      controller.hide();
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.none);
      expect(target.calls, contains('dismiss'));
    });

    testWidgets('安卓上用户收起键盘即失焦，iOS 交给 WebKit', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(.resumed);
      await keyboardUp(tester);
      events.add(_event(visible: false, start: false));
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.none);
      expect(target.calls, contains('dismiss'));

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      target.calls.clear();
      events.add(_event(visible: true, start: true));
      await tester.pumpAndSettle();
      events.add(_event(visible: false, start: false));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
      expect(controller.type, ImePanelType.none);
      expect(target.calls, isNot(contains('dismiss')));
    });

    testWidgets('安卓收起动画一开始就失焦，iOS 等动画结束', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(.resumed);
      await keyboardUp(tester);
      events.add(_event(visible: false, start: true));
      await tester.pumpAndSettle();
      expect(controller.type, ImePanelType.none);
      expect(target.calls, contains('dismiss'));

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      target.focusedNotifier.value = true;
      events.add(_event(visible: true, start: true));
      await tester.pumpAndSettle();
      events.add(_event(visible: false, start: true));
      await tester.pumpAndSettle();
      final typeAfterStart = controller.type;
      events.add(_event(visible: false, start: false));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
      expect(typeAfterStart, ImePanelType.keyboard);
      expect(controller.type, ImePanelType.none);
    });

    testWidgets('release 失焦并等键盘真正退场', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await keyboardUp(tester);
      var released = false;
      unawaited(controller.release().then((_) => released = true));
      await tester.pump();
      expect(controller.type, ImePanelType.none);
      expect(target.calls, contains('dismiss'));
      expect(released, isFalse);

      tester.view.resetViewInsets();
      await tester.pump();
      expect(released, isTrue);
    });
  });
  test('附件改名只改主文件名，扩展名跟实际文件走', () {
    expect(splitAttachmentName('旅行计划.pdf', 'file-1.pdf'), ('旅行计划', '.pdf'));
    expect(splitAttachmentName('合同.PDF', 'file-1.pdf'), ('合同', '.PDF'));
    expect(splitAttachmentName('笔记 v1.2', 'file-1.md'), ('笔记 v1.2', '.md'));
    expect(splitAttachmentName('奇怪.x-y', 'file-1.bin'), ('奇怪', '.x-y'));
    expect(splitAttachmentName('无扩展名', 'file-1.bin'), ('无扩展名', ''));
  });
}
