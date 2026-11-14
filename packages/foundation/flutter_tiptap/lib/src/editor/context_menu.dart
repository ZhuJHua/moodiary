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
    this.cut,
    required this.copy,
    required this.paste,
    required this.selectAll,
    required this.hide,
  });
  final Offset anchorAbove, anchorBelow;
  final VoidCallback? cut, copy, paste, selectAll;
  final VoidCallback hide;
}

extension _ContextMenu on TiptapEditorState {
  Future<void> _copyFromMenu({bool cut = false}) async {
    final controller = widget.controller;
    final revision = controller.revision;
    final didCut = await _copy(cut: cut);
    if (!mounted ||
        defaultTargetPlatform != TargetPlatform.android ||
        !identical(controller, widget.controller) ||
        (cut ? !didCut : controller.revision != revision)) {
      return;
    }
    controller.setSelection(
      m.Selection.near(
        controller.state.doc,
        controller.state.selection.to,
        bias: -1,
      ),
    );
  }

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
    final details = TiptapContextMenuDetails(
      anchorAbove: above,
      anchorBelow: below,
      cut: selection.empty || widget.readOnly
          ? null
          : () => unawaited(_copyFromMenu(cut: true)),
      copy: selection.empty ? null : () => unawaited(_copyFromMenu()),
      paste: widget.readOnly ? null : () => unawaited(_paste()),
      selectAll: _selectsAll ? null : _selectAllFromMenu,
      hide: _hideContextMenu,
    );
    final actions = <(String, VoidCallback)>[
      if (details.cut case final cut?) (strings.cutButtonLabel, cut),
      if (details.copy case final copy?) (strings.copyButtonLabel, copy),
      if (details.paste case final paste?) (strings.pasteButtonLabel, paste),
      if (details.selectAll case final selectAll?)
        (strings.selectAllButtonLabel, selectAll),
    ];
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
}
