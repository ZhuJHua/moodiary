import 'dart:async';

import 'package:mui/mui.dart';

import '../ime/ime_panel.dart';
import '../moodiary_editor.dart';
import 'context_items.dart';
import 'divider_panel.dart';
import 'editor_command.dart';
import 'editor_state.dart';
import 'editor_toolbar.dart';
import 'find_bar.dart';
import 'floating_bars.dart';
import 'format_panel.dart';
import 'insert_panel.dart';
import 'link_sheet.dart';
import 'toolbar_button.dart';
import 'toolbar_tools.dart';

class EditorToolbarHost extends StatefulWidget {
  final MoodiaryEditorController controller;
  final bool editable;
  final Future<void> Function(InsertItem item) onInsertMedia;
  final Future<void> Function(EditorSelectedNode node, String? name)
  onMediaRenamed;
  final Widget child;
  final Widget? statusBar;

  const EditorToolbarHost({
    super.key,
    required this.controller,
    required this.editable,
    required this.onInsertMedia,
    required this.onMediaRenamed,
    required this.child,
    this.statusBar,
  });

  @override
  State<EditorToolbarHost> createState() => _EditorToolbarHostState();
}

class _EditorToolbarHostState extends State<EditorToolbarHost> {
  late List<ToolbarTool> _tools = ToolbarPrefs.load();
  ToolbarPopover? _popover;

  MoodiaryEditorController get _c => widget.controller;
  ImePanelController<EditorPanel> get _panel => _c.panel;
  EditorState get _state => _c.state.value;

  @override
  void initState() {
    super.initState();
    _c.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(covariant EditorToolbarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.removeListener(_onState);
      widget.controller.state.addListener(_onState);
    }
    if (!oldWidget.editable && widget.editable) _tools = ToolbarPrefs.load();
  }

  @override
  void dispose() {
    _c.state.removeListener(_onState);
    super.dispose();
  }

  void _exec(EditorCommand command, [Map<String, Object?>? args]) {
    unawaited(_c.exec(command, args));
  }

  void _onState() {
    final s = _state;
    if (s.selection == .node && _c.focusTarget.value == .editor) {
      if (_panel.type == .keyboard) _panel.showPanel(.block);
    } else if (_panel.panel case .block || .divider) {
      _panel.showKeyboard();
    }
    final popover = switch (_popover) {
      .width when s.nodeType == .image || s.nodeType == .video => _popover,
      .table when s.inTable => _popover,
      _ => null,
    };
    if (popover != _popover) setState(() => _popover = popover);
  }

  void _togglePanel(EditorPanel panel) {
    if (_panel.panel == panel) {
      _panel.showKeyboard();
    } else {
      _panel.showPanel(panel);
    }
  }

  void _togglePopover(ToolbarPopover popover) =>
      setState(() => _popover = _popover == popover ? null : popover);

  Future<void> _onKeyboardToggle() async {
    if (_panel.type == .keyboard) {
      _panel.hide();
      return;
    }
    if (_state.selection == .node) await _c.exec(.caretAfterNode);
    _panel.showKeyboard();
  }

  Future<void> _editLink() async {
    final s = _state;
    final input = await _c.withInputSuspended(
      () async => mounted
          ? showLinkSheet(
              context,
              text: s.link?.text ?? s.selectedText,
              href: s.link?.href ?? '',
            )
          : null,
    );
    if (input == null || !mounted) return;
    await _c.exec(.setLink, {'text': input.text, 'href': input.href});
  }

  Future<void> _pickDividerStyle(HorizontalRuleVariant variant) async {
    String? label;
    if (variant == .text) {
      label = await _c.withInputSuspended(
        () async => mounted
            ? showDividerLabelSheet(
                context,
                _state.node?.attrs['label'] as String?,
              )
            : null,
      );
      if (label == null || !mounted) return;
    }
    await _c.exec(.setHorizontalRule, {
      'variant': variant.name,
      'label': label,
    });
  }

  Future<void> _renameMedia() async {
    final node = _state.node;
    if (node == null) return;
    final current = node.attrs['name'] as String?;
    final input = await _c.withInputSuspended(
      () async => mounted ? showMediaNameSheet(context, current) : null,
    );
    if (input == null || !mounted) return;
    final name = input.isEmpty ? null : input;
    if (name == current) return;
    await _c.exec(.setMediaName, {'name': name});
    await widget.onMediaRenamed(node, name);
  }

  void _onInsert(InsertItem item) {
    if (item.media) {
      unawaited(widget.onInsertMedia(item));
      return;
    }
    switch (item) {
      case .table:
        _exec(.insertTable);
      case .divider:
        _exec(.insertHorizontalRule);
      case .quote:
        _exec(.insertBlockquote);
      case .codeBlock:
        _exec(.insertCodeBlock);
      case .task:
        _exec(.insertTaskList);
      case .diaryLink:
        _exec(.insertDiaryLink);
      default:
    }
    _panel.showKeyboard();
  }

  void _onTool(ToolbarTool tool) {
    switch (tool) {
      case .insert:
        _togglePanel(.insert);
      case .format:
        _togglePanel(.format);
      case .task:
        _exec(.toggleTaskList);
      case .image:
        unawaited(widget.onInsertMedia(.gallery));
      case .link:
        unawaited(_editLink());
      case .diaryLink:
        _exec(.insertDiaryLink);
      case .bold:
        _exec(.toggleBold);
      case .italic:
        _exec(.toggleItalic);
      case .underline:
        _exec(.toggleUnderline);
      case .strike:
        _exec(.toggleStrike);
      case .highlight:
        _exec(.toggleHighlight);
      case .inlineCode:
        _exec(.toggleCode);
      case .bulletList:
        _exec(.toggleBulletList);
      case .orderedList:
        _exec(.toggleOrderedList);
      case .quote:
        _exec(.toggleBlockquote);
      case .codeBlock:
        _exec(.toggleCodeBlock);
      case .table:
        _exec(.insertTable);
      case .divider:
        _exec(.insertHorizontalRule);
      case .camera:
        unawaited(widget.onInsertMedia(.camera));
      case .video:
        unawaited(widget.onInsertMedia(.video));
      case .record:
        unawaited(widget.onInsertMedia(.record));
      case .audio:
        unawaited(widget.onInsertMedia(.audio));
      case .attachment:
        unawaited(widget.onInsertMedia(.attachment));
      case .clearFormat:
        _exec(.clearFormatting);
    }
  }

  static const _markTools = {
    ToolbarTool.bold,
    ToolbarTool.italic,
    ToolbarTool.underline,
    ToolbarTool.strike,
    ToolbarTool.highlight,
    ToolbarTool.inlineCode,
  };

  ToolbarButtonTone _toneOf(ToolbarTool tool) {
    final s = _state;
    final on = switch (tool) {
      .insert => _panel.panel == .insert,
      .format => _panel.panel == .format,
      _ => false,
    };
    if (on) return .pressed;
    final active = switch (tool) {
      .task => s.list == .task,
      .link => s.link != null,
      .bold => s.has(.bold),
      .italic => s.has(.italic),
      .underline => s.has(.underline),
      .strike => s.has(.strike),
      .highlight => s.has(.highlight),
      .inlineCode => s.has(.code),
      .bulletList => s.list == .bullet,
      .orderedList => s.list == .ordered,
      .quote => s.block == .blockquote,
      .codeBlock => s.block == .codeBlock,
      _ => false,
    };
    return active ? .active : .plain;
  }

  bool _enabledOf(ToolbarTool tool) => switch (tool) {
    .table => !_state.inTable,
    _ => true,
  };

  Widget? _floating() {
    final s = _state;
    final link = s.link;
    if (link != null &&
        s.selection == .caret &&
        _panel.type != .custom &&
        _c.focusTarget.value == .editor) {
      return LinkBar(
        href: link.href,
        onOpen: () => _exec(.openLink),
        onCopy: () => _exec(.copyLink),
        onEdit: () => unawaited(_editLink()),
        onRemove: () => _exec(.unsetLink),
      );
    }
    switch (_popover) {
      case .width:
        final percent = s.node?.attrs['widthPercent'];
        return Center(
          child: WidthPicker(
            current: percent is num ? percent.toInt() : null,
            onPick: (p) => _exec(.setMediaWidth, {'percent': p}),
          ),
        );
      case .table:
        return Center(
          child: TableMenuBar(
            onToggleHeader: () => _exec(.tableToggleHeaderRow),
            onDelete: () => _exec(.tableDelete),
          ),
        );
      case null:
        return null;
    }
  }

  Widget _buildPanel(BuildContext context, EditorPanel panel) {
    final colors = context.theme.colors;
    final s = _state;
    return switch (panel) {
      .block => ColoredBox(color: colors.surfaceContainerLow),
      .insert => ColoredBox(
        color: colors.surfaceContainer,
        child: InsertPanel(inTable: s.inTable, onInsert: _onInsert),
      ),
      .format => ColoredBox(
        color: colors.surfaceContainer,
        child: ValueListenableBuilder(
          valueListenable: _c.state,
          builder: (_, state, _) => FormatPanel(state: state, exec: _exec),
        ),
      ),
      .divider => ColoredBox(
        color: colors.surfaceContainer,
        child: ValueListenableBuilder(
          valueListenable: _c.state,
          builder: (_, state, _) => DividerStylePanel(
            current: HorizontalRuleVariant.values
                .asNameMap()[state.node?.attrs['variant']],
            label: state.node?.attrs['label'] as String?,
            onPick: (v) => unawaited(_pickDividerStyle(v)),
          ),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Column(
      children: [
        ValueListenableBuilder(
          valueListenable: _c.searchOpen,
          builder: (_, open, _) => open
              ? EditorFindBar(controller: _c, editable: widget.editable)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (widget.editable)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 8,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _c.state,
                      _c.focusTarget,
                      _panel,
                    ]),
                    builder: (_, _) => _floating() ?? const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
        if (widget.editable) ...[
          if (widget.statusBar case final status?)
            ListenableBuilder(
              listenable: Listenable.merge([_c.focusTarget, _panel]),
              builder: (context, child) => Container(
                height: 28,
                padding: const .symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      _c.focusTarget.value == .editor || _panel.type == .custom
                      ? colors.surfaceContainerLow
                      : colors.surface,
                  border: Border(
                    top: BorderSide(color: colors.surfaceContainerHighest),
                  ),
                ),
                child: child,
              ),
              child: status,
            ),
          ListenableBuilder(
            listenable: Listenable.merge([_c.state, _c.focusTarget, _panel]),
            builder: (context, _) {
              final visible =
                  _c.focusTarget.value == .editor || _panel.type == .custom;
              if (!visible) return const SizedBox.shrink();
              final inCode = _state.inCodeBlock;
              final toolbarContext = buildToolbarContext(
                context,
                state: _state,
                exec: _exec,
                popover: _popover,
                dividerPanelOpen: _panel.panel == .divider,
                onTogglePopover: _togglePopover,
                onToggleDividerPanel: () => _togglePanel(.divider),
                onRenameMedia: () => unawaited(_renameMedia()),
              );
              return EditorToolbar(
                contextKind: toolbarContext.kind,
                contextItems: toolbarContext.items,
                tools: switch (toolbarContext.kind) {
                  .text => ToolbarTool.selection,
                  .block => const [],
                  _ => [
                    for (final tool in _tools)
                      if (!(inCode && _markTools.contains(tool))) tool,
                  ],
                },
                toneOf: _toneOf,
                enabledOf: _enabledOf,
                onTool: _onTool,
                keyboardShown: _panel.type == .keyboard,
                onKeyboardToggle: () => unawaited(_onKeyboardToggle()),
              );
            },
          ),
          ListenableBuilder(
            listenable: Listenable.merge([_c.focusTarget, _panel]),
            builder: (context, _) => ImePanelContainer<EditorPanel>(
              controller: _panel,
              target: _c.imeTarget,
              compact: (panel) => panel == .block,
              panelBuilder: _buildPanel,
              backgroundColor:
                  _c.focusTarget.value == .editor || _panel.type == .custom
                  ? colors.surfaceContainerLow
                  : colors.surface,
            ),
          ),
        ] else
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }
}
