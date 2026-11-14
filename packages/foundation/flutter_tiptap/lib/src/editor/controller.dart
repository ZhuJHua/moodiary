part of '../editor.dart';

/// Layout counters for inspecting viewport work and per-node cache reuse.
@visibleForTesting
class TiptapDiagnostics {
  int blockLayouts = 0;
  int paragraphLayouts = 0;
  int fullDocumentScans = 0;
  int visibleBlocks = 0;
  int cachedLayouts = 0;
  int cachedTextLength = 0;
  final Expando<int> _nodeLayouts = Expando<int>();
  int layoutsFor(m.Node node) => _nodeLayouts[node] ?? 0;
  void _record(m.Node node, int index) {
    blockLayouts++;
    _nodeLayouts[node] = (_nodeLayouts[node] ?? 0) + 1;
  }
}

/// The conversion applied to pasted text before insertion.
enum TiptapPasteConversion { markdown, richText }

/// Owns editor state, commands, search and reference suggestions.
/// Listeners run synchronously; document change callbacks run once per frame.
class TiptapController extends ChangeNotifier {
  /// Creates an editor from a state or document, or an empty paragraph.
  TiptapController({
    m.EditorState? state,
    m.Node? doc,
    m.Schema? schema,
    this.onChanged,
    this.referenceCandidates,
    this.commands = const m.EditorCommands(trailingParagraph: true),
  }) {
    final s = schema ?? doc?.schema ?? m.Schema.standard();
    _state =
        state ??
        m.EditorState(
          doc: doc ?? s.node('doc', content: [s.node('paragraph')]),
        );
    _toolbar = ValueNotifier(_state.toolbar);
  }
  final ChangeNotifier _searchRepaint = ChangeNotifier();
  final ChangeNotifier _nodeHeights = ChangeNotifier();
  Set<m.Node> _invalidatedNodeHeights = {};
  void invalidateNodeHeights(Iterable<m.Node> nodes) {
    _invalidatedNodeHeights = nodes.toSet();
    try {
      _nodeHeights.notifyListeners();
    } finally {
      _invalidatedNodeHeights = {};
    }
  }

  void _searchNotify() => _searchRepaint.notifyListeners();
  m.SearchIndex _searchIndex = m.SearchIndex();
  m.Node? _searchDoc;
  (int, int) _searchVisible = (0, 0);
  int _searchGeneration = 0;
  List<m.SearchMatch> _searchMatches = [];
  Future<void> _searchDone = Future.value();
  final ValueNotifier<m.SearchStatus> _searchStatus = ValueNotifier(
    const m.SearchStatus(),
  );

  /// Search progress and the active match for a host search interface.
  ValueListenable<m.SearchStatus> get searchStatus => _searchStatus;

  /// Completes when the current yielded search scan finishes.
  Future<void> get searchComplete => _searchDone;

  /// Starts a literal search and selects its first match after scanning.
  void startSearch(String query, {bool caseSensitive = false}) {
    _searchIndex = m.SearchIndex(query: query, caseSensitive: caseSensitive);
    _searchDoc = null;
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    _startSearchScan();
    // Selection navigation follows the same yielded scan, never a synchronous
    // whole-document query on the input callback.
    final generation = _searchGeneration;
    unawaited(
      _searchDone.then((_) {
        if (!_disposed && generation == _searchGeneration) {
          apply(_searchIndex.start(state));
        }
      }),
    );
  }

  void _withSearchReady(VoidCallback action) {
    if (_searchStatus.value.complete) {
      action();
      return;
    }
    final generation = _searchGeneration;
    unawaited(
      _searchDone.then((_) {
        if (!_disposed && generation == _searchGeneration) action();
      }),
    );
  }

  /// Selects the next match, wrapping at the end of the document.
  void findNext() => _withSearchReady(() => apply(_searchIndex.next(state)));

  /// Selects the previous match, wrapping at the start of the document.
  void findPrev() =>
      _withSearchReady(() => apply(_searchIndex.next(state, backwards: true)));

  /// Replaces the active search match.
  void replaceCurrent(String text) =>
      _withSearchReady(() => apply(_searchIndex.replaceCurrent(state, text)));

  /// Replaces every match after the current scan has finished.
  Future<void> replaceAll(String text) async {
    final generation = _searchGeneration;
    await _searchDone;
    if (_disposed || generation != _searchGeneration) return;
    final before = state.doc, revision = _revision;
    final tr = await _searchIndex.replaceAllAsync(
      state,
      text,
      matches: _searchMatches,
    );
    if (!_disposed && identical(before, state.doc) && revision == _revision) {
      apply(tr);
    }
  }

  /// Cancels scanning and clears search highlights.
  void clearSearch() {
    _searchGeneration++;
    _searchDone = Future.value();
    _searchIndex = m.SearchIndex();
    _searchDoc = null;
    _searchMatches = [];
    _searchStatus.value = const m.SearchStatus();
    _searchNotify();
  }

  /// Supplies candidates for the active reference query.
  final TiptapReferenceCandidates? referenceCandidates;
  final ValueNotifier<TiptapReferenceSuggestion?> _suggestion = ValueNotifier(
    null,
  );

  /// Reference popup state, or null when no suggestion is active.
  ValueListenable<TiptapReferenceSuggestion?> get suggestion => _suggestion;
  Timer? _suggestionTimer;
  TiptapCancellation? _suggestionCancellation;
  String? _suggestionKey, _dismissedSuggestion;
  Rect _suggestionRect = Rect.zero;

  void _refreshSuggestion() {
    final match = _state.selection.empty && _composing.isCollapsed
        ? m.findReferenceMatch(_state.doc, _state.selection.head)
        : null;
    final key = match == null
        ? null
        : '${match.from}:${match.to}:${match.query}';
    if (key == _suggestionKey) return;
    _suggestionKey = key;
    _suggestionTimer?.cancel();
    _suggestionCancellation?._cancel();
    if (match == null || key == _dismissedSuggestion) {
      _suggestion.value = null;
      return;
    }
    final cancellation = _suggestionCancellation = TiptapCancellation();
    _suggestion.value = TiptapReferenceSuggestion(
      match: match,
      caretRect: _suggestionRect,
    );
    _suggestionTimer = Timer(const Duration(milliseconds: 200), () async {
      List<TiptapReferenceItem> items;
      try {
        items =
            await referenceCandidates?.call(match.query.trim(), cancellation) ??
            [];
      } catch (_) {
        items = [];
      }
      if (_disposed || cancellation.cancelled) return;
      _suggestion.value = TiptapReferenceSuggestion(
        match: match,
        caretRect: _suggestionRect,
        items: List.unmodifiable(items),
        loading: false,
      );
    });
  }

  /// Hides suggestions until the current reference query changes.
  void dismissReferenceSuggestion() {
    _dismissedSuggestion = _suggestionKey;
    _suggestionTimer?.cancel();
    _suggestionCancellation?._cancel();
    _suggestion.value = null;
  }

  /// Handles Escape, Enter and arrow navigation; returns whether consumed.
  bool handleReferenceSuggestionKey(String key) {
    final active = _suggestion.value;
    if (active == null) return false;
    if (key == 'Escape') {
      dismissReferenceSuggestion();
      return true;
    }
    if (active.items.isEmpty) return false;
    if (key == 'Enter') {
      insertReference(active.items[active.selectedIndex]);
      return true;
    }
    if (key != 'ArrowUp' && key != 'ArrowDown') return false;
    _suggestion.value = TiptapReferenceSuggestion(
      match: active.match,
      caretRect: active.caretRect,
      items: active.items,
      loading: active.loading,
      selectedIndex:
          (active.selectedIndex + (key == 'ArrowUp' ? -1 : 1)) %
          active.items.length,
    );
    return true;
  }

  /// Replaces the current reference query or selection with a reference chip.
  void insertReference(TiptapReferenceItem item) =>
      exec('insertReference', {'id': item.id, 'label': item.label});

  void _updateHostGeometry(TiptapGeometry geometry) {
    final selection = state.selection;
    _suggestionRect = geometry.caretRect(selection.head);
    final active = _suggestion.value;
    if (active != null && active.caretRect != _suggestionRect) {
      _suggestion.value = TiptapReferenceSuggestion(
        match: active.match,
        caretRect: _suggestionRect,
        items: active.items,
        selectedIndex: active.selectedIndex,
        loading: active.loading,
      );
    }
  }

  /// Copies the selected slice as text and HTML, optionally cutting it.
  /// Supply [write] to use a host clipboard that supports HTML.
  Future<void> copy({
    bool cut = false,
    Future<void> Function(String text, String html)? write,
  }) async {
    final revision = _revision;
    if (state.selection.empty) return;
    final codec = m.TiptapHtmlCodec(state.doc.schema);
    final selection = state.selection;
    final text = codec.plainText(
      state.doc,
      from: selection.from,
      to: selection.to,
    );
    _clipboardText = text;
    _clipboardSlice = state.doc.slice(selection.from, selection.to);
    final html = codec.serializeSlice(_clipboardSlice!);
    _clipboardHtml = html;
    if (write == null) {
      await Clipboard.setData(ClipboardData(text: text));
    } else {
      await write(text, html);
    }
    if (!_disposed && cut && revision == _revision) {
      apply(
        commands.execute(state, 'deleteBackward')
          ..setMeta('closeHistory', true),
      );
    }
  }

  /// Native HTML clipboard input. Internal content retains its original slice.
  Future<void> pasteHtml(
    String html, {
    String? text,
    TiptapPasteText? onPasteText,
  }) async {
    if (_disposed) return;
    final inCode =
        state.doc.resolve(state.selection.from).parent.type == 'codeBlock';
    if (inCode) {
      exec('pasteText', {
        'text': text?.isNotEmpty == true
            ? text!
            : m.TiptapHtmlCodec(state.doc.schema)
                  .parse(html)
                  .rows()
                  .map((r) => r.node.textContent)
                  .join('\n'),
      });
    } else if (html == _clipboardHtml &&
        text == _clipboardText &&
        _clipboardSlice != null) {
      await paste(text: text);
    } else {
      final slice = m.TiptapHtmlCodec(state.doc.schema).parseSlice(html);
      final applyPasteRules = !html.contains('data-pm-slice');
      final plain = slice.content.every(_isPlain);
      // Some sources wrap their plain text in HTML without any formatting.
      if (text != null && onPasteText != null && plain) {
        final revision = _revision;
        final json = await onPasteText(text);
        if (_disposed || revision != _revision) return;
        if (json != null) {
          _pasteDocument(json, text, applyPasteRules: applyPasteRules);
          return;
        }
      }
      if (text?.isNotEmpty == true && !plain) {
        _pasteConverted(
          slice,
          text!,
          TiptapPasteConversion.richText,
          applyPasteRules: applyPasteRules,
        );
      } else {
        exec('pasteSlice', {
          'slice': slice,
          'applyPasteRules': applyPasteRules,
        });
      }
    }
  }

  bool _isCopied(String text) =>
      text == _clipboardText && _clipboardSlice != null;

  bool _pasteCopied(String text) {
    if (!_isCopied(text)) return false;
    final source = _clipboardSlice!;
    final slice = m.Slice(
      m.Fragment(
        source.content.map((node) => state.doc.schema.fromJson(node.toJson())),
      ),
      source.openStart,
      source.openEnd,
    );
    exec('pasteSlice', {'slice': slice, 'applyPasteRules': false});
    return true;
  }

  bool _isPlain(m.Node node) =>
      node.type == 'hardBreak' ||
      node.isText && node.marks.isEmpty ||
      node.type == 'paragraph' && node.content.every(_isPlain);

  // A lone paragraph joins the text around the caret.
  void _pasteDocument(
    Map<String, dynamic> json,
    String text, {
    bool applyPasteRules = true,
  }) {
    final doc = state.doc.schema.fromJson(json);
    final open = doc.childCount == 1 && doc.child(0).type == 'paragraph'
        ? 1
        : 0;
    _pasteConverted(
      m.Slice(doc.content, open, open),
      text,
      TiptapPasteConversion.markdown,
      applyPasteRules: applyPasteRules,
    );
  }

  void _pasteConverted(
    m.Slice slice,
    String text,
    TiptapPasteConversion conversion, {
    bool applyPasteRules = true,
  }) {
    apply(
      commands.execute(state, 'pasteSlice', {
        'slice': slice,
        'applyPasteRules': applyPasteRules,
      })..setMeta('closeHistory', true),
    );
    _convertedText = text;
    onPasteConverted?.call(conversion);
  }

  /// Replaces the last converted paste with the text it came from.
  void restorePastedText() {
    final text = _convertedText;
    if (text == null) return;
    _convertedText = null;
    exec('undo');
    exec('pasteText', {'text': text, 'plain': true});
  }

  /// Pastes the clipboard's text with no conversion.
  Future<void> pastePlainText({String? text, bool Function()? canPaste}) async {
    final revision = _revision;
    text ??= (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (_disposed ||
        revision != _revision ||
        text == null ||
        canPaste?.call() == false) {
      return;
    }
    exec('pasteText', {'text': text, 'plain': true});
  }

  /// Pastes text or a copied internal slice, with optional text conversion.
  /// [canPaste] guards insertion when asynchronous clipboard work finishes.
  Future<void> paste({
    TiptapPasteText? onPasteText,
    String? text,
    bool Function()? canPaste,
  }) async {
    final revision = _revision;
    text ??= (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (_disposed ||
        revision != _revision ||
        text == null ||
        canPaste?.call() == false) {
      return;
    }
    if (_pasteCopied(text)) return;
    if (onPasteText != null &&
        state.doc.resolve(state.selection.from).parent.type != 'codeBlock') {
      final json = await onPasteText(text);
      if (_disposed || revision != _revision || canPaste?.call() == false) {
        return;
      }
      if (json != null) {
        _pasteDocument(json, text);
        return;
      }
    }
    exec('pasteText', {'text': text});
  }

  late m.EditorState _state;
  late final ValueNotifier<m.ToolbarState> _toolbar;

  /// Command implementation used by [exec].
  final m.EditorCommands commands;

  /// Document changes are delivered once per frame; state listeners remain synchronous.
  ValueChanged<m.EditorState>? onChanged;

  /// Called when pasted text was converted, so a host can offer
  /// [restorePastedText].
  ValueChanged<TiptapPasteConversion>? onPasteConverted;
  String? _convertedText;

  /// Layout counters populated by the attached editor viewport.
  @visibleForTesting
  final TiptapDiagnostics diagnostics = TiptapDiagnostics();
  m.Transaction? _lastTransaction;
  TextRange _composing = TextRange.empty;
  int _revision = 0;
  bool _disposed = false;

  /// The current immutable document, selection and history.
  m.EditorState get state => _state;

  /// The table context at the selection head, if any.
  m.TableContext? get table => m.tableContext(state.doc, state.selection.head);

  /// Whether the selection head is inside a table.
  bool get inTable => table != null;

  /// The enclosing table cell's document position, if any.
  @visibleForTesting
  int? get cellPosition => table?.cellPosition;

  /// The last applied transaction; null after replacing the document.
  m.Transaction? get lastTransaction => _lastTransaction;

  /// Selection formatting and command availability for host toolbars.
  ValueListenable<m.ToolbarState> get toolbar => _toolbar;

  /// The current IME composing range in document coordinates.
  TextRange get composing => _composing;

  /// A counter incremented on every state update.
  int get revision => _revision;

  /// Serializes the current document as ProseMirror JSON.
  String get json => _state.doc.toJsonString();
  bool _changePending = false;
  void _notifyChange() {
    if (_changePending || onChanged == null) return;
    _changePending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _changePending = false;
      if (!_disposed) onChanged?.call(_state);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  ({m.Node node, int percent})? _widthPreview;

  /// Previews a selected image or video width without changing the document.
  /// Pass null to clear the preview; values are clamped to 25–100 percent.
  void previewNodeWidth(int? percent) {
    final selection = state.selection;
    final node = selection is m.NodeSelection
        ? state.doc.nodeAt(selection.from)
        : null;
    _widthPreview = percent == null || node == null || !m.isResizableMedia(node)
        ? null
        : (node: node, percent: m.clampWidthPercent(percent)!);
    notifyListeners();
  }

  /// Executes a named command and applies its transaction.
  m.Transaction exec(String name, [Map<String, dynamic> args = const {}]) {
    final transaction = commands.execute(_state, name, args);
    apply(transaction);
    return transaction;
  }

  /// Applies a transaction and updates listeners, suggestions and search.
  void apply(m.Transaction transaction) {
    if (_disposed) throw StateError('Controller is disposed');
    _widthPreview = null;
    _state = _state.apply(transaction);
    _lastTransaction = transaction;
    _revision++;
    if (_composing.isValid && !transaction.composing) {
      _composing = TextRange.empty;
    }
    final next = _state.toolbar, old = _toolbar.value;
    if (next != old) _toolbar.value = next;
    _refreshSuggestion();
    _refreshSearch();
    notifyListeners();
    if (transaction.docChanged) _notifyChange();
  }

  /// Updates the selection without changing the document.
  void setSelection(m.Selection selection) =>
      apply(_state.tr.setSelection(selection));

  /// Replaces the document and resets selection, history and composition.
  void replaceDocument(m.Node doc) {
    _state = m.EditorState(doc: doc);
    _lastTransaction = null;
    _composing = TextRange.empty;
    _revision++;
    _toolbar.value = _state.toolbar;
    _refreshSuggestion();
    _refreshSearch();
    notifyListeners();
    _notifyChange();
  }

  void _setComposing(TextRange range) {
    if (_composing == range) return;
    _composing = range;
    _refreshSuggestion();
    _refreshSearch();
    notifyListeners();
  }

  /// Plain text for the selected range, including reference labels.
  String get selectedText => selectedTextPrefix();

  String selectedTextPrefix({int? maxLength}) {
    final doc = _state.doc, selection = _state.selection;
    if (selection.empty) return '';
    final from = doc.rowIndexAt(selection.from),
        to = doc.rowIndexAt(selection.to - 1);
    final result = StringBuffer();
    var first = true;
    void append(String text) {
      final remaining = maxLength == null
          ? text.length
          : math.max(0, maxLength - result.length);
      result.write(
        text.length <= remaining ? text : text.substring(0, remaining),
      );
    }

    for (final row in doc.rows(
      from: from,
      to: math.min(to + 1, doc.rowCount),
    )) {
      if (!first) append('\n');
      first = false;
      final block = row.node;
      if (!block.isTextblock) {
        append('\ufffc');
      } else {
        final start = row.position + 1;
        var offset = 0;
        for (final inline in block.content) {
          final end = offset + inline.nodeSize;
          if (end > selection.from - start && offset < selection.to - start) {
            append(
              inline.isText
                  ? inline.text!.substring(
                      (selection.from - start - offset).clamp(
                        0,
                        inline.nodeSize,
                      ),
                      (selection.to - start - offset).clamp(0, inline.nodeSize),
                    )
                  : inline.type == 'hardBreak'
                  ? '\n'
                  : inline.type == m.referenceNodeType
                  ? (inline.attrs['label'] ?? inline.attrs['id'] ?? '')
                        .toString()
                  : '\ufffc',
            );
          }
          offset = end;
          if (offset >= selection.to - start ||
              maxLength != null && result.length >= maxLength) {
            break;
          }
        }
      }
      if (maxLength != null && result.length >= maxLength) break;
    }
    return result.toString();
  }

  /// Multi-line text committed by an IME, as a keyboard's clipboard panel does.
  void insertCommittedLines(String text, TiptapPasteText? onPasteText) {
    if (_pasteCopied(text)) return;
    final inCode =
        state.doc.resolve(state.selection.from).parent.type == 'codeBlock';
    // IME input is applied synchronously, so an async hook cannot take part.
    final json = inCode ? null : onPasteText?.call(text);
    if (json is Map<String, dynamic>) {
      _pasteDocument(json, text);
    } else {
      insertPlainText(text);
    }
  }

  /// Inserts literal text with line breaks grouped into one undo event.
  void insertPlainText(String text) {
    apply(
      commands.execute(_state, 'insertCommittedLines', {
        'text': text,
        'composition': 'paste-${developer.Timeline.now}',
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _suggestionTimer?.cancel();
    _suggestionCancellation?._cancel();
    _searchGeneration++;
    _searchStatus.dispose();
    _searchRepaint.dispose();
    _nodeHeights.dispose();
    _suggestion.dispose();
    _toolbar.dispose();
    super.dispose();
  }
}
