part of '../model.dart';

/// Persisted node type for inline references in JSON and HTML.
const referenceNodeType = 'diaryLink';

/// The document range and query of an active reference trigger.
class ReferenceMatch {
  const ReferenceMatch(this.from, this.to, this.query);
  final int from, to;
  final String query;
}

/// Finds a reference trigger immediately before a text caret.
ReferenceMatch? findReferenceMatch(Node doc, int position) {
  final pos = doc.resolve(position), before = doc.resolve(position).nodeBefore;
  if (before == null ||
      !before.isText ||
      !pos.parent.isTextblock ||
      pos.parent.type == 'codeBlock') {
    return null;
  }
  final text = before.text!;
  var at = -1;
  for (final trigger in ['[[', '【【', '「「']) {
    at = math.max(at, text.lastIndexOf(trigger));
  }
  if (at < 0) return null;
  final query = text.substring(at + 2);
  if (query.length > 40 || RegExp(r'[\]】」\n]').hasMatch(query)) return null;
  return ReferenceMatch(position - text.length + at, position, query);
}

extension _ReferenceCommands on EditorCommands {
  void _insertReference(Transaction tr, Map<String, dynamic> args) {
    _leaveSelectedAtom(EditorState(doc: tr.doc, selection: tr.selection), tr);
    final match = findReferenceMatch(tr.doc, tr.selection.from);
    final from = args['from'] as int? ?? match?.from ?? tr.selection.from;
    var to = args['to'] as int? ?? match?.to ?? tr.selection.to;
    if (tr.doc.resolve(to).nodeAfter?.text?.startsWith(' ') == true) to++;
    final schema = tr.doc.schema;
    tr.replace(
      from,
      to,
      Slice(
        Fragment([
          schema.node(
            referenceNodeType,
            attrs: {'id': args['id'], 'label': args['label']},
          ),
          schema.node('text', text: ' '),
        ]),
        0,
        0,
      ),
    );
    tr.setSelection(TextSelection(from + 2));
  }
}
