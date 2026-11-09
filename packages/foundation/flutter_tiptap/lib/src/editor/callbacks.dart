part of '../editor.dart';

/// Builds a widget for a document node at its current layout position.
typedef TiptapNodeViewBuilder = Widget Function(
  BuildContext context,
  TiptapNodeView node,
);

/// Estimates a custom node's height before its widget is laid out.
typedef TiptapNodeHeightEstimator = double? Function(m.Node node, double width);

/// Converts pasted text to document JSON, or returns null to paste the text.
typedef TiptapPasteText = FutureOr<Map<String, dynamic>?> Function(String text);

/// Loads reference candidates with a cancellation signal for superseded requests.
typedef TiptapReferenceCandidates = Future<List<TiptapReferenceItem>> Function(
  String query,
  TiptapCancellation cancellation,
);

/// A node and layout context passed to a custom node view builder.
class TiptapNodeView {
  const TiptapNodeView({
    required this.node,
    required this.position,
    required this.selected,
    required this.width,
    required this.updateAttrs,
  });
  final m.Node node;
  final int position;
  final bool selected;
  final double width;
  final ValueChanged<Map<String, Object?>> updateAttrs;
}

/// The selected node and its bounds in editor viewport coordinates.
class TiptapSelectedNode {
  const TiptapSelectedNode(this.node, this.position, this.rect);
  final m.Node node;
  final int position;

  /// Coordinates in the editor viewport.
  final Rect rect;
  String get type => node.type;
  Map<String, Object?> get attrs => node.attrs;
}

/// A reference target with a stored identifier and display label.
class TiptapReferenceItem {
  const TiptapReferenceItem({required this.id, required this.label});
  final String id, label;
}

/// Signals that an asynchronous reference request is no longer needed.
class TiptapCancellation {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  final Completer<void> _signal = Completer<void>();
  Future<void> get whenCancelled => _signal.future;
  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _signal.complete();
  }
}

/// The current reference query, candidate list and popup anchor.
class TiptapReferenceSuggestion {
  const TiptapReferenceSuggestion({
    required this.match,
    required this.caretRect,
    this.items = const [],
    this.selectedIndex = 0,
    this.loading = true,
  });
  final m.ReferenceMatch match;
  final Rect caretRect;
  final List<TiptapReferenceItem> items;
  final int selectedIndex;
  final bool loading;
  String get query => match.query;
  int get from => match.from;
  int get to => match.to;
}

String? _clipboardText, _clipboardHtml;
m.Slice? _clipboardSlice;
