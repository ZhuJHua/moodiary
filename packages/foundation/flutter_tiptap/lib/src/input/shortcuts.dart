part of '../editor.dart';

class _EditorIntent extends Intent {
  const _EditorIntent(this.name, [this.args = const {}]);
  final String name;
  final Map<String, dynamic> args;
}

class _EditorAction extends Action<_EditorIntent> {
  _EditorAction(this.owner);
  final TiptapEditorState owner;
  @override
  bool isEnabled(_EditorIntent intent) {
    if (!owner._focusNode.hasPrimaryFocus) return false;
    final composing = owner.widget.controller.composing;
    if (composing.isValid &&
        !composing.isCollapsed &&
        (intent.name == 'move' ||
            intent.name == 'splitBlock' ||
            intent.name == 'hardBreak' ||
            intent.name == 'exitCode' ||
            intent.name == 'tab' ||
            intent.name == 'shiftTab' ||
            intent.name.startsWith('delete'))) {
      return false;
    }
    return true;
  }

  @override
  Object? invoke(_EditorIntent intent) {
    owner._perform(intent.name, intent.args);
    return null;
  }
}

Map<ShortcutActivator, Intent> _editorShortcuts() {
  final mac =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final result = <ShortcutActivator, Intent>{};
  void add(
    LogicalKeyboardKey key,
    String name, {
    bool mod = false,
    bool shift = false,
    bool alt = false,
    Map<String, dynamic> args = const {},
  }) {
    result[SingleActivator(
      key,
      meta: mod && mac,
      control: mod && !mac,
      alt: alt,
      shift: shift,
    )] = _EditorIntent(
      name,
      args,
    );
  }

  for (final shift in [false, true]) {
    for (final entry in {
      LogicalKeyboardKey.arrowLeft: 'left',
      LogicalKeyboardKey.arrowRight: 'right',
      LogicalKeyboardKey.arrowUp: 'up',
      LogicalKeyboardKey.arrowDown: 'down',
      LogicalKeyboardKey.home: mac ? 'scrollStart' : 'lineStart',
      LogicalKeyboardKey.end: mac ? 'scrollEnd' : 'lineEnd',
      LogicalKeyboardKey.pageUp: mac ? 'scrollPageUp' : 'pageUp',
      LogicalKeyboardKey.pageDown: mac ? 'scrollPageDown' : 'pageDown',
    }.entries) {
      add(
        entry.key,
        'move',
        shift: shift,
        args: {'direction': entry.value, 'extend': shift},
      );
    }
    for (final entry in {
      LogicalKeyboardKey.arrowLeft: 'left',
      LogicalKeyboardKey.arrowRight: 'right',
    }.entries) {
      result[SingleActivator(
        entry.key,
        alt: mac,
        control: !mac,
        shift: shift,
      )] = _EditorIntent('move', {
        'direction': entry.value,
        'extend': shift,
        'word': true,
      });
      if (mac) {
        add(
          entry.key,
          'move',
          mod: true,
          shift: shift,
          args: {
            'direction': entry.value == 'left' ? 'lineStart' : 'lineEnd',
            'extend': shift,
          },
        );
      }
    }
    add(
      mac ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.home,
      'move',
      mod: true,
      shift: shift,
      args: {'direction': 'docStart', 'extend': shift},
    );
    add(
      mac ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.end,
      'move',
      mod: true,
      shift: shift,
      args: {'direction': 'docEnd', 'extend': shift},
    );
  }
  add(LogicalKeyboardKey.backspace, 'deleteBackward');
  add(LogicalKeyboardKey.delete, 'deleteForward');
  result[SingleActivator(
    LogicalKeyboardKey.backspace,
    alt: mac,
    control: !mac,
  )] = const _EditorIntent(
    'deleteWordBackward',
  );
  result[SingleActivator(LogicalKeyboardKey.delete, alt: mac, control: !mac)] =
      const _EditorIntent('deleteWordForward');
  if (mac) {
    add(LogicalKeyboardKey.backspace, 'deleteLineBackward', mod: true);
    add(LogicalKeyboardKey.delete, 'deleteLineForward', mod: true);
  }
  add(LogicalKeyboardKey.keyF, 'find', mod: true);
  add(LogicalKeyboardKey.keyK, 'editLink', mod: true);
  add(LogicalKeyboardKey.escape, 'dismissSuggestion');
  add(LogicalKeyboardKey.tab, 'tab');
  add(LogicalKeyboardKey.tab, 'shiftTab', shift: true);
  add(LogicalKeyboardKey.enter, 'exitCode', mod: true);
  add(LogicalKeyboardKey.digit7, 'toggleOrderedList', mod: true, shift: true);
  add(LogicalKeyboardKey.digit8, 'toggleBulletList', mod: true, shift: true);
  add(LogicalKeyboardKey.digit9, 'toggleTaskList', mod: true, shift: true);
  add(LogicalKeyboardKey.keyB, 'toggleBlockquote', mod: true, shift: true);
  add(LogicalKeyboardKey.keyC, 'toggleCodeBlock', mod: true, alt: true);
  add(LogicalKeyboardKey.enter, 'splitBlock');
  add(LogicalKeyboardKey.enter, 'hardBreak', shift: true);
  for (final entry in {
    LogicalKeyboardKey.keyB: 'bold',
    LogicalKeyboardKey.keyI: 'italic',
    LogicalKeyboardKey.keyU: 'underline',
    LogicalKeyboardKey.keyE: 'code',
  }.entries) {
    add(entry.key, 'toggleMark', mod: true, args: {'type': entry.value});
  }
  add(
    LogicalKeyboardKey.keyS,
    'toggleMark',
    mod: true,
    shift: true,
    args: {'type': 'strike'},
  );
  add(
    LogicalKeyboardKey.keyH,
    'toggleMark',
    mod: true,
    shift: true,
    args: {'type': 'highlight'},
  );
  add(LogicalKeyboardKey.keyZ, 'undo', mod: true);
  add(LogicalKeyboardKey.keyZ, 'redo', mod: true, shift: true);
  add(LogicalKeyboardKey.keyY, 'redo', mod: true);
  add(LogicalKeyboardKey.keyA, 'selectAll', mod: true);
  add(LogicalKeyboardKey.keyC, 'copy', mod: true);
  add(LogicalKeyboardKey.keyX, 'cut', mod: true);
  add(LogicalKeyboardKey.keyV, 'paste', mod: true);
  add(LogicalKeyboardKey.keyV, 'pastePlain', mod: true, shift: true);
  const digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];
  for (var i = 0; i < digits.length; i++) {
    add(
      digits[i],
      i == 0 ? 'setParagraph' : 'toggleHeading',
      mod: true,
      alt: true,
      args: {'level': i},
    );
  }
  return result;
}

extension on TiptapEditorState {
  KeyEventResult _routeTextInputKey(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    // A selected atom holds keyboard focus without an IME connection. Printable
    // hardware input can therefore leave the atom without racing native deltas.
    if (!_input.attached &&
        !widget.readOnly &&
        widget.controller.state.selection is m.NodeSelection) {
      final keyboard = HardwareKeyboard.instance;
      final character = event.character;
      if (!keyboard.isControlPressed &&
          !keyboard.isAltPressed &&
          !keyboard.isMetaPressed &&
          character != null &&
          character.isNotEmpty &&
          !RegExp(r'[\x00-\x1f\x7f]').hasMatch(character)) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          widget.controller.exec('insertText', {'text': character});
        }
        return KeyEventResult.handled;
      }
    }
    final composing = widget.controller.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    final mobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final keyboardState = HardwareKeyboard.instance;
    final plainNativeEdit =
        _input.attached &&
        mobile &&
        !keyboardState.isControlPressed &&
        !keyboardState.isMetaPressed &&
        !keyboardState.isAltPressed &&
        !keyboardState.isShiftPressed &&
        const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.backspace,
          LogicalKeyboardKey.delete,
          LogicalKeyboardKey.tab,
        ].contains(event.logicalKey);
    if (!isComposing && !plainNativeEdit) {
      final keyboard = HardwareKeyboard.instance;
      for (final entry in _editorShortcuts().entries) {
        if (entry.key.accepts(event, keyboard)) {
          final intent = entry.value as _EditorIntent;
          _perform(intent.name, intent.args);
          return KeyEventResult.handled;
        }
      }
      if (event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          _perform('splitBlock');
        }
        return KeyEventResult.handled;
      }
    }
    final android =
        _input.attached && defaultTargetPlatform == TargetPlatform.android;
    if (android &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        (event.character == null || event.character!.isEmpty)) {
      // Some soft IMEs send KEYCODE_ENTER with Unicode 0. The adapter cannot
      // insert a character for that event, even on a multiline connection.
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _input.insertNewline();
      }
      return KeyEventResult.handled;
    }
    if (android &&
        (event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete)) {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed ||
          keyboard.isAltPressed ||
          keyboard.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      // InputConnectionAdaptor has no KEYCODE_DEL/FORWARD_DEL fallback.
      // Handle the edit once, including live composition, and sync it to the IME.
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _input.deleteFromKey(
          backward: event.logicalKey == LogicalKeyboardKey.backspace,
        );
      }
      return KeyEventResult.handled;
    }
    if ((isComposing ||
            plainNativeEdit && defaultTargetPlatform == TargetPlatform.iOS ||
            plainNativeEdit &&
                const [
                  LogicalKeyboardKey.enter,
                  LogicalKeyboardKey.numpadEnter,
                  LogicalKeyboardKey.tab,
                ].contains(event.logicalKey)) &&
        const [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.backspace,
          LogicalKeyboardKey.delete,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.home,
          LogicalKeyboardKey.end,
          LogicalKeyboardKey.pageUp,
          LogicalKeyboardKey.pageDown,
          LogicalKeyboardKey.tab,
        ].contains(event.logicalKey)) {
      // Native deltas/actions must stay ordered with pending text. Ancestor
      // shortcuts (including Tab traversal) must not consume these keys either.
      return KeyEventResult.skipRemainingHandlers;
    }
    return KeyEventResult.ignored;
  }

  void _perform(String name, [Map<String, dynamic> args = const {}]) {
    final composing = widget.controller.composing;
    if (composing.isValid &&
        !composing.isCollapsed &&
        (name == 'exitCode' ||
            name == 'tab' ||
            name == 'shiftTab' ||
            name == 'move' ||
            name == 'splitBlock' ||
            name == 'hardBreak' ||
            name.startsWith('delete'))) {
      return;
    }
    if (name == 'find' || name == 'editLink') {
      _input.finishComposition();
      if (name == 'find') widget.onFind?.call();
      if (name == 'editLink' && !widget.readOnly) widget.onEditLink?.call();
      return;
    }
    if (name == 'dismissSuggestion' && (_menu.isShown || _systemMenuVisible)) {
      _hideContextMenu();
      return;
    }
    if (name == 'dismissSuggestion' && widget.onEscape?.call() == true) return;
    if (!_touch && !widget.readOnly) {
      final key = name == 'splitBlock'
          ? 'Enter'
          : name == 'move' && args['direction'] == 'up'
          ? 'ArrowUp'
          : name == 'move' && args['direction'] == 'down'
          ? 'ArrowDown'
          : name == 'dismissSuggestion'
          ? 'Escape'
          : '';
      if (widget.controller.handleReferenceSuggestionKey(key)) return;
    }
    if (name == 'dismissSuggestion') {
      if (_menu.isShown || _systemMenuVisible) {
        _hideContextMenu();
      } else if (widget.controller.state.selection
          case final m.NodeSelection selection) {
        widget.controller.setSelection(
          m.Selection.beside(widget.controller.state.doc, selection.to),
        );
        requestKeyboard();
      } else if (widget.controller.state.selection
          case final m.CellSelection selection) {
        widget.controller.setSelection(
          m.Selection.beside(
            widget.controller.state.doc,
            selection.headCell + 1,
          ),
        );
        requestKeyboard();
      }
      return;
    }
    if (name == 'copy') {
      unawaited(_copy());
      return;
    }
    if (name == 'selectAll') {
      _input.finishComposition();
      widget.controller.exec(name);
      return;
    }
    if (name == 'move') {
      _input.finishComposition();
      _move(
        args['direction'] as String,
        extend: args['extend'] == true,
        word: args['word'] == true,
      );
      return;
    }
    if (widget.readOnly) return;
    if (name == 'tab' || name == 'shiftTab') {
      _input.finishComposition();
      final tr = widget.controller.commands.execute(
        widget.controller.state,
        name,
      );
      if (tr.docChanged || tr.selectionSet) {
        widget.controller.apply(tr);
      } else if (widget.onBoundaryNavigation?.call(name) == true) {
        return;
      } else if (name == 'tab') {
        FocusScope.of(context).nextFocus();
      } else {
        FocusScope.of(context).previousFocus();
      }
      return;
    }
    _input.finishComposition();
    _goalX = null;
    if (name == 'paste') {
      unawaited(_paste());
      return;
    }
    if (name == 'pastePlain') {
      unawaited(_pastePlain());
      return;
    }
    if (name == 'cut') {
      unawaited(_copy(cut: true));
      return;
    }
    if (name.startsWith('deleteWord') || name.startsWith('deleteLine')) {
      final backward = name.endsWith('Backward'),
          selection = widget.controller.state.selection;
      if (selection.empty) {
        final target = name.startsWith('deleteWord')
            ? _wordPosition(backward)
            : (backward
                  ? geometry!.lineBoundary(selection.head).start
                  : geometry!.lineBoundary(selection.head).end);
        if (target != selection.head) {
          widget.controller.setSelection(
            m.TextSelection(selection.head, target),
          );
        }
      }
      widget.controller.exec(backward ? 'deleteBackward' : 'deleteForward');
    } else {
      widget.controller.exec(name, args);
    }
  }

  void _performSelector(String selector) {
    if (selector == 'insertTab:' || selector == 'insertBacktab:') {
      _input.performAction(
        selector == 'insertTab:'
            ? TextInputAction.next
            : TextInputAction.previous,
      );
      return;
    }
    final names = <String, (String, Map<String, dynamic>)>{
      'moveLeft:': ('move', {'direction': 'left'}),
      'moveRight:': ('move', {'direction': 'right'}),
      'moveUp:': ('move', {'direction': 'up'}),
      'moveDown:': ('move', {'direction': 'down'}),
      'pageUp:': ('move', {'direction': 'scrollPageUp'}),
      'pageDown:': ('move', {'direction': 'scrollPageDown'}),
      'scrollToBeginningOfDocument:': ('move', {'direction': 'scrollStart'}),
      'scrollToEndOfDocument:': ('move', {'direction': 'scrollEnd'}),
      'moveWordLeft:': ('move', {'direction': 'left', 'word': true}),
      'moveWordRight:': ('move', {'direction': 'right', 'word': true}),
      'moveToBeginningOfLine:': ('move', {'direction': 'lineStart'}),
      'moveToEndOfLine:': ('move', {'direction': 'lineEnd'}),
      'moveToBeginningOfDocument:': ('move', {'direction': 'docStart'}),
      'moveToEndOfDocument:': ('move', {'direction': 'docEnd'}),
      'deleteBackward:': ('deleteBackward', {}),
      'deleteForward:': ('deleteForward', {}),
      'deleteWordBackward:': ('deleteWordBackward', {}),
      'deleteWordForward:': ('deleteWordForward', {}),
      'insertNewline:': ('splitBlock', {}),
      'insertLineBreak:': ('hardBreak', {}),
      'selectAll:': ('selectAll', {}),
      'copy:': ('copy', {}),
      'cut:': ('cut', {}),
      'paste:': ('paste', {}),
      'pasteAndMatchStyle:': ('pastePlain', {}),
    };
    final extend = selector.contains('AndModifySelection:');
    final entry = names[selector.replaceFirst('AndModifySelection:', ':')];
    if (entry != null) {
      _perform(entry.$1, {...entry.$2, if (extend) 'extend': true});
    }
  }

  int _wordPosition(bool backward) {
    final doc = widget.controller.state.doc,
        head = widget.controller.state.selection.head;
    final resolved = doc.resolve(head);
    if (!resolved.parent.isTextblock || geometry == null) return head;
    final start = resolved.start(), end = start + resolved.parent.content.size;
    if ((backward && head == start) || (!backward && head == end)) return head;
    var range = geometry!.wordBoundary(backward ? head - 1 : head);
    final from = (range.start - start).clamp(0, resolved.parent.content.size),
        to = (range.end - start).clamp(0, resolved.parent.content.size);
    final text = resolved.parent.content
        .cut(from, to)
        .map((n) => n.text ?? ' ')
        .join();
    if (text.trim().isEmpty) {
      if (backward && range.start > start) {
        range = geometry!.wordBoundary(range.start - 1);
      }
      if (!backward && range.end < end) {
        range = geometry!.wordBoundary(range.end);
      }
    }
    return backward ? math.min(head, range.start) : math.max(head, range.end);
  }

  void _move(String direction, {required bool extend, required bool word}) {
    final controller = widget.controller,
        doc = controller.state.doc,
        selection = controller.state.selection;
    final geometry = this.geometry;
    if (geometry == null) return;
    var target = selection.head;
    final horizontal = direction == 'left' || direction == 'right';
    if (direction.startsWith('scroll')) {
      if (_scroll.hasClients) {
        final position = _scroll.position;
        final next = switch (direction) {
          'scrollStart' => position.minScrollExtent,
          'scrollEnd' => position.maxScrollExtent,
          'scrollPageUp' => _scroll.offset - geometry.viewportSize.height * .9,
          _ => _scroll.offset + geometry.viewportSize.height * .9,
        };
        _reveal = false;
        _scroll.jumpTo(
          next.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      }
      return;
    }
    if (!extend && const {'left', 'right', 'up', 'down'}.contains(direction)) {
      final backward = direction == 'left' || direction == 'up';
      if (selection is m.NodeSelection) {
        var next = m.Selection.beside(
          doc,
          backward ? selection.from : selection.to,
          bias: backward ? -1 : 1,
        );
        if (!horizontal && next is m.TextSelection) {
          _goalX ??= geometry.caretRect(selection.from).left;
          next = m.TextSelection(
            geometry.positionForOffset(
              Offset(_goalX!, geometry.caretRect(next.head).center.dy),
            ),
          );
        }
        controller.setSelection(next);
        requestKeyboard();
        _scheduleGeometry(reveal: true);
        return;
      }
      if (selection is m.GapSelection) {
        final pos = doc.resolve(selection.head);
        final next = backward ? pos.nodeBefore : pos.nodeAfter;
        if (next != null) {
          controller.setSelection(
            next.isAtom
                ? m.NodeSelection(
                    doc,
                    backward ? selection.head - next.nodeSize : selection.head,
                  )
                : m.Selection.near(
                    doc,
                    selection.head,
                    bias: backward ? -1 : 1,
                  ),
          );
          _scheduleGeometry(reveal: true);
          return;
        }
      }
    }
    if (!extend &&
        direction == 'up' &&
        selection.empty &&
        selection is m.TextSelection) {
      final first = m.Selection.near(doc, 0);
      if (geometry.lineBoundary(selection.head).start == first.head &&
          widget.onBoundaryNavigation?.call('up') == true) {
        return;
      }
    }
    final cell = m.tableContext(doc, selection.head);
    if (cell != null &&
        const {'left', 'right', 'up', 'down'}.contains(direction)) {
      final pos = doc.resolve(selection.head),
          line = geometry.lineBoundary(selection.head),
          backward = direction == 'left' || direction == 'up';
      var boundary = horizontal
          ? (backward
                ? pos.parentOffset == 0
                : pos.parentOffset == pos.parent.content.size)
          : (backward ? line.start == pos.start() : line.end >= pos.end());
      for (var d = pos.depth - 1; d > 0; d--) {
        if ((backward ? pos.index(d) : pos.indexAfter(d)) !=
            (backward ? 0 : pos.node(d).childCount)) {
          boundary = false;
        }
        if (pos.node(d).type == 'tableCell' ||
            pos.node(d).type == 'tableHeader') {
          break;
        }
      }
      if (selection is m.CellSelection ||
          boundary &&
              (extend ||
                  !horizontal ||
                  direction == 'left' &&
                      cell.tablePosition == 0 &&
                      cell.rect.top == 0 &&
                      cell.rect.left == 0)) {
        final tr = controller.commands.execute(
          controller.state,
          'arrow${direction[0].toUpperCase()}${direction.substring(1)}',
          {'extend': extend},
        );
        if (tr.selectionSet) {
          controller.apply(tr);
          _scheduleGeometry(reveal: true);
          return;
        }
      }
    }

    if (horizontal && !extend && !selection.empty) {
      target = direction == 'left' ? selection.from : selection.to;
      _goalX = null;
    } else if (horizontal) {
      final backward = direction == 'left', pos = doc.resolve(target);
      if (word) target = _wordPosition(backward);
      if (!word || target == selection.head) {
        if (pos.parent.isTextblock) {
          final text = _inlineText(pos.parent), offset = pos.parentOffset;
          if (backward && offset > 0) {
            target -= text.substring(0, offset).characters.last.length;
          } else if (!backward && offset < text.length) {
            target += text.substring(offset).characters.first.length;
          } else {
            if (m.tableContext(doc, target) != null) {
              controller.setSelection(
                m.Selection.near(
                  doc,
                  (target + (backward ? -1 : 1)).clamp(0, doc.content.size),
                  bias: backward ? -1 : 1,
                ),
              );
              _scheduleGeometry(reveal: true);
              return;
            }
            final other = doc.rowIndexAt(target) + (backward ? -1 : 1);
            if (other < 0 || other >= doc.rowCount) return;
            final row = doc.rowAt(other),
                block = row.node,
                start = row.position;
            target = block.isTextblock
                ? backward
                      ? start + block.nodeSize - 1
                      : start + 1
                : start;
          }
        }
      }
      _goalX = null;
    } else if (direction == 'pageUp' || direction == 'pageDown') {
      final caret = geometry.caretRect(target);
      _goalX ??= caret.left;
      target = geometry.positionForOffset(
        Offset(
          _goalX!,
          caret.center.dy +
              geometry.viewportSize.height *
                  .9 *
                  (direction == 'pageUp' ? -1 : 1),
        ),
      );
    } else if (direction == 'up' || direction == 'down') {
      if (!extend && direction == 'down' && cell == null) {
        final tr = controller.commands.execute(controller.state, 'arrowDown');
        if (tr.docChanged || tr.selectionSet) {
          controller.apply(tr);
          _scheduleGeometry(reveal: true);
          return;
        }
      }
      final caret = geometry.caretRect(target);
      _goalX ??= caret.left;
      final pos = doc.resolve(target), text = widget.style.forBlock(pos.parent);
      final step =
          (text.fontSize ?? 17) *
          (text.height ?? 1.5) *
          (direction == 'up' ? -1 : 1);
      for (var i = 1; i <= 3; i++) {
        target = geometry.positionForOffset(
          Offset(_goalX!, caret.center.dy + step * i),
        );
        if (target != selection.head) break;
      }
    } else {
      _goalX = null;
      target = switch (direction) {
        'lineStart' => geometry.lineBoundary(target).start,
        'lineEnd' => geometry.lineBoundary(target).end,
        'docStart' => 0,
        'docEnd' => doc.content.size,
        _ => target,
      };
    }
    if (extend) {
      controller.setSelection(m.TextSelection(selection.anchor, target));
    } else {
      controller.setSelection(
        m.Selection.near(
          doc,
          target,
          bias: direction == 'left' || direction == 'docEnd' ? -1 : 1,
        ),
      );
    }
    _scheduleGeometry(reveal: true);
  }

  Future<void> _copy({bool cut = false}) async {
    final controller = widget.controller;
    if (controller.state.selection.empty) return;
    final revision = controller.revision;
    await controller.copy(write: widget.onCopyClipboard);
    if (!mounted) return;
    if (cut &&
        !widget.readOnly &&
        identical(controller, widget.controller) &&
        revision == controller.revision) {
      controller.apply(
        controller.commands.execute(controller.state, 'deleteBackward')
          ..setMeta('closeHistory', true),
      );
    }
    _hideContextMenu();
  }

  Future<void> _pastePlain() async {
    if (widget.readOnly) return;
    final controller = widget.controller,
        selection = controller.state.selection;
    await controller.pastePlainText(
      canPaste: () =>
          mounted &&
          !widget.readOnly &&
          identical(controller, widget.controller) &&
          selection == controller.state.selection,
    );
    _hideContextMenu();
  }

  Future<void> _paste() async {
    if (widget.readOnly) return;
    final controller = widget.controller,
        selection = controller.state.selection,
        revision = controller.revision;
    if (await widget.onPasteClipboard?.call() == true) {
      _hideContextMenu();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted ||
        widget.readOnly ||
        !identical(controller, widget.controller) ||
        controller.revision != revision ||
        selection != controller.state.selection) {
      return;
    }
    if (data?.text != null) {
      await controller.paste(
        text: data!.text!,
        onPasteText: widget.onPasteText,
        canPaste: () =>
            mounted &&
            !widget.readOnly &&
            identical(controller, widget.controller),
      );
    }
    _hideContextMenu();
  }
}
