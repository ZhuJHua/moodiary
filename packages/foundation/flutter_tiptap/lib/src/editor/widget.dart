part of '../editor.dart';

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
  late final _caret = _CaretMotion(this);
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
  PointerDeviceKind _pointerKind =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? PointerDeviceKind.touch
      : PointerDeviceKind.mouse;
  Offset? _pointerDown, _dragGlobal, _magnifier, _handleGrab;
  int? _dragAnchor;
  TextRange? _dragUnit;
  int _dragGranularity = 1;
  MouseCursor _cursor = SystemMouseCursors.text;
  _PointerHit? _pointerHit;
  PointerDownEvent? _pendingMouseSelection;
  final Map<int, ScrollHoldController> _scrollHolds = {};
  bool get _scrollInputBlocked =>
      _scroll.hasClients && _scroll.position.isScrollingNotifier.value;

  void _releaseScrollHold(PointerEvent event) =>
      _scrollHolds.remove(event.pointer)?.cancel();

  ScrollPositionWithSingleContext? _overflowPosition;
  Drag? _overflowDrag;
  ScrollHoldController? _overflowHold;

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
    final marker = render._markerLayout(
      render._indexForPosition(position),
      position: position,
    );
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
  void debugMuteCaret(bool muted) => _caret._ticker.muted = muted;
  @visibleForTesting
  Size? debugMeasuredSize(m.Node node, double width) =>
      _render?._nodeSizes.get(node, width);
  @visibleForTesting
  void debugCacheMeasurement(m.Node node, double width, Size size) =>
      _render?._nodeSizes.put(node, width, size);

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
  List<Rect> get debugSearchHighlightRects => _render?._searchRects() ?? [];

  /// Commits any active IME composition before a host editing action.
  void finishComposition() => _input.finishComposition();

  /// Focuses the editor and attaches its platform text input connection.
  void requestKeyboard() {
    if (widget.readOnly) return;
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
        widget.controller.state.selection is m.NodeSelection) {
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

  bool _revealAllowed({bool geometry = false}) =>
      widget.controller.state.selection is! m.NodeSelection &&
      (geometry
          ? _render?._scrollAnchored != true &&
                widget.controller.state.selection is! m.AllSelection
          : widget.controller.lastTransaction?.blockMove == null);

  void _setState(VoidCallback update) => setState(update);

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
    if (!_revealAllowed()) _reveal = false;
    _scheduleGeometry(reveal: _revealAllowed() && !_dragging);
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
  Future<void> pasteImage(Object payload) async =>
      widget.onPasteImage?.call(payload);

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
    if (!_revealAllowed(geometry: true)) _reveal = false;
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
    render._horizontal._revealHorizontal(
      widget.controller.state.selection.head,
    );
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

  // As in Flutter's text fields, a menu copy ends the selection on Android
  // and keeps it elsewhere.

  bool get _selectsAll {
    final m.EditorState(:doc, :selection) = widget.controller.state;
    return selection is m.AllSelection ||
        selection.from <= m.Selection.near(doc, 0).from &&
            selection.to >=
                m.Selection.near(doc, doc.content.size, bias: -1).to;
  }

  /// Runs the paste action, as the keyboard shortcut does.
  void paste() => _perform('paste', const {});

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
              _pointerKind = PointerDeviceKind.mouse;
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
                  m.isMediaNode(widget.controller.state.doc.nodeAt(position));
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
                    _render?._horizontal._horizontalRowAt(
                          _local(event.position),
                        ) !=
                        null) {
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (_) => _render?._horizontal._scrollCode(
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
                                  _render?._horizontal._horizontalRowAt(
                                        _local(point),
                                      ) !=
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
                          PointerDeviceKind.mouse,
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
                        onLongPressStart: (details) {
                          if (_pointerKind != PointerDeviceKind.mouse) {
                            _longPress(details);
                          }
                        },
                        onLongPressMoveUpdate: (details) {
                          if (_pointerKind != PointerDeviceKind.mouse) {
                            _longPressMoved(details.globalPosition);
                          }
                        },
                        onLongPressEnd: (_) {
                          if (_pointerKind != PointerDeviceKind.mouse) {
                            _endDrag(showMenu: true);
                          }
                        },
                        onLongPressCancel: () {
                          if (_pointerKind != PointerDeviceKind.mouse) {
                            _endDrag(showMenu: false);
                          }
                        },
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
                                onCaretLayout: _updateCaret,
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
