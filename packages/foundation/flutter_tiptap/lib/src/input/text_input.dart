part of '../editor.dart';

class _InputWindow {
  const _InputWindow(this.start, this.rowIndex, this.placeholder);
  final int start, rowIndex;
  final bool placeholder;
}

class _TiptapTextInput with TextInputClient, DeltaTextInputClient {
  _TiptapTextInput(this.owner);
  static const _sentinel = '\u200b';
  static const _windowSize = 2048;
  final TiptapEditorState owner;
  TextInputConnection? _connection;
  (String?, double, FontWeight?, TextDirection, TextAlign)? _lastStyle;
  TextEditingValue _value = TextEditingValue.empty;
  TextEditingValue? _platformValue;
  TextEditingValue? _nativeValue;
  m.Node? _nativeDocument;
  _InputWindow? _nativeWindow;
  _InputWindow? _window;
  bool _applying = false, _freshComposition = false;
  int _serial = 0;
  int? _composition;
  int? _batchDocumentOffset;
  int? _selectedToInBatch;
  m.Selection? _selectionAtBatchStart;
  Offset? _floatingOrigin;
  TiptapController get controller => owner.widget.controller;
  bool get attached => _connection?.attached == true;
  @override
  TextEditingValue get currentTextEditingValue => _value;
  @override
  AutofillScope? get currentAutofillScope => null;

  void open() {
    if (owner.widget.readOnly ||
        !owner.widget.keyboardEnabled ||
        !owner._focusNode.hasPrimaryFocus) {
      return;
    }
    synchronize();
    if (!attached) {
      _lastStyle = null;
      _connection = TextInput.attach(
        this,
        TextInputConfiguration(
          viewId: View.of(owner.context).viewId,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          allowedMimeTypes: const [
            'image/png',
            'image/jpeg',
            'image/webp',
            'image/gif',
          ],
          enableDeltaModel: true,
          textCapitalization: TextCapitalization.sentences,
          keyboardAppearance: owner.widget.style.keyboardAppearance,
        ),
      );
      _connection!.setEditingState(_value);
      _platformValue = _value;
    }
    _connection!.show();
    owner._scheduleGeometry();
  }

  @override
  void insertContent(KeyboardInsertedContent content) {
    if (!owner.widget.readOnly && content.mimeType.startsWith('image/')) {
      unawaited(owner.pasteImage(content));
    }
  }

  void close({bool commit = true}) {
    if (commit) finishComposition();
    _connection?.close();
    _connection = null;
    _platformValue = null;
    _nativeWindow = null;
    _nativeValue = null;
    _nativeDocument = null;
  }

  void cancelComposition() {
    _composition = null;
    _freshComposition = false;
    _window = null;
    _nativeWindow = null;
    _nativeDocument = null;
    _nativeValue = null;
  }

  void finishComposition() {
    if (_composition == null) return;
    final applying = _applying;
    _applying = true;
    controller.exec('commitComposition', {'composition': _composition});
    controller._setComposing(TextRange.empty);
    _composition = null;
    _freshComposition = false;
    _value = _value.copyWith(composing: TextRange.empty);
    _applying = applying;
    if (!applying) synchronize();
  }

  int _boundaryBefore(m.Node block, int offset) {
    if (offset <= 0 || offset >= block.content.size) return offset;
    final start = math.max<int>(0, offset - 64);
    final text = block.content
        .cut(start, math.min<int>(block.content.size, offset + 64))
        .inlineText(atom: '\n');
    var position = start, result = start;
    for (final cluster in text.characters) {
      position += cluster.length;
      if (position > offset) break;
      result = position;
    }
    return result;
  }

  void synchronize() {
    if (_applying) return;
    final state = controller.state,
        selection = state.selection,
        doc = state.doc;
    final head = doc.resolve(selection.head),
        anchor = doc.resolve(selection.anchor);
    if (selection is! m.TextSelection ||
        !head.parent.isTextblock ||
        !anchor.parent.isTextblock ||
        head.start() != anchor.start() ||
        selection.to - selection.from > _windowSize - 2) {
      _window = _InputWindow(
        selection.from,
        doc.rowIndexAt(selection.head),
        true,
      );
      _value = TextEditingValue(
        text: '$_sentinel\ufffc',
        selection: TextSelection(
          baseOffset: selection.anchor <= selection.head ? 1 : 2,
          extentOffset: selection.anchor <= selection.head ? 2 : 1,
        ),
      );
    } else {
      final block = head.parent, blockStart = head.start();
      var from = math.max(0, head.parentOffset - _windowSize ~/ 2);
      if (_composition != null &&
          _window?.rowIndex == doc.rowIndexAt(selection.head) &&
          _window?.placeholder == false) {
        from = (_window!.start - blockStart).clamp(0, block.content.size);
      }
      from = math.min(
        from,
        (selection.from - blockStart).clamp(0, block.content.size),
      );
      if (selection.to - blockStart > from + _windowSize) {
        from = selection.to - blockStart - _windowSize;
      }
      from = math.min(from, math.max(0, block.content.size - _windowSize));
      from = _boundaryBefore(block, from);
      final to = _boundaryBefore(
        block,
        math.min(block.content.size, from + _windowSize),
      );
      final text = block.content
          .cut(from, to)
          .map(
            (n) => n.isText
                ? n.text!
                : n.type == 'hardBreak'
                ? '\n'
                : '\ufffc',
          )
          .join();
      final start = blockStart + from, composing = controller.composing;
      _window = _InputWindow(start, doc.rowIndexAt(selection.head), false);
      final comp =
          composing.isValid &&
              composing.start >= start &&
              composing.end <= start + text.length
          ? TextRange(
              start: composing.start - start + 1,
              end: composing.end - start + 1,
            )
          : TextRange.empty;
      _value = TextEditingValue(
        text: '$_sentinel$text',
        selection: TextSelection(
          baseOffset: (selection.anchor - start + 1).clamp(1, text.length + 1),
          extentOffset: (selection.head - start + 1).clamp(1, text.length + 1),
        ),
        composing: comp,
      );
    }
    if (attached && !_sameEditingState(_value, _platformValue)) {
      _connection!.setEditingState(_value);
      _platformValue = _value;
    }
  }

  // A collapsed composing range and TextRange.empty both mean no marked text.
  bool _sameEditingState(TextEditingValue a, TextEditingValue? b) =>
      b != null &&
      a.text == b.text &&
      a.selection.baseOffset == b.selection.baseOffset &&
      a.selection.extentOffset == b.selection.extentOffset &&
      (a.composing == b.composing ||
          ((!a.composing.isValid || a.composing.isCollapsed) &&
              (!b.composing.isValid || b.composing.isCollapsed)));

  // Rebase an IME offset over the editor's intervening replacement. Native
  // deltas can still refer to the state preceding an outbound setEditingState.
  int _rebaseOffset(String before, String after, int offset) {
    if (offset < 0 || before == after) return offset;
    var prefix = 0, suffix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before.codeUnitAt(before.length - suffix - 1) ==
            after.codeUnitAt(after.length - suffix - 1)) {
      suffix++;
    }
    final oldEnd = before.length - suffix, newEnd = after.length - suffix;
    if (offset < prefix) return offset;
    if (offset > oldEnd) return offset + after.length - before.length;
    return newEnd;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _applyDeltas(textEditingDeltas, fromPlatform: true);
  }

  void deleteFromKey({required bool backward}) {
    final selection = _value.selection;
    if (!selection.isValid) return;
    var from = selection.start, to = selection.end;
    if (selection.isCollapsed) {
      if (backward && from > 0) {
        from -= m.graphemeBefore(_value.text, from).length;
      } else if (!backward && to < _value.text.length) {
        to += m.graphemeAfter(_value.text, to).length;
      }
    }
    if (from == to) {
      // Forward Delete at the window edge can join the following block.
      finishComposition();
      controller.exec(backward ? 'deleteBackward' : 'deleteForward');
      return;
    }
    final range = TextRange(start: from, end: to);
    final next = _value.replaced(range, '');
    _applyDeltas([
      TextEditingDeltaDeletion(
        oldText: _value.text,
        deletedRange: range,
        selection: next.selection,
        composing: next.composing,
      ),
    ], fromPlatform: false);
  }

  void insertNewline() {
    finishComposition();
    final selection = _value.selection;
    if (!selection.isValid) return;
    _applyDeltas([
      TextEditingDeltaReplacement(
        oldText: _value.text,
        replacedRange: TextRange(start: selection.start, end: selection.end),
        replacementText: '\n',
        selection: TextSelection.collapsed(offset: selection.start + 1),
        composing: TextRange.empty,
      ),
    ], fromPlatform: false);
  }

  void _applyDeltas(
    List<TextEditingDelta> textEditingDeltas, {
    required bool fromPlatform,
  }) {
    if (owner.widget.readOnly ||
        !owner.widget.keyboardEnabled ||
        !owner._focusNode.hasPrimaryFocus) {
      return;
    }
    // Keep application synchronous so desktop commands see every earlier delta.
    _applying = true;
    _batchDocumentOffset = null;
    _selectedToInBatch = null;
    _selectionAtBatchStart = controller.state.selection;
    try {
      for (final delta in textEditingDeltas) {
        if (fromPlatform &&
            delta.oldText == _nativeValue?.text &&
            _nativeWindow != null &&
            identical(controller.state.doc, _nativeDocument)) {
          // A queued delta still belongs to the previous window, even if the
          // framework has already sent a newly centred window to the engine.
          _value = _nativeValue!;
          _window = _nativeWindow;
        }
        final nativeNext = delta.apply(TextEditingValue(text: delta.oldText));
        if (fromPlatform) _platformValue = nativeNext;
        int? from, to;
        var text = '';
        switch (delta) {
          case TextEditingDeltaInsertion():
            from = to = delta.insertionOffset;
            text = delta.textInserted;
          case TextEditingDeltaDeletion():
            from = delta.deletedRange.start;
            to = delta.deletedRange.end;
          case TextEditingDeltaReplacement():
            from = delta.replacedRange.start;
            to = delta.replacedRange.end;
            text = delta.replacementText;
          case TextEditingDeltaNonTextUpdate():
            break;
        }
        var next = nativeNext;
        if (delta.oldText != _value.text) {
          final before = _value.text;
          if (from != null && to != null) {
            final insertion = from == to;
            from = _rebaseOffset(delta.oldText, before, from);
            to = insertion
                ? from
                : math.max(from, _rebaseOffset(delta.oldText, before, to));
          }
          final rebased = from == null
              ? before
              : before.replaceRange(from, to!, text);
          int position(int offset) =>
              _rebaseOffset(nativeNext.text, rebased, offset);
          next = TextEditingValue(
            text: rebased,
            selection: nativeNext.selection.copyWith(
              baseOffset: position(nativeNext.selection.baseOffset),
              extentOffset: position(nativeNext.selection.extentOffset),
            ),
            composing: nativeNext.composing.isValid
                ? TextRange(
                    start: position(nativeNext.composing.start),
                    end: position(nativeNext.composing.end),
                  )
                : TextRange.empty,
          );
        }
        _process(next, from, to, text);
        _nativeValue = fromPlatform ? nativeNext : null;
        _nativeDocument = fromPlatform ? controller.state.doc : null;
        _nativeWindow =
            fromPlatform &&
                next.text == nativeNext.text &&
                _batchDocumentOffset == null &&
                _window?.placeholder == false
            ? _window
            : null;
      }
    } finally {
      _applying = false;
      _batchDocumentOffset = null;
    }
    synchronize();
    owner._scheduleGeometry(reveal: true);
  }

  void _process(TextEditingValue next, int? from, int? to, String text) {
    var window = _window!;
    if (from == null && next.selection.baseOffset == 0) {
      _selectedToInBatch = next.selection.extentOffset;
    }
    // Android's select-all spans the editable, sentinel included.
    if (from == null &&
        next.selection.baseOffset == 0 &&
        next.selection.extentOffset == next.text.length) {
      finishComposition();
      controller.exec('selectAll');
      _value = next;
      return;
    }
    if (from == 0 &&
        to == _value.text.length &&
        !window.placeholder &&
        controller.state.selection is m.AllSelection) {
      controller.exec('selectAll');
      window = _InputWindow(0, window.rowIndex, true);
    }
    final wasComposing =
        _value.composing.isValid && !_value.composing.isCollapsed;
    final composing = next.composing.isValid && !next.composing.isCollapsed;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        wasComposing &&
        (text == '\n' || text == '\r' || text == '\r\n')) {
      // UIKit may report Return as replacement of the marked range by a
      // newline. Commit our live marked text before accepting another Return.
      finishComposition();
      _value = next;
      _batchDocumentOffset =
          controller.state.selection.head - next.selection.extentOffset;
      return;
    }
    if (composing && _composition == null) {
      _composition = ++_serial;
      _freshComposition = true;
    }
    var base = window.start, structural = false, rule = false;
    if (from != null && to != null) {
      // An IME's "clear" selects from the sentinel to the caret, then deletes
      // that in one batch. Backspace never selects first.
      if (from == 0 &&
          to > 0 &&
          to == _selectedToInBatch &&
          text.isEmpty &&
          controller.state.selection is! m.AllSelection) {
        final selection = _selectionAtBatchStart!;
        controller.exec('deleteBefore', {
          'position': !window.placeholder
              ? window.start + to - 1
              : to <= 1
              ? selection.from
              : selection.to,
        });
        structural = true;
      } else if (text.isEmpty &&
          from < to &&
          !window.placeholder &&
          controller.state.canUndoInputRule &&
          window.start + to - 1 == controller.state.selection.head) {
        controller.exec('undoInputRule');
        structural = true;
      } else if (from == 0 && to == 1 && text.isEmpty && !window.placeholder) {
        controller.exec('deleteBackward');
        structural = true;
      } else {
        final selection = controller.state.selection;
        final a =
            (_batchDocumentOffset != null
                    ? from + _batchDocumentOffset!
                    : window.placeholder
                    ? selection.from
                    : window.start + math.max<int>(0, from - 1))
                .clamp(0, controller.state.doc.content.size);
        final b =
            (_batchDocumentOffset != null
                    ? to + _batchDocumentOffset!
                    : window.placeholder
                    ? selection.to
                    : window.start + math.max<int>(0, to - 1))
                .clamp(0, controller.state.doc.content.size);
        final state = controller.state;
        final same = a == state.selection.from && b == state.selection.to;
        final temporary = state.apply(
          state.tr
              .setSelection(
                window.placeholder &&
                        (state.selection is m.NodeSelection ||
                            state.selection is m.GapSelection)
                    ? state.selection
                    : m.TextSelection(a, b),
              )
              .setStoredMarks(same ? state.storedMarks : null),
        );
        if (text == '\t' && !composing) {
          final tab = controller.commands.execute(temporary, 'tab');
          if (tab.docChanged || tab.selectionSet) {
            controller.apply(tab);
            structural = true;
          } else {
            owner._perform('tab');
            structural = true;
          }
        } else if (text.length > 1 &&
            !composing &&
            !wasComposing &&
            controller._isCopied(text)) {
          // The iOS menu's Paste inserts only the clipboard's plain text.
          controller.setSelection(temporary.selection);
          controller._pasteCopied(text);
          structural = true;
        } else if (text == '\n' || text == '\r' || text == '\r\n') {
          controller.apply(
            controller.commands.execute(temporary, 'splitBlock'),
          );
          structural = true;
        } else if (text.contains('\n') || text.contains('\r')) {
          controller.setSelection(temporary.selection);
          controller.insertCommittedLines(text, owner.widget.onPasteText);
          structural = true;
        } else {
          final tr = controller.commands.execute(temporary, 'insertText', {
            'text': text,
            'committed': text.isNotEmpty && !composing && !wasComposing,
            'composition': _composition,
          });
          if (_freshComposition) {
            tr.setMeta('closeHistory', true);
            _freshComposition = false;
          }
          controller.apply(tr);
          rule = tr.metadata['inputRule'] == true;
          if (window.placeholder) {
            base = controller.state.selection.head - text.length;
          }
        }
      }
    }
    _value = next;
    if (!structural && !rule) {
      final length = controller.state.doc.content.size;
      int position(int offset) {
        if (_batchDocumentOffset != null) {
          return (offset + _batchDocumentOffset!).clamp(0, length);
        }
        if (window.placeholder && from == null) {
          return offset <= 1
              ? controller.state.selection.from
              : controller.state.selection.to;
        }
        return (base + math.max<int>(0, offset - 1)).clamp(0, length);
      }

      if (next.selection.isValid) {
        final selection = m.TextSelection(
          position(next.selection.baseOffset),
          position(next.selection.extentOffset),
        );
        if (selection != controller.state.selection) {
          controller.apply(
            controller.state.tr.setSelection(selection)
              ..setMeta('composition', _composition),
          );
        }
      }
      controller._setComposing(
        composing
            ? TextRange(
                start: position(next.composing.start),
                end: position(next.composing.end),
              )
            : TextRange.empty,
      );
    } else {
      controller._setComposing(TextRange.empty);
    }
    if (wasComposing && !composing) {
      final committed = controller.exec('commitComposition', {
        'composition': _composition,
      });
      rule = rule || committed.metadata['inputRule'] == true;
      _composition = null;
      _freshComposition = false;
      controller._setComposing(TextRange.empty);
    }
    if (rule || (from != null && (window.placeholder || structural))) {
      _batchDocumentOffset =
          controller.state.selection.head - next.selection.extentOffset;
      _window = _InputWindow(
        base,
        controller.state.doc.rowIndexAt(controller.state.selection.head),
        false,
      );
    }
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    var from = 0, suffix = 0;
    while (from < value.text.length &&
        from < _value.text.length &&
        value.text.codeUnitAt(from) == _value.text.codeUnitAt(from)) {
      from++;
    }
    while (suffix < value.text.length - from &&
        suffix < _value.text.length - from &&
        value.text.codeUnitAt(value.text.length - suffix - 1) ==
            _value.text.codeUnitAt(_value.text.length - suffix - 1)) {
      suffix++;
    }
    updateEditingValueWithDeltas([
      TextEditingDeltaReplacement(
        oldText: _value.text,
        replacedRange: TextRange(start: from, end: _value.text.length - suffix),
        replacementText: value.text.substring(from, value.text.length - suffix),
        selection: value.selection,
        composing: value.composing,
      ),
    ]);
  }

  void updateGeometry() {
    final render = owner._render;
    if (!attached || render == null || !render.attached || !render.hasSize) {
      return;
    }
    final style = owner.widget.style,
        caret = render._caretForInput(controller.state.selection.head);
    _connection!.setEditableSizeAndTransform(
      render.size,
      render.getTransformTo(null),
    );
    _connection!.setCaretRect(caret);
    final composing = controller.composing;
    final rects = composing.isValid && !composing.isCollapsed
        ? render.selectionRects(composing.start, composing.end)
        : <Rect>[];
    _connection!.setComposingRect(
      rects.isEmpty ? caret : rects.reduce((a, b) => a.expandToInclude(b)),
    );
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _connection!.setSelectionRects([
        SelectionRect(position: _value.selection.extentOffset, bounds: caret),
      ]);
    }
    final node = controller.state.doc
        .resolve(controller.state.selection.head)
        .parent;
    final base = style.forBlock(node);
    final nextStyle = (
      base.fontFamily,
      base.fontSize ?? 17.0,
      base.fontWeight,
      style.textDirection,
      style.textAlign,
    );
    if (nextStyle == _lastStyle) return;
    _lastStyle = nextStyle;
    _connection!.updateStyle(
      TextInputStyle(
        fontFamily: base.fontFamily,
        fontSize: base.fontSize ?? 17,
        fontWeight: base.fontWeight,
        textDirection: style.textDirection,
        textAlign: style.textAlign,
      ),
    );
  }

  @override
  void performAction(TextInputAction action) {
    if (owner.widget.readOnly) return;
    if (action == TextInputAction.newline) {
      // Android IME_ACTION_NONE is a request, with no accompanying insertion.
      // Apple engines also send newline notifications alongside text deltas.
      if (defaultTargetPlatform == TargetPlatform.android) insertNewline();
      return;
    }
    finishComposition();
    if (action == TextInputAction.next || action == TextInputAction.previous) {
      owner._perform(action == TextInputAction.next ? 'tab' : 'shiftTab');
    } else if (action == TextInputAction.done) {
      owner._focusNode.unfocus();
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    final geometry = owner.geometry;
    if (geometry == null || owner.widget.readOnly) return;
    if (point.state == FloatingCursorDragState.Start) {
      finishComposition();
      _floatingOrigin = geometry
          .caretRect(controller.state.selection.head)
          .center;
    }
    if (_floatingOrigin != null &&
        point.state == FloatingCursorDragState.Update) {
      owner._selectPosition(
        geometry.positionForOffset(
          _floatingOrigin! + (point.offset ?? Offset.zero),
        ),
      );
    }
    if (point.state == FloatingCursorDragState.End) _floatingOrigin = null;
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) =>
      owner._scheduleGeometry(reveal: true);
  @override
  bool onFocusReceived() {
    owner._focusNode.requestFocus();
    return true;
  }

  @override
  void connectionClosed() {
    _connection = null;
    finishComposition();
  }

  @override
  void showToolbar() => owner._showContextMenu();
  @override
  void performSelector(String selectorName) =>
      owner._performSelector(selectorName);
}
