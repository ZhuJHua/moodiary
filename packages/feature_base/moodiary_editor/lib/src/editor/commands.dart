part of '../moodiary_editor.dart';

const _tableCommands = {
  EditorCommand.tableAddRowAfter: 'addRowAfter',
  EditorCommand.tableDeleteRow: 'deleteRow',
  EditorCommand.tableAddColumnAfter: 'addColumnAfter',
  EditorCommand.tableDeleteColumn: 'deleteColumn',
  EditorCommand.tableToggleHeaderRow: 'toggleHeaderRow',
  EditorCommand.tableDelete: 'deleteTable',
};

extension _HostCommands on MoodiaryEditorHost {
  Future<void> _executeCommand(
    EditorCommand command,
    Map<String, Object?>? args,
  ) async {
    final a = args ?? const <String, Object?>{};
    const safe = {
      EditorCommand.openLink,
      EditorCommand.copyLink,
      EditorCommand.previewImage,
      EditorCommand.openAttachment,
      EditorCommand.copyCode,
      EditorCommand.search,
      EditorCommand.searchNext,
      EditorCommand.searchPrev,
      EditorCommand.clearSearch,
    };
    if (readOnly && !safe.contains(command)) return;
    _restore();
    if (const {
          EditorCommand.insertTable,
          EditorCommand.insertDiaryLink,
          EditorCommand.setLink,
        }.contains(command) &&
        editor.state.selection is ft.NodeSelection) {
      editor.exec('caretAfterNode');
    }
    final rule = _adjacentRule();
    if (rule != null &&
        const {
          EditorCommand.moveBlockUp,
          EditorCommand.moveBlockDown,
          EditorCommand.deleteBlock,
        }.contains(command)) {
      editor.setSelection(ft.NodeSelection(editor.state.doc, rule));
    }
    final selected = editor.state.selection is ft.NodeSelection
        ? editor.state.doc.nodeAt(editor.state.selection.from)
        : null;
    if (_tableCommands.containsKey(command) && !editor.state.toolbar.inTable) {
      return;
    }
    switch (command) {
      case EditorCommand.search:
        editor.startSearch(
          a['query'] as String? ?? '',
          caseSensitive: a['caseSensitive'] == true,
        );
        await editor.searchComplete;
      case EditorCommand.searchNext:
        editor.findNext();
      case EditorCommand.searchPrev:
        editor.findPrev();
      case EditorCommand.replace:
        editor.replaceCurrent(a['text'] as String? ?? '');
      case EditorCommand.replaceAll:
        await editor.replaceAll(a['text'] as String? ?? '');
      case EditorCommand.clearSearch:
        editor.clearSearch();
        _search.value = null;
      case EditorCommand.openLink:
        final link = state.value.link;
        if (link != null) _configuration.onUrlTap?.call(link.href);
      case EditorCommand.copyLink:
        final link = state.value.link;
        if (link != null) {
          await Clipboard.setData(ClipboardData(text: link.href));
        }
      case EditorCommand.copyCode:
        final parent = editor.state.doc
            .resolve(editor.state.selection.from)
            .parent;
        if (parent.type == 'codeBlock') {
          await Clipboard.setData(ClipboardData(text: parent.textContent));
        }
      case EditorCommand.previewImage:
        if (selected?.type == 'image') {
          previewImage(editor.state.selection.from);
        }
      case EditorCommand.openAttachment:
        if (selected?.type == 'attachment') {
          _configuration.onAttachmentTap?.call(
            selected!.attrs['src'] as String? ?? '',
            selected.attrs['name'] as String? ?? '',
            selected.attrs['mime'] as String?,
          );
        }
      case EditorCommand.previewMediaWidth:
        editor.previewNodeWidth((a['percent'] as num?)?.round());
      case EditorCommand.insertImage ||
          EditorCommand.insertVideo ||
          EditorCommand.insertAudio ||
          EditorCommand.insertAttachment:
        final name = a['name'];
        if (name is! String || name.isEmpty) return;
        editor.exec('insertAtomBlock', {
          'type': switch (command) {
            EditorCommand.insertImage => 'image',
            EditorCommand.insertVideo => 'video',
            EditorCommand.insertAudio => 'audio',
            _ => 'attachment',
          },
          'attrs': {
            'src': name,
            'name': a['displayName'],
            if (command == EditorCommand.insertAttachment) ...{
              'mime': a['mime'],
              'size': a['size'],
            },
          },
        });
      case EditorCommand.toggleBold ||
          EditorCommand.toggleItalic ||
          EditorCommand.toggleUnderline ||
          EditorCommand.toggleStrike ||
          EditorCommand.toggleCode ||
          EditorCommand.toggleHighlight:
        editor.exec('toggleMark', {
          'type': command.name.substring(6).toLowerCase(),
        });
      case EditorCommand.setHeading:
        editor.exec('toggleHeading', Map<String, dynamic>.from(a));
      case EditorCommand.indent:
        editor.exec('sinkListItem');
      case EditorCommand.outdent:
        editor.exec('liftListItem');
      case EditorCommand.insertHorizontalRule:
        editor.exec('insertAtomBlock', {
          'type': 'horizontalRule',
          'attrs': {'variant': a['variant'] ?? 'solid', 'label': null},
        });
      case EditorCommand.setHorizontalRule:
        if (selected?.type == 'horizontalRule') {
          editor.exec('setHorizontalRule', Map<String, dynamic>.from(a));
        } else if (rule != null) {
          final tr = editor.state.tr;
          for (final entry in a.entries) {
            tr.step(ft.AttrStep(rule, entry.key, entry.value));
          }
          editor.apply(tr);
        }
      case EditorCommand.insertDiaryLink:
        editor.exec('insertText', {'text': '[['});
      case EditorCommand.exitCode:
        final pos = editor.state.doc.resolve(editor.state.selection.from);
        if (pos.parent.type == 'codeBlock') {
          final after = pos.after(),
              next = editor.state.doc.nodeAt(after),
              tr = editor.state.tr;
          if (next?.type != 'paragraph' || next!.content.isNotEmpty) {
            tr.replace(
              after,
              after,
              ft.Slice(
                ft.Fragment([editor.state.doc.schema.node('paragraph')]),
                0,
                0,
              ),
            );
          }
          tr.setSelection(ft.TextSelection(after + 1));
          editor.apply(tr);
        }
      case EditorCommand.insertBlockquote:
        _insertContainer('blockquote');
      case EditorCommand.insertCodeBlock:
        _insertContainer('codeBlock');
      case EditorCommand.insertTaskList:
        _insertContainer('taskList');
      default:
        editor.exec(
          _tableCommands[command] ?? command.name,
          Map<String, dynamic>.from(a),
        );
    }
    const noFocus = {
      ...safe,
      EditorCommand.undo,
      EditorCommand.redo,
      EditorCommand.replace,
      EditorCommand.replaceAll,
      EditorCommand.previewMediaWidth,
    };
    if (!_panelMode && !noFocus.contains(command)) await focus();
  }

  void _insertContainer(String type) {
    final pos = editor.state.doc.resolve(editor.state.selection.from);
    if (pos.parent.type == 'paragraph' && pos.parent.content.isEmpty) {
      editor.exec(
        type == 'blockquote'
            ? 'toggleBlockquote'
            : type == 'codeBlock'
            ? 'setCodeBlock'
            : 'toggleTaskList',
      );
      return;
    }
    final schema = editor.state.doc.schema, node = schema.createAndFill(type)!;
    var depth = pos.depth;
    for (; depth > 1; depth--) {
      final parent = pos.node(depth - 1), index = pos.index(depth - 1);
      if (parent.canReplace(index + 1, index + 1, ft.Fragment([node]))) break;
    }
    final at = editor.state.selection is ft.NodeSelection
        ? editor.state.selection.to
        : depth > 0
        ? pos.after(depth)
        : pos.pos;
    final tr = editor.state.tr.replace(
      at,
      at,
      ft.Slice(ft.Fragment([node]), 0, 0),
    );
    if (tr.doc.blocks.last.type != 'paragraph') {
      final end = tr.doc.content.size;
      tr.replace(
        end,
        end,
        ft.Slice(ft.Fragment([schema.node('paragraph')]), 0, 0),
      );
    }
    tr.setSelection(ft.Selection.near(tr.doc, at + 1));
    editor.apply(tr);
  }
}
