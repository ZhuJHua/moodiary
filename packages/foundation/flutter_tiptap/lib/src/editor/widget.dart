part of '../editor.dart';

/// Builds a selection menu from viewport anchors and available actions.
typedef TiptapContextMenuBuilder = Widget Function(
  BuildContext context,
  TiptapContextMenuDetails details,
);

/// Viewport anchors and callbacks for a custom selection menu.
class TiptapContextMenuDetails {
  const TiptapContextMenuDetails({
    required this.anchorAbove,
    required this.anchorBelow,
    required this.copy,
    required this.paste,
    required this.selectAll,
    required this.hide,
  });
  final Offset anchorAbove, anchorBelow;
  final VoidCallback? copy, paste, selectAll;
  final VoidCallback hide;
}

class _PointerHit {
  const _PointerHit(this.doc, this.position, this.task, this.reference);
  final m.Node doc;
  final int position;
  final int? task;
  final m.Node? reference;
}

/// A virtualized rich text editor with platform text input and selection.
class TiptapEditor extends StatefulWidget {
  /// Creates an editor connected to [controller].
  const TiptapEditor({
    super.key,
    required this.controller,
    this.style = const TiptapEditorStyle(),
    this.readOnly = false,
    this.keyboardEnabled = true,
    this.header,
    this.footer,
    this.codeBlockHeader,
    this.onEditingTap,
    this.onFind,
    this.onEditLink,
    this.onEscape,
    this.onBoundaryNavigation,
    this.focusNode,
    this.autofocus = false,
    this.caretBottomMargin = 24,
    this.contextMenuBuilder,
    this.placeholder = '',
    this.scrollController,
    this.codeHighlighter,
    this.nodeViews = const {},
    this.nodeHeightEstimator,
    this.onLinkTap,
    this.onReferenceTap,
    this.onPasteText,
    this.onPasteImage,
    this.onPasteClipboard,
    this.onCopyClipboard,
  });

  /// Custom widget builders keyed by document node type.
  final Map<String, TiptapNodeViewBuilder> nodeViews;

  /// Estimates custom node heights before their widgets are mounted.
  final TiptapNodeHeightEstimator? nodeHeightEstimator;

  /// Opens a tapped link URL or reference identifier.
  final ValueChanged<String>? onLinkTap, onReferenceTap;

  /// Optionally converts clipboard text to document JSON.
  final TiptapPasteText? onPasteText;

  /// Imports an image payload supplied by the platform or host.
  final FutureOr<void> Function(Object payload)? onPasteImage;

  /// Handles host clipboard formats; returns true when paste is handled.
  final Future<bool> Function()? onPasteClipboard;

  /// Writes both text and HTML to the host clipboard.
  final Future<void> Function(String text, String html)? onCopyClipboard;

  /// State and editing commands shared with the host.
  final TiptapController controller;

  /// Supplies syntax colors while preserving the code text.
  final TiptapCodeHighlighter? codeHighlighter;

  /// Typography, spacing and interaction colors for the document.
  final TiptapEditorStyle style;

  /// Controls editing, initial focus and platform keyboard attachment.
  final bool readOnly, autofocus, keyboardEnabled;

  /// Content placed before and after the document inside its scroll view.
  final Widget? header, footer;

  /// Builds a header for each visible code block.
  final TiptapNodeViewBuilder? codeBlockHeader;

  /// Host actions for an editing tap, search shortcut and link editing.
  final VoidCallback? onEditingTap, onFind, onEditLink;

  /// Handles Escape; returns true when the host consumes it.
  final bool Function()? onEscape;

  /// Handles keyboard navigation beyond a document boundary.
  final bool Function(String direction)? onBoundaryNavigation;

  /// Optional host-owned focus node; otherwise the editor owns one.
  final FocusNode? focusNode;

  /// Minimum space below the caret when revealing it in the viewport.
  final double caretBottomMargin;

  /// Builds a custom menu in place of the default selection menu.
  final TiptapContextMenuBuilder? contextMenuBuilder;

  /// Text shown when the document is empty.
  final String placeholder;

  /// Optional host-owned controller for the vertical document scroll view.
  final ScrollController? scrollController;
  @override
  TiptapEditorState createState() => TiptapEditorState();
}

/// Exposes keyboard, composition and viewport controls for an editor.
class TiptapEditorState extends State<TiptapEditor>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late FocusNode _focusNode;
  late ScrollController _scroll;
  late _TiptapTextInput _input;
  _RenderEditorViewport? _render;
  Timer? _autoScroll, _caretHandleTimer, _tapMenuTimer;
  bool _caretHandleShown = false;
  final _caret = _CaretMotion();
  bool _foreground = true, _tickerEnabled = true, _reduceMotion = false;
  bool _snapCaret = true;
  m.Node? _caretDocument;
  int _caretRevision = -1;
  final ContextMenuController _menu = ContextMenuController();
  SystemContextMenuController? _systemMenu;
  bool _systemMenuVisible = false;
  bool _dragCollapsed = false;
  // The word a long press picked; it stays selected until the finger leaves it.
  (int, int)? _pressedWord;
  bool _nodeFocused = false;
  bool _touch = false,
      _geometryPending = false,
      _reveal = false,
      _dragging = false;
  double? _goalX;
  double _lastKeyboardInset = 0;
  // A keyboard animation moves the visible area every frame, and a far jump
  // refines its estimate over a few layouts: both settle in step. Other
  // reveals glide.
  bool _revealSnaps = false;
  double? _viewportHeight;
  double? _revealTarget;
  int _lastRevealLayout = -1;
  String? _geometrySignature;
  PointerDeviceKind _pointerKind = PointerDeviceKind.touch;
  Offset? _pointerDown, _dragGlobal, _magnifier, _handleGrab;
  int? _dragAnchor;
  TextRange? _dragUnit;
  int _dragGranularity = 1;
  MouseCursor _cursor = SystemMouseCursors.text;
  _PointerHit? _pointerHit;
  final Map<int, ScrollHoldController> _scrollHolds = {};
  bool get _scrollInputBlocked =>
      _scroll.hasClients && _scroll.position.isScrollingNotifier.value;

  void _stopScrollOnDown(PointerDownEvent event) {
    // Touch drags are normally held by Scrollable before this listener runs.
    // Mouse/other presses may not be in its drag-device set: stop those here.
    if (!_scrollInputBlocked) return;
    _reveal = false;
    _scrollHolds[event.pointer] = _scroll.position.hold(
      () => _scrollHolds.remove(event.pointer),
    );
  }

  void _releaseScrollHold(PointerEvent event) =>
      _scrollHolds.remove(event.pointer)?.cancel();

  void _releaseScrollHolds() {
    final holds = _scrollHolds.values.toList();
    _scrollHolds.clear();
    for (final hold in holds) {
      hold.cancel();
    }
  }

  ScrollPositionWithSingleContext? _overflowPosition;
  Drag? _overflowDrag;
  ScrollHoldController? _overflowHold;

  void _unbindOverflow() {
    _render?._unbindHorizontal();
    _overflowPosition?.goIdle();
  }

  void _overflowDown(DragDownDetails details) {
    final render = _render, position = _overflowPosition;
    if (render == null || position == null) return;
    final index = render._horizontalRowAt(_local(details.globalPosition));
    if (index == null) return;
    final row = render._row(index), block = row.table ?? row.node;
    if (!identical(render._horizontalBlock, block)) {
      _unbindOverflow();
      position.correctPixels(render._horizontalOffset(index));
      render._horizontalBlock = block;
      render._horizontalBlockPosition = row.table == null
          ? row.position
          : row.position - row.tableRowPosition - 1;
      render._horizontalPosition = position;
    }
    render._applyHorizontalDimensions();
    _overflowHold = position.hold(() => _overflowHold = null);
  }

  void _overflowStart(DragStartDetails details) {
    if (_render?._horizontalBlock == null) return;
    _overflowDrag = _overflowPosition!.drag(
      details,
      () => _overflowDrag = null,
    );
  }

  void _overflowCancel() {
    _overflowHold?.cancel();
    _overflowDrag?.cancel();
  }

  void _overflowScrolled() {
    final render = _render, block = render?._horizontalBlock;
    if (render == null || block == null) return;
    render._setHorizontalOffset(block, _overflowPosition!.pixels);
  }

  int _tapCount = 0;
  Duration _lastTap = Duration.zero;
  Offset _lastTapPosition = Offset.zero;

  /// Viewport geometry once the editor has completed layout.
  TiptapGeometry? get geometry => _render?.hasSize == true ? _render : null;

  /// The active vertical document scroll controller.
  ScrollController get scrollController => _scroll;
  @visibleForTesting
  ({Rect bounds, double baseline, double textBaseline, String kind})?
  debugListMarker(int position) {
    final render = _render;
    if (render == null || !render.hasSize) return null;
    final marker = render._markerLayout(render._indexForPosition(position));
    return marker == null
        ? null
        : (
            bounds: marker.bounds,
            baseline: marker.baseline,
            textBaseline: marker.textBaseline,
            kind: marker.kind,
          );
  }

  @visibleForTesting
  ({Rect rect, double baseline, double ascent, double descent})?
  get debugCaretMetrics {
    final value = _render?._lastCaretGeometry;
    return value == null
        ? null
        : (
            rect: value.rect,
            baseline: value.baseline,
            ascent: value.ascent,
            descent: value.descent,
          );
  }

  @visibleForTesting
  int get debugDocumentPaints => _render?._paintCount ?? 0;

  @visibleForTesting
  TextEditingValue get debugInputValue => _input.currentTextEditingValue;
  @visibleForTesting
  void debugApplyDeltas(List<TextEditingDelta> deltas) =>
      _input.updateEditingValueWithDeltas(deltas);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _focusNode = widget.focusNode ?? FocusNode();
    _scroll = widget.scrollController ?? ScrollController();
    _input = _TiptapTextInput(this)..synchronize();
    _focusNode.addListener(_focusChanged);
    _scroll.addListener(_scrolled);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TiptapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyboardEnabled != widget.keyboardEnabled) {
      if (widget.keyboardEnabled) {
        _input.open();
      } else {
        _input.close();
      }
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _snapCaret = true;
      _input.close(commit: false);
      _input = _TiptapTextInput(this)..synchronize();
    }
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      _focusNode.removeListener(_focusChanged);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_focusChanged);
    }
    if (!identical(oldWidget.scrollController, widget.scrollController)) {
      _releaseScrollHolds();
      _scroll.removeListener(_scrolled);
      if (oldWidget.scrollController == null) _scroll.dispose();
      _scroll = widget.scrollController ?? ScrollController();
      _scroll.addListener(_scrolled);
    }
    if (widget.caretBottomMargin != oldWidget.caretBottomMargin &&
        _focusNode.hasPrimaryFocus) {
      _scheduleGeometry(reveal: true);
    }
    if (widget.readOnly != oldWidget.readOnly) {
      // Selection listeners include ancestors that are building right now.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dropRange();
      });
    }
    if (widget.readOnly != oldWidget.readOnly ||
        !identical(oldWidget.focusNode, widget.focusNode)) {
      _focusChanged();
    } else if (_focusNode.hasPrimaryFocus &&
        !_input.attached &&
        !widget.readOnly) {
      _input.open();
    }
    _scheduleGeometry(
      reveal: !identical(oldWidget.controller, widget.controller),
    );
  }

  @override
  void dispose() {
    _unbindOverflow();
    _overflowPosition?.dispose();
    _releaseScrollHolds();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    _focusNode.removeListener(_focusChanged);
    _scroll.removeListener(_scrolled);
    _caret.dispose();
    _autoScroll?.cancel();
    _caretHandleTimer?.cancel();
    _tapMenuTimer?.cancel();
    _hideContextMenu();
    _systemMenu?.dispose();
    _input.close(commit: false);
    if (widget.focusNode == null) _focusNode.dispose();
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final inset = View.of(context).viewInsets.bottom;
    final changed = inset != _lastKeyboardInset;
    _lastKeyboardInset = inset;
    if (changed && _focusNode.hasPrimaryFocus) _revealSnaps = true;
    _scheduleGeometry(reveal: changed && _focusNode.hasPrimaryFocus);
  }

  @visibleForTesting
  List<Rect> get debugCellSelectionRects =>
      _render?._cellSelectionRects() ?? [];
  @visibleForTesting
  List<Rect> get debugSearchHighlightRects => _render?._searchRects() ?? [];

  /// Commits any active IME composition before a host editing action.
  void finishComposition() => _input.finishComposition();

  /// Focuses the editor and attaches its platform text input connection.
  void requestKeyboard() {
    _focusNode.requestFocus();
    if (_focusNode.hasPrimaryFocus) _input.open();
  }

  // A range and its menu belong to the mode they were picked in.
  void _dropRange() {
    _hideContextMenu();
    _hideCaretHandle();
    final selection = widget.controller.state.selection;
    if (selection is m.TextSelection && !selection.empty) {
      widget.controller.setSelection(m.TextSelection(selection.head));
    } else if (selection is m.NodeSelection) {
      widget.controller.setSelection(
        m.Selection.beside(widget.controller.state.doc, selection.to),
      );
    } else if (selection is m.CellSelection) {
      widget.controller.setSelection(
        m.Selection.near(widget.controller.state.doc, selection.head),
      );
    }
  }

  void _showCaretHandle() {
    _caretHandleTimer?.cancel();
    _caretHandleTimer = Timer(const Duration(seconds: 2), _hideCaretHandle);
    if (!_caretHandleShown && mounted) setState(() => _caretHandleShown = true);
  }

  void _hideCaretHandle() {
    _caretHandleTimer?.cancel();
    _caretHandleTimer = null;
    if (_caretHandleShown && mounted) {
      setState(() => _caretHandleShown = false);
    }
  }

  void _focusChanged() {
    _snapCaret = true;
    if (!_focusNode.hasPrimaryFocus) _hideCaretHandle();
    if (_focusNode.hasPrimaryFocus &&
        (widget.controller.state.selection is m.NodeSelection ||
            widget.controller.state.selection is m.CellSelection)) {
      _nodeFocused = true;
    }
    if (_focusNode.hasPrimaryFocus &&
        !widget.readOnly &&
        widget.controller.state.selection is! m.NodeSelection) {
      _input.open();
    } else {
      _input.close();
      _hideContextMenu();
    }
    _resetBlink();
    if (mounted) setState(() {});
    _scheduleGeometry(
      reveal:
          _focusNode.hasPrimaryFocus &&
          widget.controller.state.selection is! m.NodeSelection,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final physics = ScrollConfiguration.of(context).getScrollPhysics(context);
    if (_overflowPosition == null ||
        _overflowPosition!.physics.toString() != physics.toString()) {
      _unbindOverflow();
      _overflowPosition?.dispose();
      _overflowPosition = ScrollPositionWithSingleContext(
        physics: physics,
        context: _OverflowScrollContext(this),
        keepScrollOffset: false,
      )..addListener(_overflowScrolled);
    }
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _resetBlink();
    _scheduleGeometry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _snapCaret = true;
    _resetBlink();
    _scheduleGeometry();
  }

  void _resetBlink() {
    final selection = widget.controller.state.selection;
    _caret.enable(
      _foreground &&
          _tickerEnabled &&
          _focusNode.hasPrimaryFocus &&
          !widget.readOnly &&
          selection is m.TextSelection &&
          selection.empty,
      reduced: _reduceMotion,
    );
    _caret.activity();
  }

  void _updateCaret(_RenderEditorViewport render) {
    final controller = widget.controller;
    final swapped =
        controller.lastTransaction == null &&
        !identical(_caretDocument, controller.state.doc);
    final edited =
        controller.lastTransaction?.metadata['history'] != true &&
        controller.revision != _caretRevision &&
        !identical(_caretDocument, controller.state.doc);
    _caretDocument = controller.state.doc;
    _caretRevision = controller.revision;
    final rect = render._visualCaretRect(controller.state.selection.head);
    _caret.move(
      rect,
      render.size,
      snap:
          _snapCaret ||
          swapped ||
          edited ||
          _dragging ||
          controller.composing.isValid ||
          !widget.style.animateCaretMovement ||
          _reduceMotion,
    );
    _snapCaret = false;
  }

  @visibleForTesting
  ({Rect? rect, double opacity, bool timer}) get debugCaret =>
      (rect: _caret.rect, opacity: _caret.opacity, timer: _caret.running);

  void _changed() {
    if (widget.controller.lastTransaction == null) _input.cancelComposition();
    if (widget.controller.lastTransaction?.docChanged == true && !_dragging) {
      _hideCaretHandle();
      _hideContextMenu();
    }
    _resetBlink();
    if (widget.controller.state.selection is! m.NodeSelection && _nodeFocused) {
      _nodeFocused = false;
      if (_focusNode.hasPrimaryFocus && !widget.readOnly) _input.open();
    }
    _input.synchronize();
    if ((widget.controller.state.selection is m.NodeSelection ||
        widget.controller.state.selection is m.CellSelection)) {
      _reveal = false;
    }
    _scheduleGeometry(
      reveal:
          !_dragging && widget.controller.state.selection is! m.NodeSelection,
    );
    if (mounted) setState(() {});
  }

  void _scrolled() {
    _snapCaret = true;
    _tapCount = 0;
    _hideContextMenu();
    _scheduleGeometry();
  }

  void _scheduleGeometry({bool reveal = false}) {
    if (!mounted) return;
    if (reveal && !_reveal) _lastRevealLayout = -1;
    _reveal |= reveal;
    if (_geometryPending) return;
    _geometryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryPending = false;
      _geometryChanged();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Passes an image payload to the configured host import callback.
  Future<void> pasteImage(Object payload) =>
      widget.controller.pasteImage(payload, widget.onPasteImage);

  void _geometryChanged() {
    final render = _render;
    if (!mounted || render == null || !render.attached || !render.hasSize) {
      return;
    }
    // A panel opened under a hardware keyboard shrinks the viewport without a
    // metrics change; keep the caret in what is left.
    final height = render.size.height;
    if (_viewportHeight case final previous?
        when height < previous - .5 && _focusNode.hasPrimaryFocus) {
      _scheduleGeometry(reveal: true);
    }
    _viewportHeight = height;
    if ((widget.controller.state.selection is m.NodeSelection ||
        widget.controller.state.selection is m.CellSelection ||
        widget.controller.state.selection is m.AllSelection)) {
      _reveal = false;
    }
    if (_reveal && !_dragging && _lastRevealLayout != render.layoutGeneration) {
      _lastRevealLayout = render.layoutGeneration;
      _reveal = _revealCaret();
      if (!_reveal) _revealSnaps = false;
    }
    _updateCaret(render);
    _input.updateGeometry();
    widget.controller._updateHostGeometry(render);
    final signature =
        '${widget.controller.revision}:${render.size}:${render.scrollOffset}:${_focusNode.hasPrimaryFocus}:${widget.controller.composing}';
    if (_geometrySignature != signature) {
      _geometrySignature = signature;
      setState(() {});
    }
  }

  // The caret ring and the end handle hang below the line; keep them in view.
  double get _bottomReserve => math.max(widget.caretBottomMargin, _handleReach);

  bool _revealCaret() {
    if ((widget.controller.state.selection is m.NodeSelection ||
        widget.controller.state.selection is m.CellSelection)) {
      return false;
    }
    final render = _render;
    if (render == null ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions) {
      return false;
    }
    // The spring owns an out-of-range position. Clamping a reveal target here
    // would snap the document between pointer down and selection/IME geometry.
    final position = _scroll.position;
    if (position.outOfRange ||
        render.scrollOffset < position.minScrollExtent ||
        render.scrollOffset > position.maxScrollExtent) {
      return true;
    }
    if ((position.pixels - render.scrollOffset).abs() > .01) return true;
    render._revealHorizontal(widget.controller.state.selection.head);
    final caret = render.caretRect(widget.controller.state.selection.head);
    final view = View.of(context);
    final available =
        view.physicalSize.height / view.devicePixelRatio -
        MediaQuery.viewInsetsOf(context).bottom -
        render.localToGlobal(Offset.zero).dy;
    final height = math.min(render.size.height, math.max(0, available));
    var delta = 0.0;
    if (caret.bottom > height - _bottomReserve) {
      delta = caret.bottom - height + _bottomReserve;
    }
    if (caret.top < widget.style.padding.top) {
      delta = caret.top - widget.style.padding.top;
    }
    if (delta.abs() > .5) {
      final target = (render.scrollOffset + delta).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (_revealTarget case final gliding?
          when (gliding - target).abs() <= .5) {
        return false;
      }
      if ((target - _scroll.offset).abs() > .5) {
        if (_revealSnaps ||
            _reduceMotion ||
            (target - _scroll.offset).abs() > render.size.height) {
          _revealSnaps = true;
          _revealTarget = null;
          _scroll.jumpTo(target);
        } else {
          _revealTarget = target;
          unawaited(
            _scroll
                .animateTo(
                  target,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                )
                .whenComplete(() {
                  if (_revealTarget == target) _revealTarget = null;
                }),
          );
        }
        return true;
      }
    }
    return false;
  }

  Offset _local(Offset global) => _render?.globalToLocal(global) ?? global;
  void _selectPosition(int position, {bool extend = false}) {
    _input.finishComposition();
    _goalX = null;
    final controller = widget.controller, doc = controller.state.doc;
    controller.setSelection(
      extend
          ? m.TextSelection(controller.state.selection.anchor, position)
          : m.Selection.near(doc, position),
    );
  }

  void _place(
    Offset global, {
    bool word = false,
    bool block = false,
    bool extend = false,
    bool activateControls = true,
    _PointerHit? hit,
  }) {
    final geometry = this.geometry;
    if (geometry == null ||
        _render?.attached != true ||
        _render?._inChrome(_local(global)) == true) {
      return;
    }
    if (!widget.readOnly) widget.onEditingTap?.call();
    final task = hit != null ? hit.task : _render?._taskAt(_local(global));
    if (activateControls && task != null && !word && !block && !extend) {
      _toggleTask(task);
      return;
    }
    final position =
        hit?.position ?? geometry.positionForOffset(_local(global));
    final doc = widget.controller.state.doc;
    final row = doc.rowAt(doc.rowIndexAt(position));
    if (activateControls && !word && !block && !extend) {
      final chip = hit != null
          ? hit.reference
          : _render?._referenceAt(_local(global));
      final keyboard = HardwareKeyboard.instance;
      final open =
          widget.readOnly ||
          keyboard.isMetaPressed ||
          keyboard.isControlPressed;
      if (chip != null && open) {
        widget.onReferenceTap?.call((chip.attrs['id'] ?? '').toString());
      }
      if (open) {
        final link = m.linkAt(doc, position);
        if (link != null) widget.onLinkTap?.call(link.href);
      }
    }
    final atom = doc.nodeAt(position);
    if (atom?.type == 'horizontalRule' && !extend) {
      if (widget.readOnly) return;
      _input.finishComposition();
      final rect = geometry.rowRect(position);
      final before = _local(global).dy < rect.center.dy;
      widget.controller.setSelection(
        m.Selection.beside(
          doc,
          before ? position : position + atom!.nodeSize,
          bias: before ? -1 : 1,
        ),
      );
      requestKeyboard();
      _hideContextMenu();
      return;
    }
    if (!extend && !row.node.isTextblock && row.node.type != 'tableRow') {
      if (widget.readOnly) return;
      _input.finishComposition();
      widget.controller.setSelection(m.NodeSelection(doc, row.position));
      _input.close(commit: false);
      _nodeFocused = true;
      if (!widget.readOnly) _focusNode.requestFocus();
      _hideContextMenu();
      return;
    }
    _input.finishComposition();
    _goalX = null;
    if (word || block) {
      final doc = widget.controller.state.doc;
      final row = doc.rowAt(doc.rowIndexAt(position)), node = row.node;
      if (!node.isTextblock && node.type != 'tableRow') {
        widget.controller.setSelection(m.NodeSelection(doc, row.position));
      } else {
        final chip = _render?._referenceAt(_local(global));
        final resolved = doc.resolve(position);
        final chipPosition = resolved.nodeAfter == chip
            ? position
            : position - 1;
        final range = word
            ? chip != null
                  ? TextRange(start: chipPosition, end: chipPosition + 1)
                  : geometry.wordBoundary(position)
            : TextRange(
                start: node.type == 'tableRow'
                    ? doc.resolve(position).start()
                    : row.position + 1,
                end: node.type == 'tableRow'
                    ? doc.resolve(position).end()
                    : row.position + node.nodeSize - 1,
              );
        widget.controller.setSelection(m.TextSelection(range.start, range.end));
      }
    } else {
      _selectPosition(position, extend: extend);
    }
    requestKeyboard();
    _hideContextMenu();
  }

  void _toggleTask(int position) {
    if (widget.readOnly) return;
    _input.finishComposition();
    final state = widget.controller.state,
        node = widget.controller.state.doc.nodeAt(position);
    if (node?.type != 'taskItem') return;
    widget.controller.apply(
      state.tr.step(
        m.AttrStep(position, 'checked', node!.attrs['checked'] != true),
      ),
    );
  }

  void _pointerStarted(PointerDownEvent event) {
    if (_render?._inChrome(_local(event.position)) == true) {
      _pointerDown = null;
      _pointerHit = null;
      return;
    }
    _tapMenuTimer?.cancel();
    _pointerKind = event.kind;
    _pointerDown = event.position;
    _reveal = false;
    final render = _render;
    _pointerHit = render != null && render.hasSize
        ? _PointerHit(
            widget.controller.state.doc,
            render.positionForOffset(_local(event.position)),
            render._taskAt(_local(event.position)),
            render._referenceAt(_local(event.position)),
          )
        : null;
    _touch =
        event.kind != PointerDeviceKind.mouse &&
        event.kind != PointerDeviceKind.trackpad;
    if (event.buttons & kSecondaryMouseButton != 0) {
      final selection = widget.controller.state.selection;
      final position = _pointerHit?.position;
      if (selection.empty ||
          position != null &&
              (position < selection.from || position > selection.to)) {
        _place(event.position, activateControls: false);
      }
      _showContextMenu();
      return;
    }
    if (event.timeStamp - _lastTap < const Duration(milliseconds: 400) &&
        (event.position - _lastTapPosition).distance < 12) {
      _tapCount = _tapCount % 3 + 1;
    } else {
      _tapCount = 1;
    }
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed) {
      _tapCount = 1;
    }
    _lastTap = event.timeStamp;
    _lastTapPosition = event.position;
    if (_touch || event.buttons & kPrimaryMouseButton == 0) return;
    _place(
      event.position,
      word: _tapCount == 2,
      block: _tapCount == 3,
      extend: HardwareKeyboard.instance.isShiftPressed,
    );
    _dragAnchor = widget.controller.state.selection.anchor;
    _dragGranularity = HardwareKeyboard.instance.isShiftPressed ? 1 : _tapCount;
    final selection = widget.controller.state.selection;
    _dragUnit = TextRange(start: selection.from, end: selection.to);
  }

  void _pointerMoved(PointerMoveEvent event) {
    if (_touch ||
        event.buttons & kPrimaryMouseButton == 0 ||
        _dragAnchor == null ||
        _pointerDown == null) {
      return;
    }
    if (!_dragging && (event.position - _pointerDown!).distance < 3) return;
    _dragging = true;
    _updateDrag(event.position);
  }

  void _pointerEnded(PointerEvent event) {
    if (event is PointerCancelEvent) _pointerHit = null;
    if (!_touch) _endDrag(showMenu: false);
  }

  void _updateDrag(Offset global) {
    if (geometry == null || _dragAnchor == null) return;
    _dragGlobal = global;
    final position = geometry!.positionForOffset(
      _local(global - (_handleGrab ?? Offset.zero)),
    );
    final doc = widget.controller.state.doc,
        anchorCell = m.tableContext(doc, _dragAnchor!),
        headCell = m.tableContext(doc, position);
    if (!_dragCollapsed &&
        anchorCell != null &&
        headCell != null &&
        anchorCell.tablePosition == headCell.tablePosition &&
        anchorCell.cellPosition != headCell.cellPosition) {
      widget.controller.setSelection(
        m.CellSelection(doc, anchorCell.cellPosition, headCell.cellPosition),
      );
    } else {
      var anchor = _dragAnchor!, head = position;
      final unit = _dragUnit;
      if (!_touch && unit != null && _dragGranularity > 1) {
        final resolved = doc.resolve(position);
        final range = _dragGranularity == 2
            ? geometry!.wordBoundary(position)
            : TextRange(start: resolved.start(), end: resolved.end());
        final backward = position < unit.start;
        anchor = backward ? unit.end : unit.start;
        head = backward ? range.start : range.end;
      }
      widget.controller.setSelection(
        _dragCollapsed
            ? m.TextSelection(position)
            : m.TextSelection(anchor, head),
      );
    }
    if (_touch) {
      setState(
        () => _magnifier = _local(global - (_handleGrab ?? Offset.zero)),
      );
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          !_dragging ||
          _dragGlobal == null ||
          !_scroll.hasClients ||
          geometry == null) {
        return;
      }
      final point = _local(_dragGlobal!),
          height = geometry!.viewportSize.height;
      final speed = point.dy < 40
          ? -math.min(20.0, (40 - point.dy) / 3)
          : point.dy > height - 40
          ? math.min(20.0, (point.dy - height + 40) / 3)
          : 0.0;
      if (speed == 0) return;
      final next = (_scroll.offset + speed).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (next != _scroll.offset) {
        _scroll.jumpTo(next);
        _updateDrag(_dragGlobal!);
      }
    });
  }

  void _endDrag({required bool showMenu}) {
    _dragging = false;
    _dragCollapsed = false;
    _pressedWord = null;
    _dragAnchor = null;
    _dragUnit = null;
    _dragGranularity = 1;
    _dragGlobal = null;
    _handleGrab = null;
    _autoScroll?.cancel();
    _autoScroll = null;
    if (mounted) setState(() => _magnifier = null);
    if (showMenu) _showContextMenu();
  }

  void _longPress(LongPressStartDetails details) {
    _touch = true;
    final appleCaret =
        !widget.readOnly &&
        _focusNode.hasPrimaryFocus &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    _place(details.globalPosition, word: !appleCaret, activateControls: false);
    _dragCollapsed = appleCaret;
    if ((widget.controller.state.selection is m.NodeSelection ||
        widget.controller.state.selection is m.CellSelection)) {
      return;
    }
    _dragging = true;
    final selection = widget.controller.state.selection;
    _dragAnchor = selection.anchor;
    _pressedWord = appleCaret ? null : (selection.from, selection.to);
    setState(() => _magnifier = _local(details.globalPosition));
  }

  void _longPressMoved(Offset global) {
    final word = _pressedWord;
    if (word != null && geometry != null) {
      final (from, to) = word;
      final position = geometry!.positionForOffset(_local(global));
      if (position >= from && position <= to) {
        widget.controller.setSelection(m.TextSelection(from, to));
        setState(() => _magnifier = _local(global));
        return;
      }
      _dragAnchor = position > to ? from : to;
    }
    _updateDrag(global);
  }

  Widget _handle(int position, {required bool start, required bool collapsed}) {
    final render = _render!;
    final kind = collapsed
        ? _HandleKind.caret
        : start
        ? _HandleKind.start
        : _HandleKind.end;
    final shown = !collapsed || _caretHandleShown || _dragging;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _HandleLayout(render, position, kind, _scroll),
        child: IgnorePointer(
          ignoring: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: _handleGestures(render, position, kind),
          ),
        ),
      ),
    );
  }

  Widget _handleGestures(
    _RenderEditorViewport render,
    int position,
    _HandleKind kind,
  ) {
    final collapsed = kind == _HandleKind.caret,
        start = kind == _HandleKind.start;
    void begin(DragStartDetails details) {
      _touch = true;
      _dragging = true;
      _dragCollapsed = collapsed;
      _hideContextMenu();
      _input.finishComposition();
      _dragAnchor = collapsed
          ? position
          : start
          ? widget.controller.state.selection.to
          : widget.controller.state.selection.from;
      _handleGrab =
          details.globalPosition -
          render.localToGlobal(render.caretRect(position).centerLeft);
      setState(() => _magnifier = _local(details.globalPosition));
    }

    // The handles live inside the Scrollable and the long-press detector, whose
    // drags pass their slop first; claim the pointer on down instead.
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _HandleDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_HandleDragRecognizer>(
              _HandleDragRecognizer.new,
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = begin
                ..onUpdate = ((details) => _updateDrag(details.globalPosition))
                ..onEnd = (_) {
                  _endDrag(showMenu: true);
                  if (collapsed) _showCaretHandle();
                }
                ..onCancel = () {
                  _endDrag(showMenu: false);
                  if (collapsed) _showCaretHandle();
                },
            ),
      },
      child: CustomPaint(
        key: ValueKey(
          'tiptap-handle-${collapsed
              ? 'caret'
              : start
              ? 'start'
              : 'end'}',
        ),
        painter: _HandlePainter(
          widget.style.handleColor,
          kind,
          render.caretRect(position).height,
        ),
      ),
    );
  }

  List<(String, VoidCallback)> _menuActions(WidgetsLocalizations strings) => [
    if (!widget.controller.state.selection.empty)
      (strings.copyButtonLabel, () => unawaited(_copyFromMenu())),
    if (!widget.readOnly) (strings.pasteButtonLabel, () => unawaited(_paste())),
    if (!_selectsAll) (strings.selectAllButtonLabel, _selectAllFromMenu),
  ];

  // As in Flutter's text fields, a menu copy ends the selection on Android
  // and keeps it elsewhere.
  Future<void> _copyFromMenu() async {
    final controller = widget.controller;
    final selection = controller.state.selection;
    await _copy();
    if (!mounted ||
        defaultTargetPlatform != TargetPlatform.android ||
        controller.state.selection != selection) {
      return;
    }
    controller.setSelection(
      m.Selection.near(controller.state.doc, selection.to, bias: -1),
    );
  }

  bool get _selectsAll {
    final m.EditorState(:doc, :selection) = widget.controller.state;
    return selection is m.AllSelection ||
        selection.from <= m.Selection.near(doc, 0).from &&
            selection.to >=
                m.Selection.near(doc, doc.content.size, bias: -1).to;
  }

  /// Runs the paste action, as the keyboard shortcut does.
  void paste() => _perform('paste', const {});

  void _selectAllFromMenu() {
    widget.controller.exec('selectAll');
    _showContextMenu();
  }

  void _showContextMenu() {
    final render = _render;
    if (!mounted || render == null || !render.hasSize) return;
    final selection = widget.controller.state.selection;
    final viewport = Offset.zero & render.size;
    final rects = selection.empty
        ? <Rect>[]
        : render
              .selectionRects(selection.from, selection.to)
              .where((rect) => rect.overlaps(viewport))
              .map((rect) => rect.intersect(viewport))
              .toList();
    final first = rects.isEmpty
        ? render._caretForInput(selection.from).intersect(viewport)
        : rects.first;
    final last = rects.isEmpty ? first : rects.last;
    final above = render.localToGlobal(first.topCenter),
        below = render.localToGlobal(last.bottomCenter);
    final strings = WidgetsLocalizations.of(context);
    final actions = _menuActions(strings);
    if (SystemContextMenu.isSupported(context) &&
        _input.attached &&
        !widget.readOnly) {
      _menu.remove();
      _systemMenu ??= SystemContextMenuController(
        onSystemHide: () => _systemMenuVisible = false,
      );
      _systemMenuVisible = true;
      unawaited(
        _systemMenu!.showWithItems(Rect.fromPoints(above, below), [
          for (final (label, callback) in actions)
            if (label == strings.pasteButtonLabel)
              const IOSSystemContextMenuItemDataPaste()
            else
              IOSSystemContextMenuItemDataCustom(
                title: label,
                onPressed: callback,
              ),
        ]),
      );
      return;
    }
    final details = TiptapContextMenuDetails(
      anchorAbove: above,
      anchorBelow: below,
      copy: selection.empty ? null : () => unawaited(_copyFromMenu()),
      paste: widget.readOnly ? null : () => unawaited(_paste()),
      selectAll: _selectsAll ? null : _selectAllFromMenu,
      hide: _hideContextMenu,
    );
    _menu.show(
      context: context,
      contextMenuBuilder: (context) =>
          widget.contextMenuBuilder?.call(context, details) ??
          CupertinoTextSelectionToolbar(
            anchorAbove: above,
            anchorBelow: below,
            children: [
              for (final (label, callback) in actions)
                CupertinoTextSelectionToolbarButton(
                  onPressed: callback,
                  child: Text(label),
                ),
            ],
          ),
    );
  }

  void _hideContextMenu() {
    _menu.remove();
    if (_systemMenuVisible) {
      _systemMenuVisible = false;
      unawaited(_systemMenu!.hide());
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.controller.state.selection;
    return Shortcuts(
      shortcuts: _editorShortcuts(),
      child: Actions(
        actions: {_EditorIntent: _EditorAction(this)},
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _routeTextInputKey,
          child: MouseRegion(
            cursor: _cursor,
            onHover: (event) {
              final point = _local(event.position), render = _render;
              if (render == null || !render.hasSize) return;
              final position = render.positionForOffset(point);
              final actionable =
                  render._inChrome(point) ||
                  !widget.readOnly && render._taskAt(point) != null ||
                  widget.readOnly &&
                      (render._referenceAt(point) != null ||
                          m.linkAt(widget.controller.state.doc, position) !=
                              null) ||
                  const {'image', 'video', 'audio', 'attachment'}.contains(
                    widget.controller.state.doc.nodeAt(position)?.type,
                  );
              final cursor = actionable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.text;
              if (cursor != _cursor) setState(() => _cursor = cursor);
            },
            child: Listener(
              onPointerDown: _stopScrollOnDown,
              onPointerUp: _releaseScrollHold,
              onPointerCancel: _releaseScrollHold,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent &&
                    (event.scrollDelta.dx != 0 ||
                        HardwareKeyboard.instance.isShiftPressed &&
                            event.scrollDelta.dy != 0) &&
                    _render?._horizontalRowAt(_local(event.position)) != null) {
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (_) => _render?._scrollCode(
                      _local(event.position),
                      event.scrollDelta.dx != 0
                          ? event.scrollDelta.dx
                          : event.scrollDelta.dy,
                    ),
                  );
                }
              },
              child: Scrollable(
                controller: _scroll,
                viewportBuilder: (context, offset) => _IgnoreScrollInput(
                  blocked: () => _scrollInputBlocked,
                  child: Listener(
                    onPointerDown: _pointerStarted,
                    onPointerMove: _pointerMoved,
                    onPointerUp: _pointerEnded,
                    onPointerCancel: _pointerEnded,
                    child: RawGestureDetector(
                      gestures: {
                        _OverflowDragRecognizer:
                            GestureRecognizerFactoryWithHandlers<
                              _OverflowDragRecognizer
                            >(() => _OverflowDragRecognizer(), (recognizer) {
                              recognizer.canStart = (point) =>
                                  !_scrollInputBlocked &&
                                  _render?._horizontalRowAt(_local(point)) !=
                                      null;
                              recognizer
                                ..gestureSettings =
                                    MediaQuery.maybeGestureSettingsOf(context)
                                ..dragStartBehavior = DragStartBehavior.start
                                ..minFlingDistance =
                                    _overflowPosition?.physics.minFlingDistance
                                ..minFlingVelocity =
                                    _overflowPosition?.physics.minFlingVelocity
                                ..maxFlingVelocity =
                                    _overflowPosition?.physics.maxFlingVelocity
                                ..supportedDevices = ScrollConfiguration.of(
                                  context,
                                ).dragDevices
                                ..velocityTrackerBuilder =
                                    ScrollConfiguration.of(context)
                                        .velocityTrackerBuilder(context)
                                ..onDown = _overflowDown
                                ..onStart = _overflowStart
                                ..onUpdate = (details) {
                                  _overflowDrag?.update(details);
                                }
                                ..onEnd = (details) {
                                  _overflowDrag?.end(details);
                                }
                                ..onCancel = _overflowCancel;
                            }),
                      },
                      child: GestureDetector(
                        supportedDevices: const {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.stylus,
                          PointerDeviceKind.invertedStylus,
                          PointerDeviceKind.trackpad,
                        },
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          if (_pointerKind != PointerDeviceKind.mouse) {
                            _touch = true;
                            final hit = _pointerHit;
                            _place(
                              details.globalPosition,
                              word: _tapCount == 2,
                              block: _tapCount == 3,
                              hit:
                                  hit != null &&
                                      identical(
                                        hit.doc,
                                        widget.controller.state.doc,
                                      )
                                  ? hit
                                  : null,
                            );
                            _pointerHit = null;
                            if (_tapCount == 2) {
                              _tapMenuTimer = Timer(
                                const Duration(milliseconds: 400),
                                () {
                                  if (mounted) _showContextMenu();
                                },
                              );
                            } else if (_tapCount == 3) {
                              _showContextMenu();
                            }
                            if (widget.controller.state.selection
                                case m.TextSelection(empty: true)) {
                              _showCaretHandle();
                            }
                          }
                        },
                        onTapCancel: () => _pointerHit = null,
                        onLongPressStart: _longPress,
                        onLongPressMoveUpdate: (details) =>
                            _longPressMoved(details.globalPosition),
                        onLongPressEnd: (_) => _endDrag(showMenu: true),
                        onLongPressCancel: () => _endDrag(showMenu: false),
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.hardEdge,
                          children: [
                            RepaintBoundary(
                              child: _EditorViewport(
                                controller: widget.controller,
                                header: widget.header,
                                footer: widget.footer,
                                codeBlockHeader: widget.codeBlockHeader,
                                offset: offset,
                                style: widget.style,
                                codeHighlighter: widget.codeHighlighter,
                                nodeViews: widget.nodeViews,
                                nodeHeightEstimator: widget.nodeHeightEstimator,
                                readOnly: widget.readOnly,
                                onTaskToggle: _toggleTask,
                                placeholder: widget.placeholder,
                                bottomMargin: _bottomReserve,
                                onReady: (render) => _render = render,
                                onGeometry: _geometryChanged,
                              ),
                            ),
                            IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _CaretPainter(
                                    _caret,
                                    widget.style,
                                    MediaQuery.devicePixelRatioOf(context),
                                  ),
                                ),
                              ),
                            ),
                            if (_touch &&
                                selection is! m.NodeSelection &&
                                selection is! m.CellSelection &&
                                selection is! m.GapSelection &&
                                _focusNode.hasPrimaryFocus &&
                                geometry != null &&
                                !(widget.readOnly && selection.empty)) ...[
                              _handle(
                                selection.from,
                                start: true,
                                collapsed: selection.empty,
                              ),
                              if (!selection.empty)
                                _handle(
                                  selection.to,
                                  start: false,
                                  collapsed: false,
                                ),
                            ],
                            _Magnifier(
                              point: _magnifier,
                              maxWidth: geometry?.viewportSize.width,
                              style: widget.style,
                            ),
                          ],
                        ),
                      ),
                    ),
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

enum _HandleKind { caret, start, end }

const double _ringRadius = 5, _ringGap = 3, _knobRadius = 6;
// How far the caret ring (stroke included) hangs below the line.
const double _handleReach = _ringGap + _ringRadius * 2 + 1;
// The ring's touch box hangs below the line so taps on the text still land.
const Offset _ringCenter = Offset(22, _ringGap + _ringRadius);

// Every handle is a 44 px touch box; range handles centre theirs on the knob.
class _HandleLayout extends SingleChildLayoutDelegate {
  _HandleLayout(
    this.viewport,
    this.position,
    this.kind,
    ScrollController scroll,
  ) : super(relayout: scroll);
  final _RenderEditorViewport viewport;
  final int position;
  final _HandleKind kind;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints.tightFor(width: 44, height: 44);
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // This layout can precede viewport layout in a scroll frame. Project the
    // document caret with that frame's unrestricted raw offset, not a previous
    // widget build's scroll position (and never a clamped in-range offset).
    final shift = Offset(0, viewport.scrollOffset - viewport._offset.pixels);
    final rect =
        (kind == _HandleKind.caret
                ? viewport._visualCaretRect(position)
                : viewport.caretRect(position))
            .shift(shift);
    return switch (kind) {
      _HandleKind.caret => Offset(rect.center.dx - 22, rect.bottom),
      _HandleKind.start => Offset(
        rect.center.dx - 22,
        rect.top - _knobRadius - 22,
      ),
      _HandleKind.end => Offset(
        rect.center.dx - 22,
        rect.bottom + _knobRadius - 22,
      ),
    };
  }

  @override
  // Styling and document layout can change while the selection offsets stay
  // fixed, so a rebuilt handle must refresh its geometry too.
  bool shouldRelayout(_HandleLayout old) => true;
}

class _OverflowScrollContext implements ScrollContext {
  _OverflowScrollContext(this.state);
  final TiptapEditorState state;

  @override
  BuildContext get notificationContext => state.context;
  @override
  BuildContext get storageContext => state.context;
  @override
  TickerProvider get vsync => state;
  @override
  AxisDirection get axisDirection => AxisDirection.right;
  @override
  double get devicePixelRatio => MediaQuery.devicePixelRatioOf(state.context);
  @override
  void setIgnorePointer(bool value) {}
  @override
  void setCanDrag(bool value) {}
  @override
  void setSemanticsActions(Set<ui.SemanticsAction> actions) {}
  @override
  void saveOffset(double offset) {}
}

class _OverflowDragRecognizer extends HorizontalDragGestureRecognizer {
  bool Function(Offset point)? canStart;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.kind != PointerDeviceKind.mouse &&
      (canStart?.call(event.position) ?? false) &&
      super.isPointerAllowed(event);
}

class _HandleDragRecognizer extends PanGestureRecognizer {
  _HandleDragRecognizer()
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
        },
      );

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}

class _HandlePainter extends CustomPainter {
  const _HandlePainter(this.color, this.kind, this.stem);
  final Color color;
  final _HandleKind kind;
  // Line height the range handle's stem spans; it paints past the touch box.
  final double stem;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const center = Offset(22, 22);
    switch (kind) {
      case _HandleKind.caret:
        canvas.drawCircle(
          _ringCenter,
          _ringRadius,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case _HandleKind.start:
        canvas.drawRect(Rect.fromLTWH(21, 22, 2, _knobRadius + stem), paint);
        canvas.drawCircle(center, _knobRadius, paint);
      case _HandleKind.end:
        canvas.drawRect(
          Rect.fromLTRB(21, 22 - _knobRadius - stem, 23, 22),
          paint,
        );
        canvas.drawCircle(center, _knobRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_HandlePainter oldDelegate) =>
      color != oldDelegate.color ||
      kind != oldDelegate.kind ||
      stem != oldDelegate.stem;
}

/// Read the notifier during hit testing, before Scrollable's down handler turns
/// a ballistic/drag activity into a hold. Rebuilding an IgnorePointer widget on
/// that notifier would allow a pointer to slip through before the next frame.
class _IgnoreScrollInput extends SingleChildRenderObjectWidget {
  const _IgnoreScrollInput({required this.blocked, required super.child});
  final bool Function() blocked;
  @override
  _RenderIgnoreScrollInput createRenderObject(BuildContext context) =>
      _RenderIgnoreScrollInput(blocked);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIgnoreScrollInput renderObject,
  ) {
    renderObject.blocked = blocked;
  }
}

class _RenderIgnoreScrollInput extends RenderProxyBox {
  _RenderIgnoreScrollInput(this.blocked);
  bool Function() blocked;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !blocked() && super.hitTest(result, position: position);
}

class _Magnifier extends StatefulWidget {
  const _Magnifier({
    required this.point,
    required this.maxWidth,
    required this.style,
  });

  final Offset? point;
  final double? maxWidth;
  final TiptapEditorStyle style;

  @override
  State<_Magnifier> createState() => _MagnifierState();
}

class _MagnifierState extends State<_Magnifier>
    with SingleTickerProviderStateMixin {
  static const _size = Size(108, 54);
  static const _hidden = Positioned(left: 0, top: 0, child: SizedBox.shrink());

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 110),
  )..addListener(() => setState(() {}));
  Offset? _last;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Magnifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.point == null) != (widget.point == null)) _sync();
  }

  void _sync() {
    final target = widget.point == null ? 0.0 : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else if (target == 1) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _last = widget.point ?? _last;
    final point = _last;
    if (point == null || widget.point == null && _controller.isDismissed) {
      return _hidden;
    }
    final t = Curves.easeOutCubic.transform(_controller.value);
    final size = _size * (.6 + .4 * t);
    final left = (point.dx - _size.width / 2).clamp(
      0.0,
      math.max(0.0, (widget.maxWidth ?? _size.width) - _size.width),
    );
    final center = Offset(
      left + _size.width / 2,
      math.max(0.0, point.dy - 90) + _size.height / 2 + (1 - t) * 16,
    );
    final style = widget.style;
    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      child: IgnorePointer(
        child: RawMagnifier(
          size: size,
          magnificationScale: 1.35,
          clipBehavior: Clip.antiAlias,
          focalPointOffset: point - center,
          decoration: MagnifierDecoration(
            opacity: t,
            shape: StadiumBorder(
              side: BorderSide(color: style.magnifierBorderColor, width: 2),
            ),
            shadows: [
              BoxShadow(
                color: style.magnifierShadowColor,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
