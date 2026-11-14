part of '../editor.dart';

extension _Gestures on TiptapEditorState {
  void _stopScrollOnDown(PointerDownEvent event) {
    // Touch drags are normally held by Scrollable before this listener runs.
    // Mouse/other presses may not be in its drag-device set: stop those here.
    if (!_scrollInputBlocked) return;
    _reveal = false;
    _scrollHolds[event.pointer] = _scroll.position.hold(
      () => _scrollHolds.remove(event.pointer),
    );
  }

  void _releaseScrollHolds() {
    final holds = _scrollHolds.values.toList();
    _scrollHolds.clear();
    for (final hold in holds) {
      hold.cancel();
    }
  }

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
    if (row.node.type == 'tableRow') _snapCaret = true;
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
    if (!extend && row.isAtomRow) {
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
      if (row.isAtomRow) {
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
    if (ScrollConfiguration.of(context).dragDevices.contains(event.kind) &&
        render?._horizontal._horizontalRowAt(_local(event.position)) != null) {
      _pendingMouseSelection = event;
      return;
    }
    _startMouseSelection(event);
  }

  void _startMouseSelection(PointerDownEvent event) {
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
    if (_pendingMouseSelection case final down?) {
      final delta = event.position - down.position;
      if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
        _pendingMouseSelection = null;
        _startMouseSelection(down);
      }
    }
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
    if (_pendingMouseSelection case final down?) {
      _pendingMouseSelection = null;
      if (event is PointerUpEvent &&
          (event.position - down.position).distance <= kTouchSlop) {
        _startMouseSelection(down);
      }
    }
    if (event is PointerCancelEvent) _pointerHit = null;
    if (!_touch) _endDrag(showMenu: false);
  }

  void _updateDrag(Offset global) {
    if (geometry == null || _dragAnchor == null) return;
    _dragGlobal = global;
    final position = geometry!.positionForOffset(
      _local(global - (_handleGrab ?? Offset.zero)),
    );
    var anchor = _dragAnchor!, head = position;
    final unit = _dragUnit;
    if (!_touch && unit != null && _dragGranularity > 1) {
      final resolved = widget.controller.state.doc.resolve(position);
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
    if (_touch) {
      _setState(
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
    if (mounted) _setState(() => _magnifier = null);
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
    if (widget.controller.state.selection is m.NodeSelection) {
      return;
    }
    _dragging = true;
    final selection = widget.controller.state.selection;
    _dragAnchor = selection.anchor;
    _pressedWord = appleCaret ? null : (selection.from, selection.to);
    _setState(() => _magnifier = _local(details.globalPosition));
  }

  void _longPressMoved(Offset global) {
    final word = _pressedWord;
    if (word != null && geometry != null) {
      final (from, to) = word;
      final position = geometry!.positionForOffset(_local(global));
      if (position >= from && position <= to) {
        widget.controller.setSelection(m.TextSelection(from, to));
        _setState(() => _magnifier = _local(global));
        return;
      }
      _dragAnchor = position > to ? from : to;
    }
    _updateDrag(global);
  }

  void _overflowDown(DragDownDetails details) {
    final render = _render, position = _overflowPosition;
    if (render == null || position == null) return;
    final index = render._horizontal._horizontalRowAt(
      _local(details.globalPosition),
    );
    if (index == null) return;
    final (block, blockPosition, pixels) = render._horizontal._horizontalTarget(
      _local(details.globalPosition),
      index,
    );
    render._horizontal.bind(block, blockPosition, position, pixels);
    _overflowHold = position.hold(() => _overflowHold = null);
  }

  void _overflowStart(DragStartDetails details) {
    if (_render?._horizontal.bound != true) return;
    _pendingMouseSelection = null;
    _pointerHit = null;
    _tapCount = 0;
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
    _render?._horizontal.updatePixels(_overflowPosition!.pixels);
  }

  void _unbindOverflow() {
    _render?._horizontal.unbind();
    _overflowPosition?.goIdle();
  }
}

class _PointerHit {
  const _PointerHit(this.doc, this.position, this.task, this.reference);
  final m.Node doc;
  final int position;
  final int? task;
  final m.Node? reference;
}
