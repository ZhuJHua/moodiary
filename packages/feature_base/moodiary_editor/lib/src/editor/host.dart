part of '../moodiary_editor.dart';

const _asyncLoadThreshold = 64 * 1024;

final _titleLineBreak = RegExp('\r\n|[\r\n\u2028\u2029]');

String _singleLineTitle(String title) => title.replaceAll(_titleLineBreak, ' ');

typedef _LoadedDocument = ({ft.Node doc, String? error, TiptapContent source});

_LoadedDocument _loadDocument(String content) {
  final schema = ft.Schema.standard();
  final source = TiptapContent.parse(content);
  try {
    final json = source.document;
    ft.Node doc;
    if (json != null) {
      if (json['type'] != 'doc') {
        throw const FormatException('Expected document');
      }
      final v = (json['attrs'] as Map?)?['v'];
      doc = schema.fromJson(json);
      void validate(ft.Node node) {
        if (node.isOpaque ||
            !node.isLeaf && !schema.validContent(node.type, node.content)) {
          throw FormatException('Invalid node: ${node.type}');
        }
        for (final child in node.content) {
          validate(child);
        }
      }

      validate(doc);
      if (v is num && v > 2) {
        throw const FormatException('Newer document schema');
      }
    } else {
      if (content.trimLeft().startsWith('{')) {
        throw const FormatException('Expected document');
      }
      doc = schema.node(
        'doc',
        content: [
          for (final line in content.split('\n'))
            schema.node(
              'paragraph',
              content: [if (line.isNotEmpty) schema.node('text', text: line)],
            ),
        ],
      );
    }
    return (doc: doc, error: null, source: source);
  } catch (error) {
    final message = error.toString();
    // Keep readable portions without ever replacing the persisted source.
    try {
      final raw = jsonDecode(content);
      if (raw is Map && raw['type'] == 'doc') {
        final parsed = schema.fromJson(raw.cast<String, dynamic>());
        bool valid(ft.Node n) =>
            !n.isOpaque &&
            (n.isLeaf || schema.validContent(n.type, n.content)) &&
            n.content.every(valid);
        if (valid(parsed)) return (doc: parsed, error: message, source: source);
        return (
          error: message,
          source: source,
          doc: schema.node(
            'doc',
            content: [
              schema.node(
                'paragraph',
                content: [
                  if (parsed.textContent.isNotEmpty)
                    schema.node('text', text: parsed.textContent),
                ],
              ),
            ],
          ),
        );
      }
    } catch (_) {}
    return (
      error: message,
      source: source,
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              if (content.isNotEmpty) schema.node('text', text: content),
            ],
          ),
        ],
      ),
    );
  }
}

Future<_LoadedDocument> _loadDocumentAsync(String content) =>
    Isolate.run(() => _loadDocument(content));

TiptapMetadata _documentMetadata(
  ft.Node? doc,
  TiptapContent? source,
  String? contentText,
  bool useRenderedContent,
) {
  final rendered = source == null || useRenderedContent
      ? TiptapContent.fromDocument(doc!.toJson())
      : null;
  return (source ?? rendered!).metadata(
    contentText: contentText,
    renderedContent: rendered,
  );
}

Future<TiptapMetadata> _documentMetadataAsync(
  ft.Node? doc,
  TiptapContent? source,
  String? contentText,
  bool useRenderedContent,
) => Isolate.run(
  () => _documentMetadata(doc, source, contentText, useRenderedContent),
);

Future<TiptapMetadata> _metadataForContentText(
  TiptapMetadata metadata,
  String? contentText,
) async => (contentText?.length ?? 0) >= _asyncLoadThreshold
    ? Isolate.run(() => metadata.forContentText(contentText))
    : metadata.forContentText(contentText);

/// Connects the document editor to the shared toolbar and host callbacks.
class MoodiaryEditorHost extends ChangeNotifier implements EditorHost {
  MoodiaryEditorHost(
    MoodiaryEditor configuration, {
    components.AudioPlaybackController Function()? audioControllerFactory,
    VideoPlaybackPortFactory? videoPortFactory,
    Future<FastImageProbe> Function({required String filePath})? imageProbe,
  }) : _configuration = configuration,
       _audioControllerFactory =
           audioControllerFactory ?? components.AudioPlaybackController.new,
       _videoPortFactory =
           videoPortFactory ?? components.videoPlayerPortFactory,
       _imageProbe = imageProbe ?? FastImageCodec.probe {
    final content = configuration.initialContent;
    _largeDocument = content.length >= _asyncLoadThreshold;
    _loading = _largeDocument;
    final initial = _loading ? _loadDocument('') : _loadDocument(content);
    _protected = initial.error != null;
    contentError.value = initial.error;
    editor = ft.TiptapController(
      doc: initial.doc,
      referenceCandidates: (query, cancellation) async {
        final result =
            await _configuration.onRequestLinkCandidates?.call(query) ?? [];
        return cancellation.cancelled
            ? []
            : [
                for (final item in result)
                  ft.TiptapReferenceItem(id: item.id, label: item.label),
              ];
      },
    );
    title.text = _singleLineTitle(configuration.initialTitle);
    editor.addListener(_changed);
    title.addListener(_titleChanged);
    bodyFocus.addListener(_focusChanged);
    titleFocus.addListener(_focusChanged);
    editor.searchStatus.addListener(_searchChanged);
    scroll.addListener(_scrolled);
    _lastDocument = editor.state.doc;
    _lastTitle = title.text;
    _deriveState();
    if (_loading) {
      _documentLoaded = _finishLoad(
        content,
        _generation,
        configuration.initialContentText,
      );
    } else {
      _probeDocumentImages(initial.doc);
      _scheduleCount(
        initial: initial,
        contentText: configuration.initialContentText,
      );
    }
  }
  MoodiaryEditor _configuration;
  late final ft.TiptapController editor;
  final title = TextEditingController();
  final bodyFocus = FocusNode(), titleFocus = FocusNode();
  final scroll = ScrollController();
  final editorKey = GlobalKey<ft.TiptapEditorState>();
  final _state = ValueNotifier<EditorState>(EditorState.empty),
      _focus = ValueNotifier<EditorFocusTarget>(EditorFocusTarget.none);
  final _search = ValueNotifier<EditorSearchState?>(null);
  final contentError = ValueNotifier<String?>(null);
  final components.AudioPlaybackController Function() _audioControllerFactory;
  final VideoPlaybackPortFactory _videoPortFactory;
  final Future<FastImageProbe> Function({required String filePath}) _imageProbe;
  final Map<int, _MediaPlayback> _media = {};
  final _mediaSources =
      MediaCache<(String, bool), ({String path, String mime})>();
  final _mediaRequests =
      MediaCache<(String, bool), Future<({String path, String mime})?>>();
  final _imageRatios = MediaCache<String, ({double ratio, bool header})>();
  Iterator<ft.Node>? _pendingImageProbes;
  int _activeImageProbes = 0, _imageProbeGeneration = 0;
  _MediaPlayback? _fullscreenMedia;

  double? estimateNodeHeight(ft.Node node, double width) => switch (node.type) {
    'image' =>
      width /
          (_imageRatios[node.attrs['src'] as String? ?? '']?.ratio ?? 3 / 2),
    'video' => width * 9 / 16,
    'audio' || 'attachment' => 76,
    _ => null,
  };

  void _recordImageHeader(String name, double ratio) {
    final previous = _imageRatios[name];
    _imageRatios[name] = (ratio: ratio, header: true);
    if (previous?.ratio != ratio) notifyListeners();
  }

  Map<String, ft.TiptapNodeViewBuilder> get nodeViews => {
    for (final type in ['image', 'video', 'audio', 'attachment'])
      type: (context, view) => _MediaNode(host: this, view: view),
  };
  ft.Selection? _held;
  ft.Node? _heldDocument, _lastDocument;
  TextSelection? _heldTitle;
  Timer? _save;
  bool _pending = false,
      _disposed = false,
      _loading = false,
      _largeDocument = false,
      _protected = false,
      _panelMode = false;
  Timer? _countTimer;
  int? _characterCount;
  TiptapMetadata? _metadata;
  ft.Node? _metadataDocument;
  int? get characterCount => _characterCount;
  Future<void> _documentLoaded = Future.value();
  @visibleForTesting
  Future<void> get documentLoaded => _documentLoaded;

  void _scheduleCount({
    bool debounce = false,
    _LoadedDocument? initial,
    String? contentText,
  }) {
    _countTimer?.cancel();
    final doc = editor.state.doc;
    final configuration = _configuration;
    final followContentText =
        initial != null && contentText == configuration.initialContentText;
    Future<void> count() async {
      if (_disposed || _loading || !identical(doc, editor.state.doc)) return;
      final useRenderedContent =
          initial != null &&
          (initial.error != null ||
              !initial.source.isDoc ||
              !identical(initial.doc, doc));
      var value =
          _largeDocument ||
              doc.content.size >= _asyncLoadThreshold ||
              (contentText?.length ?? 0) >= _asyncLoadThreshold
          ? await _documentMetadataAsync(
              initial == null || useRenderedContent ? doc : null,
              initial?.source,
              contentText,
              useRenderedContent,
            )
          : _documentMetadata(
              doc,
              initial?.source,
              contentText,
              useRenderedContent,
            );
      if (_disposed || _loading || !identical(doc, editor.state.doc)) return;
      if (followContentText &&
          configuration.initialContent == _configuration.initialContent &&
          contentText != _configuration.initialContentText) {
        value = await _metadataForContentText(
          value,
          _configuration.initialContentText,
        );
      }
      if (_disposed || _loading || !identical(doc, editor.state.doc)) return;
      _publishMetadata(doc, value);
    }

    if (debounce) {
      _countTimer = Timer(const Duration(milliseconds: 300), count);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(count()));
    }
  }

  void _publishMetadata(ft.Node doc, TiptapMetadata value) {
    _metadataDocument = doc;
    _metadata = value;
    _characterCount = value.characterCount;
    _configuration.onMetadataChanged?.call(value);
    notifyListeners();
  }

  Future<void> _finishLoad(
    String content,
    int generation,
    String? contentText,
  ) async {
    _loadingContent = content;
    final configuration = _configuration;
    final result = await _loadDocumentAsync(content);
    if (_disposed || generation != _generation) return;
    _loadingContent = null;
    _installDocument(
      result,
      contentText:
          configuration.initialContent == content &&
              configuration.initialContentText == contentText &&
              _configuration.initialContent == content
          ? _configuration.initialContentText
          : contentText,
    );
    notifyListeners();
  }

  void _installDocument(_LoadedDocument result, {String? contentText}) {
    _protected = result.error != null;
    contentError.value = result.error;
    editor.replaceDocument(result.doc);
    _lastDocument = editor.state.doc;
    _loading = false;
    _probeDocumentImages(result.doc);
    _deriveState();
    _scheduleCount(initial: result, contentText: contentText);
  }

  String? _loadingContent;
  String _lastTitle = '';
  int _generation = 0, _lastHeading = -2;
  bool get readOnly => _configuration.readOnly || _protected || _loading;
  bool get panelMode => _panelMode;
  @override
  ValueListenable<EditorState> get state => _state;
  @override
  ValueListenable<EditorFocusTarget> get focusTarget => _focus;
  @override
  ValueListenable<EditorSearchState?> get search => _search;

  void update(MoodiaryEditor configuration) {
    final previous = _configuration;
    final replacePending =
        _loading && _loadingContent != configuration.initialContent;
    _configuration = configuration;
    if (previous.readOnly != configuration.readOnly) _releaseAllMedia();
    if (replacePending) {
      unawaited(
        swapDocument(
          content: configuration.initialContent,
          contentText: configuration.initialContentText,
          title: configuration.initialTitle,
        ),
      );
    }
    _deriveState();
    // Metadata also drives a route outside the editor subtree. Notify it after
    // didUpdateWidget's build so async place results can refresh the popover.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
    if (!replacePending &&
        previous.initialContent == configuration.initialContent &&
        previous.initialContentText != configuration.initialContentText) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final metadata = _metadata, doc = editor.state.doc;
        if (_disposed ||
            metadata == null ||
            !identical(doc, _metadataDocument)) {
          return;
        }
        final value = await _metadataForContentText(
          metadata,
          configuration.initialContentText,
        );
        if (_disposed ||
            _loading ||
            !identical(doc, editor.state.doc) ||
            configuration.initialContentText !=
                _configuration.initialContentText) {
          return;
        }
        _publishMetadata(doc, value);
      });
    }
  }

  void _changed() {
    final doc = editor.state.doc;
    if (!identical(doc, _lastDocument)) {
      _syncMedia();
      _metadata = null;
      _metadataDocument = null;
      if (_lastDocument != null && !_loading && !readOnly) {
        _pending = true;
        _save?.cancel();
        _save = Timer(const Duration(milliseconds: 300), _deliverChange);
      }
      _lastDocument = doc;
      if (!_loading) _scheduleCount(debounce: true);
    }
    _deriveState();
    notifyListeners();
  }

  void _titleChanged() {
    if (_loading ||
        readOnly ||
        title.value.composing.isValid && !title.value.composing.isCollapsed) {
      return;
    }
    if (title.text == _lastTitle) return;
    _lastTitle = title.text;
    _configuration.onTitleChanged?.call(title.text);
  }

  void _focusChanged() {
    _focus.value = titleFocus.hasPrimaryFocus
        ? EditorFocusTarget.title
        : bodyFocus.hasPrimaryFocus
        ? EditorFocusTarget.editor
        : EditorFocusTarget.none;
    _syncSystemPaste();
  }

  bool _ownsSystemPaste = false;

  void _syncSystemPaste() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final owns = !_disposed && bodyFocus.hasPrimaryFocus;
    if (owns == _ownsSystemPaste) return;
    _ownsSystemPaste = owns;
    _SystemPaste.instance.setOwner(this, owns);
  }

  void _searchChanged() {
    final status = editor.searchStatus.value;
    _search.value = (
      query: status.query,
      total: status.total,
      current: status.current,
    );
  }

  void _deriveState() {
    final s = editor.state,
        t = s.toolbar,
        pos = s.doc.resolve(s.selection.from);
    String? listType;
    var quote = false;
    for (var d = pos.depth; d > 0; d--) {
      final type = pos.node(d).type;
      if (listType == null &&
          const {'bulletList', 'orderedList', 'taskList'}.contains(type)) {
        listType = type;
      }
      quote |= type == 'blockquote';
    }
    final parent = pos.parent,
        selected = s.selection is ft.NodeSelection
            ? s.doc.nodeAt(s.selection.from)
            : null;
    final adjacentRule = _adjacentRule();
    final actionNode =
        selected ?? (adjacentRule == null ? null : s.doc.nodeAt(adjacentRule));
    final nodeType = EditorNodeType.values.asNameMap()[actionNode?.type];
    final link = ft.linkAt(s.doc, s.selection.from);
    final block = parent.type == 'heading'
        ? EditorBlock.values.asNameMap()['heading${parent.attrs['level']}'] ??
              EditorBlock.paragraph
        : parent.type == 'codeBlock'
        ? EditorBlock.codeBlock
        : quote
        ? EditorBlock.blockquote
        : EditorBlock.paragraph;
    final marks = {
      for (final mark in EditorMark.values)
        if (t.activeMarks.contains(mark.name) ||
            mark == EditorMark.link && link != null)
          mark,
    };
    _state.value = EditorState(
      contentError: _protected,
      marks: marks,
      block: block,
      list: switch (listType) {
        'bulletList' => EditorList.bullet,
        'orderedList' => EditorList.ordered,
        'taskList' => EditorList.task,
        _ => null,
      },
      canIndent:
          !_protected &&
          listType != null &&
          editor.commands.execute(s, 'sinkListItem').docChanged,
      canOutdent:
          !_protected &&
          listType != null &&
          editor.commands.execute(s, 'liftListItem').docChanged,
      canUndo: s.history.canUndo,
      canRedo: s.history.canRedo,
      selection: selected != null
          ? EditorSelectionKind.node
          : s.selection.empty
          ? EditorSelectionKind.caret
          : EditorSelectionKind.text,
      node: nodeType == null
          ? null
          : (type: nodeType, attrs: actionNode!.attrs),
      inTable: t.inTable,
      link: link == null
          ? null
          : (href: link.href, text: _textBetween(link.from, link.to)),
      selectedText: selected != null || s.selection.empty
          ? ''
          : editor.selectedText
                .replaceAll('\n', ' ')
                .substring(0, math.min(200, editor.selectedText.length)),
    );
  }

  String _textBetween(int from, int to) => editor.state.doc
      .slice(from, to)
      .content
      .map((n) => n.textContent)
      .join('');
  int? _adjacentRule() {
    final selection = editor.state.selection;
    if (!selection.empty) return null;
    final pos = editor.state.doc.resolve(selection.head);
    if (pos.parent.isTextblock) {
      if (pos.parentOffset == 0 &&
          pos.depth > 0 &&
          editor.state.doc.resolve(pos.before()).nodeBefore?.type ==
              'horizontalRule') {
        return pos.before() - 1;
      }
      if (pos.parentOffset == pos.parent.content.size &&
          pos.depth > 0 &&
          editor.state.doc.resolve(pos.after()).nodeAfter?.type ==
              'horizontalRule') {
        return pos.after();
      }
    } else {
      if (pos.nodeBefore?.type == 'horizontalRule') return pos.pos - 1;
      if (pos.nodeAfter?.type == 'horizontalRule') return pos.pos;
    }
    return null;
  }

  void _restore() {
    if (_held != null && identical(_heldDocument, editor.state.doc)) {
      editor.setSelection(_held!);
    }
    if (_heldTitle != null) title.selection = _heldTitle!;
    _held = null;
    _heldTitle = null;
    _heldDocument = null;
  }

  @override
  Future<void> holdSelection() async {
    editorKey.currentState?.finishComposition();
    _held = editor.state.selection;
    _heldDocument = editor.state.doc;
    _heldTitle = title.selection;
  }

  @override
  Future<void> focus() async {
    _restore();
    bodyFocus.requestFocus();
    if (!_panelMode) {
      editorKey.currentState?.requestKeyboard();
      _showKeyboardAfterBuild();
    }
  }

  void _showKeyboardAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || readOnly || _panelMode) return;
      if (bodyFocus.hasPrimaryFocus) {
        editorKey.currentState?.requestKeyboard();
      } else if (titleFocus.hasPrimaryFocus) {
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        );
      }
    });
  }

  @override
  Future<void> focusTitle() async {
    _restore();
    await setPanelMode(false);
    await setScrollY(0);
    titleFocus.requestFocus();
  }

  @override
  Future<void> blur() async {
    editorKey.currentState?.finishComposition();
    bodyFocus.unfocus();
    titleFocus.unfocus();
  }

  @override
  Future<void> setPanelMode(bool value) async {
    editorKey.currentState?.finishComposition();
    _panelMode = value;
    if (value) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    notifyListeners();
  }

  @override
  Future<bool> suppressKeyboard(bool value) async {
    await setPanelMode(value);
    if (!value) _showKeyboardAfterBuild();
    return true;
  }

  @override
  Future<void> dismissKeyboard() async {
    await setPanelMode(false);
    await blur();
  }

  @override
  Future<void> flush() async {
    editorKey.currentState?.finishComposition();
    if (title.value.composing.isValid && !title.value.composing.isCollapsed) {
      title.value = title.value.copyWith(composing: TextRange.empty);
    }
    _titleChanged();
    _save?.cancel();
    _deliverChange();
  }

  void _deliverChange() {
    // Autosave observes the document, never commits the IME's marked range.
    if (_disposed) return;
    if (_pending && !readOnly) {
      _pending = false;
      _configuration.onChanged?.call(editor.json);
    }
  }

  @override
  Future<double> getScrollY() async => scroll.hasClients ? scroll.offset : 0;
  @override
  Future<void> setScrollY(double value) async {
    if (!scroll.hasClients) return;
    scroll.jumpTo(
      value.clamp(
        scroll.position.minScrollExtent,
        scroll.position.maxScrollExtent,
      ),
    );
  }

  @override
  Future<void> swapDocument({
    required String content,
    required String title,
    String? contentText,
    double scrollY = 0,
  }) async {
    final generation = ++_generation;
    await flush();
    if (_disposed || generation != _generation) return;
    _releaseAllMedia();
    _mediaSources.clear();
    _mediaRequests.clear();
    _imageRatios.clear();
    _pendingImageProbes = null;
    _lastHeading = -2;
    _save?.cancel();
    _countTimer?.cancel();
    _characterCount = null;
    _metadata = null;
    _metadataDocument = null;
    _pending = false;
    _held = null;
    _heldDocument = null;
    _loading = true;
    _protected = false;
    contentError.value = null;
    editor.clearSearch();
    this.title.text = _singleLineTitle(title);
    _lastTitle = this.title.text;
    _largeDocument = content.length >= _asyncLoadThreshold;
    if (_largeDocument) {
      editor.replaceDocument(_loadDocument('').doc);
      notifyListeners();
      _documentLoaded = _finishLoad(content, generation, contentText);
      await _documentLoaded;
      if (_disposed || generation != _generation) return;
    } else {
      _loadingContent = null;
      _installDocument(_loadDocument(content), contentText: contentText);
      notifyListeners();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && generation == _generation) {
        unawaited(setScrollY(scrollY));
      }
    });
  }

  void _scrolled() {
    final geometry = editorKey.currentState?.geometry;
    if (geometry == null) return;
    final at = geometry.positionForOffset(const Offset(20, 1));
    var index = -1, count = 0;
    for (final row in editor.state.doc.rows()) {
      if (row.node.type == 'heading') {
        if (row.position <= at) index = count;
        count++;
      }
      if (row.position > at) break;
    }
    if (index != _lastHeading) {
      _lastHeading = index;
      _configuration.onActiveHeadingChanged?.call(index);
    }
  }

  @override
  Future<void> scrollToHeading(int index) async {
    final geometry = editorKey.currentState?.geometry;
    if (geometry == null) return;
    var count = 0;
    for (final row in editor.state.doc.rows()) {
      if (row.node.type != 'heading') continue;
      if (count++ == index) {
        await setScrollY(
          geometry.rowRect(row.position).top + geometry.scrollOffset,
        );
        return;
      }
    }
  }

  @override
  Future<void> resumeVideo(String name, Duration position) async {
    final fullscreen = _fullscreenMedia;
    final playback =
        fullscreen != null && !fullscreen.disposed && fullscreen.name == name
        ? fullscreen
        : _media.values
              .where((entry) => entry.type == 'video' && entry.name == name)
              .lastOrNull;
    await playback?.resumeAt(position);
  }

  /// Pauses every audio and video in the body, including offscreen ones.
  Future<void> pauseMedia() =>
      Future.wait([for (final entry in _media.values.toList()) entry.pause()]);

  void previewImage(int documentPosition) {
    final images = <String>[];
    final positions = <int>[];
    void visit(ft.Node node, int position) {
      if (node.type == 'image' &&
          node.attrs['src'] is String &&
          !(node.attrs['src']! as String).startsWith('data:')) {
        images.add(node.attrs['src']! as String);
        positions.add(position);
      }
      var childPosition = position + 1;
      for (final child in node.content) {
        visit(child, childPosition);
        childPosition += child.nodeSize;
      }
    }

    visit(editor.state.doc, -1);
    final index = positions.indexOf(documentPosition);
    if (index < 0) return;
    _configuration.onImageTap?.call(images, index, [
      for (final position in positions) (this, position),
    ]);
  }

  Future<void> pasteImage(Object payload) => importImage(payload);

  @override
  Future<void> exec(EditorCommand command, Map<String, Object?>? args) async {
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
    if (const {
          EditorCommand.tableAddRowAfter,
          EditorCommand.tableDeleteRow,
          EditorCommand.tableAddColumnAfter,
          EditorCommand.tableDeleteColumn,
          EditorCommand.tableToggleHeaderRow,
          EditorCommand.tableDelete,
        }.contains(command) &&
        !editor.state.toolbar.inTable) {
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
      case EditorCommand.tableAddRowAfter:
        editor.exec('addRowAfter');
      case EditorCommand.tableDeleteRow:
        editor.exec('deleteRow');
      case EditorCommand.tableAddColumnAfter:
        editor.exec('addColumnAfter');
      case EditorCommand.tableDeleteColumn:
        editor.exec('deleteColumn');
      case EditorCommand.tableToggleHeaderRow:
        editor.exec('toggleHeaderRow');
      case EditorCommand.tableDelete:
        editor.exec('deleteTable');
      default:
        editor.exec(command.name, Map<String, dynamic>.from(a));
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

  @override
  void dispose() {
    _disposed = true;
    _releaseAllMedia();
    _mediaSources.clear();
    _mediaRequests.clear();
    _imageRatios.clear();
    _pendingImageProbes = null;
    _syncSystemPaste();
    _save?.cancel();
    _countTimer?.cancel();
    editor.removeListener(_changed);
    editor.searchStatus.removeListener(_searchChanged);
    editor.dispose();
    title.dispose();
    bodyFocus.dispose();
    titleFocus.dispose();
    scroll.dispose();
    _state.dispose();
    _focus.dispose();
    _search.dispose();
    contentError.dispose();
    super.dispose();
  }
}
