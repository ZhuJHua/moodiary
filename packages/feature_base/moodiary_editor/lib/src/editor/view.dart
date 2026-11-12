part of '../moodiary_editor.dart';

class _MoodiaryEditorState extends State<MoodiaryEditor>
    with WidgetsBindingObserver, RouteAware {
  late final MoodiaryEditorHost host;
  int? _dropTarget;
  int _dropGeneration = -1;
  Rect? _dropBounds;
  bool get _mobileDrop =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  void _receivedDrop(ImageDrop drop) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || host.readOnly) return;
    final point = box.globalToLocal(Offset(drop.x, drop.y));
    if (!(Offset.zero & box.size).contains(point)) return;
    unawaited(host.importDrop(drop, point));
  }

  void _syncDropTarget() {
    if (!mounted || !_mobileDrop) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (host.readOnly) {
      _clearDropTarget();
      return;
    }
    _dropTarget ??= _ImageDrops.instance.register(_receivedDrop);
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (_dropBounds == rect) return;
    _dropBounds = rect;
    unawaited(
      ImageTransferApi()
          .setDropTarget(
            _dropTarget!,
            rect.left,
            rect.top,
            rect.width,
            rect.height,
          )
          .catchError((Object error) {
            _dropBounds = null;
          }),
    );
  }

  void _clearDropTarget() {
    final id = _dropTarget;
    if (id == null) return;
    _ImageDrops.instance.unregister(id);
    _dropTarget = null;
    _dropBounds = null;
    unawaited(ImageTransferApi().clearDropTarget(id).catchError((Object _) {}));
  }

  // The toolbar host floats a 44 px link bar 8 px above the editor's bottom
  // while the caret is in a link; the caret has to clear it.
  bool _linkBar = false;

  void _stateChanged() {
    final state = host.state.value,
        linkBar = state.link != null && state.selection == .caret;
    if (linkBar != _linkBar && mounted) setState(() => _linkBar = linkBar);
  }

  bool _escape() {
    final controller = widget.controller;
    if (controller?.dismissTransient?.call() == true) return true;
    if (controller?.searchOpen.value == true) {
      unawaited(controller!.closeSearch());
      return true;
    }
    if (controller?.panel.type == .custom) {
      controller!.panel.showKeyboard();
      return true;
    }
    return false;
  }

  ft.TiptapEditorStyle? _style;
  ColorScheme? _colors;
  (Brightness, String?, double, bool, EditorTypography)? _styleKey;
  late final ft.TiptapCodeHighlighter _codeHighlight = _highlight;
  @override
  void initState() {
    super.initState();
    host = MoodiaryEditorHost(widget);
    widget.controller?._bind(host);
    host.addListener(_changed);
    host.state.addListener(_stateChanged);
    host.editor.onPasteConverted = _offerRestore;
    WidgetsBinding.instance.addObserver(this);
  }

  VoidCallback? _dismissRestore;
  Object? _restoreState;

  void _offerRestore(ft.TiptapPasteConversion conversion) {
    _closeRestore();
    if (!mounted) return;
    final labels = context.l10n.editor.toolbar;
    final box = context.findRenderObject() as RenderBox;
    final bottom = box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy;
    _restoreState = host.editor.state;
    _dismissRestore = MSnackbar.show(
      context,
      message: switch (conversion) {
        .markdown => labels.pasteFormatted,
        .richText => labels.pasteKeptFormat,
      },
      action: MSnackbarAction(
        label: switch (conversion) {
          .markdown => labels.restoreOriginal,
          .richText => labels.pasteUsePlain,
        },
        onPressed: host.editor.restorePastedText,
      ),
      bottom: MediaQuery.sizeOf(context).height - bottom + 8,
    );
    host.editor.addListener(_watchRestore);
  }

  // Any later edit or caret move ends the offer.
  void _watchRestore() {
    if (!identical(host.editor.state, _restoreState)) _closeRestore();
  }

  void _closeRestore() {
    host.editor.removeListener(_watchRestore);
    _dismissRestore?.call();
    _dismissRestore = null;
  }

  void _changed() {
    if (_dropGeneration != host._generation) {
      _dropGeneration = host._generation;
      _clearDropTarget();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) moodiaryRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => unawaited(host.pauseMedia());

  @override
  void didUpdateWidget(MoodiaryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._unbind(host);
      widget.controller?._bind(host);
    }
    host.update(widget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(host.flush());
  }

  @override
  void dispose() {
    _closeRestore();
    _clearDropTarget();
    WidgetsBinding.instance.removeObserver(this);
    moodiaryRouteObserver.unsubscribe(this);
    unawaited(host.flush());
    widget.controller?._unbind(host);
    host.removeListener(_changed);
    host.state.removeListener(_stateChanged);
    host.dispose();
    super.dispose();
  }

  Widget _contextMenu(
    BuildContext context,
    ft.TiptapContextMenuDetails details,
  ) {
    final labels = MaterialLocalizations.of(context);
    final pos = host.editor.state.doc.resolve(host.editor.state.selection.from);
    final chip = pos.nodeAfter?.type == ft.referenceNodeType
        ? pos.nodeAfter
        : pos.nodeBefore?.type == ft.referenceNodeType
        ? pos.nodeBefore
        : null;
    return _SelectionMenu(
      details: details,
      items: [
        if (chip != null)
          (
            LucideIcons.bookOpen,
            context.l10n.editor.toolbar.openLink,
            () {
              details.hide();
              widget.onOpenDiaryLink?.call(chip.attrs['id'] as String);
            },
          ),
        if (details.cut case final cut?)
          (LucideIcons.scissors, labels.cutButtonLabel, cut),
        if (details.copy case final copy?)
          (LucideIcons.copy, labels.copyButtonLabel, copy),
        if (details.paste case final paste?)
          (LucideIcons.clipboardPaste, labels.pasteButtonLabel, paste),
        if (details.selectAll case final selectAll?)
          (LucideIcons.textSelect, labels.selectAllButtonLabel, selectAll),
      ],
    );
  }

  TextSpan _highlight(String? language, String text) {
    return buildCodeHighlight(language, text, context.theme.brightness);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDropTarget());
    if (!widget.metaReady) return const SizedBox.expand();
    final colors = context.theme.colors, font = widget.fontResolver?.call();
    final styleKey = (
      context.theme.brightness,
      font?.family,
      widget.fontScale,
      widget.firstLineIndent,
      widget.typography,
    );
    if (_styleKey != styleKey || _colors != colors) {
      _styleKey = styleKey;
      _colors = colors;
      _style = buildEditorStyle(
        colors: colors,
        brightness: context.theme.brightness,
        fontFamily: font?.family,
        fontScale: widget.fontScale,
        fontSize: widget.typography.fontSize,
        lineHeight: widget.typography.lineHeight,
        paragraphSpacing: widget.typography.paragraphSpacing,
        firstLineIndent: widget.firstLineIndent,
      );
    }
    if (font != null) {
      unawaited(
        FontManager.loadFont(fontName: font.family, fontPath: font.path),
      );
    }
    return Material(
      color: context.theme.colors.surface,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (details) => !host.readOnly,
        onAcceptWithDetails: (details) =>
            unawaited(host.pasteImage(details.data)),
        builder: (context, _, _) => MediaQuery.withNoTextScaling(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ft.TiptapEditor(
                  key: host.editorKey,
                  controller: host.editor,
                  focusNode: host.bodyFocus,
                  scrollController: host.scroll,
                  readOnly: host.readOnly,
                  keyboardEnabled: !host.panelMode,
                  style: _style!,
                  codeHighlighter: _codeHighlight,
                  placeholder: host._loading
                      ? ''
                      : context.l10n.editor.content.bodyPlaceholder,
                  // Room for the caret ring under the last line, and no more:
                  // a document that fits above the keyboard must not scroll.
                  caretBottomMargin: _linkBar && !host.readOnly ? 12 + 52 : 12,
                  onEditingTap: () => widget.controller?.panel.showKeyboard(),
                  onFind: widget.controller?.openSearch,
                  onEditLink: () =>
                      unawaited(widget.controller?.editLink(context)),
                  onEscape: _escape,
                  onBoundaryNavigation: (direction) {
                    if (host.readOnly ||
                        !const {'up', 'shiftTab', 'tab'}.contains(direction)) {
                      return false;
                    }
                    host.title.selection = TextSelection.collapsed(
                      offset: host.title.text.length,
                    );
                    unawaited(host.focusTitle());
                    return true;
                  },
                  header: _DiaryHeader(
                    host: host,
                    font: font?.family,
                    scale: widget.fontScale,
                  ),
                  footer: host.readOnly
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 24),
                            _LinkedDiaries(host: host),
                            // Read mode runs under the gesture bar, like iOS.
                            SizedBox(
                              height: MediaQuery.viewPaddingOf(context).bottom,
                            ),
                          ],
                        )
                      : null,
                  nodeViews: host.nodeViews,
                  nodeHeightEstimator: host.estimateNodeHeight,
                  codeBlockHeader: (context, node) =>
                      _CodeHeader(node: node, readOnly: host.readOnly),
                  contextMenuBuilder: _contextMenu,
                  onLinkTap: widget.onUrlTap,
                  onReferenceTap: widget.onOpenDiaryLink,
                  onPasteText: parsePastedMarkdown,
                  onPasteImage: host.pasteImage,
                  onPasteClipboard: host.pasteClipboard,
                  onCopyClipboard: host.copyClipboard,
                ),
              ),
              ValueListenableBuilder<ft.TiptapReferenceSuggestion?>(
                valueListenable: host.editor.suggestion,
                builder: (context, suggestion, _) {
                  if (suggestion == null || host.readOnly) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 16,
                    right: 16,
                    bottom: 8,
                    child: Material(
                      color: context.theme.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            if (suggestion.loading)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            for (final item in suggestion.items)
                              ListTile(
                                dense: true,
                                title: Text(item.label),
                                onTap: () => host.editor.insertReference(item),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A card raised above the page, one icon and label per action. It grows out
// of the caret when it appears.
class _SelectionMenu extends StatelessWidget {
  const _SelectionMenu({required this.details, required this.items});

  final ft.TiptapContextMenuDetails details;
  final List<(IconData, String, VoidCallback)> items;

  // Clears the range handles' knobs above and below the selection.
  static const _gap = 18.0, _height = 68.0, _inset = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors,
        foreground = colors.onSurface,
        top = MediaQuery.paddingOf(context).top + 8,
        above = details.anchorAbove - Offset(8, top + _gap),
        below = details.anchorBelow - Offset(8, top - _gap),
        fitsAbove = above.dy >= _height;
    final style = context.theme.typography.labelSmall.withColor(foreground);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: .7 + .3 * t,
          alignment: Alignment.topLeft,
          origin: fitsAbove ? details.anchorAbove : details.anchorBelow,
          child: child,
        ),
      ),
      child: Padding(
        padding: .fromLTRB(8, top, 8, 8),
        child: CustomSingleChildLayout(
          delegate: TextSelectionToolbarLayoutDelegate(
            anchorAbove: above,
            anchorBelow: below,
            fitsAbove: fitsAbove,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.surfaceBright,
              shape: const RoundedRectangleBorder(borderRadius: MuiRadius.xl),
              shadows: MGlassSurface.defaultShadows(colors),
            ),
            child: ClipRRect(
              borderRadius: MuiRadius.xl,
              child: SizedBox(
                height: _height,
                child: SingleChildScrollView(
                  scrollDirection: .horizontal,
                  padding: const .symmetric(horizontal: _inset),
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      for (final (icon, label, onPressed) in items)
                        MInkWell(
                          onTap: onPressed,
                          borderRadius: MuiRadius.inside(MuiRadius.xl, _inset),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 56,
                              minHeight: _height - _inset * 2,
                            ),
                            child: Padding(
                              padding: const .symmetric(horizontal: 6),
                              child: Column(
                                mainAxisSize: .min,
                                mainAxisAlignment: .center,
                                spacing: 4,
                                children: [
                                  Icon(icon, size: 20, color: foreground),
                                  Text(label, style: style),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
