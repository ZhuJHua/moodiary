part of '../moodiary_editor.dart';

final _titleLineBreak = RegExp('\r\n|[\r\n\u2028\u2029]');

String _singleLineTitle(String title) => title.replaceAll(_titleLineBreak, ' ');

class _EditorChange {
  _EditorChange(this.doc, this.json, this.metadata, this.withText);

  final ft.Node doc;
  final String json;
  final FutureOr<TiptapMetadata>? metadata;
  final void Function(String, String)? withText;
  bool delivered = false;

  void deliver(String plainText) {
    if (delivered) return;
    delivered = true;
    withText?.call(json, plainText);
  }
}

/// Connects the document editor to the shared toolbar and host callbacks.
@visibleForTesting
class MoodiaryEditorHost extends ChangeNotifier {
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
  final _viewChanges = ChangeNotifier();
  final _imageChanges = ChangeNotifier();
  final _count = ValueNotifier<int?>(null);
  bool _imageNotificationScheduled = false;
  final _pendingImageHeights = <String>{};
  String? _decodedMetaJson;
  Map<String, dynamic>? _decodedMeta;
  Map<String, dynamic> get _meta {
    final json = _configuration.metaJson;
    if (_decodedMeta == null || _decodedMetaJson != json) {
      _decodedMetaJson = json;
      _decodedMeta = _jsonMap(json);
    }
    return _decodedMeta!;
  }

  final components.AudioPlaybackController Function() _audioControllerFactory;
  final VideoPlaybackPortFactory _videoPortFactory;
  final Future<FastImageProbe> Function({required String filePath}) _imageProbe;
  final Map<int, _MediaPlayback> _media = {};
  final _mediaSources = LRUCache<(String, bool), ({String path, String mime})>(
    maxSize: 512,
  );
  final _mediaRequests =
      LRUCache<(String, bool), Future<({String path, String mime})?>>(
        maxSize: 512,
      );
  final _imageRatios = LRUCache<String, ({double ratio, bool header})>(
    maxSize: 512,
  );
  Iterator<ft.Node>? _pendingImageProbes;
  int _activeImageProbes = 0, _imageProbeGeneration = 0;
  _MediaPlayback? _fullscreenMedia;

  double? estimateNodeHeight(ft.Node node, double width) => switch (node.type) {
    'image' =>
      width /
          (_imageRatios.get(node.attrs['src'] as String? ?? '')?.ratio ??
              3 / 2),
    'video' => width * 9 / 16,
    'audio' || 'attachment' => 76,
    _ => null,
  };

  void _recordImageHeader(String name, double ratio) {
    if (!_recordImageRatio(name, ratio, probed: true)) return;
    _pendingImageHeights.add(name);
    if (_imageNotificationScheduled) return;
    _imageNotificationScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _imageNotificationScheduled = false;
      if (_disposed) return;
      final nodes = <ft.Node>[];
      editor.state.doc.descendants((node, position, parent, index) {
        if (node.type == 'image' &&
            _pendingImageHeights.contains(node.attrs['src'])) {
          nodes.add(node);
        }
        return !node.isTextblock;
      });
      _pendingImageHeights.clear();
      _imageChanges.notifyListeners();
      editor.invalidateNodeHeights(nodes);
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _recordImageRatio(String name, double ratio, {required bool probed}) {
    final previous = _imageRatios.get(name);
    if (!probed && previous?.header == true) return false;
    _imageRatios.put(name, (ratio: ratio, header: probed));
    return previous?.ratio != ratio;
  }

  late final Map<String, ft.TiptapNodeViewBuilder> nodeViews = {
    for (final type in ['image', 'video', 'audio', 'attachment'])
      type: (context, view) => _MediaNode(host: this, view: view),
  };
  ft.Selection? _held;
  ft.Node? _heldDocument, _lastDocument;
  TextSelection? _heldTitle;
  Timer? _save;
  Future<void>? _changeDelivery;
  _EditorChange? _queuedChange, _activeChange;
  bool _pending = false,
      _disposed = false,
      _loading = false,
      _largeDocument = false,
      _protected = false,
      _panelMode = false;
  Timer? _countTimer;
  TiptapMetadata? _metadata;
  ft.Node? _metadataDocument;
  ft.Node? _countDocument;
  FutureOr<TiptapMetadata>? _countResult;
  int? get characterCount => _count.value;
  ft.Node? _headingDocument;
  List<int> _headingPositions = const [];
  List<int> get _headings {
    final doc = editor.state.doc;
    if (!identical(doc, _headingDocument)) {
      _headingDocument = doc;
      _headingPositions = [
        for (final row in doc.rows())
          if (row.node.type == 'heading') row.position,
      ];
    }
    return _headingPositions;
  }

  (ft.Node, ft.Selection, bool)? _indentKey;
  (bool, bool) _indentCommands = (false, false);
  Future<void> _documentLoaded = Future.value();
  @visibleForTesting
  Future<void> get documentLoaded => _documentLoaded;

  String? _loadingContent;
  String _lastTitle = '';
  int _generation = 0, _lastHeading = -2;
  bool get readOnly => _configuration.readOnly || _protected || _loading;
  bool get panelMode => _panelMode;
  ValueListenable<EditorState> get state => _state;
  ValueListenable<EditorFocusTarget> get focusTarget => _focus;
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
      if (!_disposed) _notifyHost();
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

  void _notifyHost({bool view = true}) {
    notifyListeners();
    if (view) _viewChanges.notifyListeners();
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

  String _textBetween(int from, int to) => editor.state.doc
      .slice(from, to)
      .content
      .map((n) => n.textContent)
      .join('');

  void _restore() {
    if (_held != null && identical(_heldDocument, editor.state.doc)) {
      editor.setSelection(_held!);
    }
    if (_heldTitle != null) title.selection = _heldTitle!;
    _held = null;
    _heldTitle = null;
    _heldDocument = null;
  }

  Future<void> holdSelection() async {
    editorKey.currentState?.finishComposition();
    _held = editor.state.selection;
    _heldDocument = editor.state.doc;
    _heldTitle = title.selection;
  }

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

  Future<void> focusTitle() async {
    _restore();
    await setPanelMode(false);
    setScrollY(0);
    titleFocus.requestFocus();
  }

  Future<void> blur() async {
    editorKey.currentState?.finishComposition();
    bodyFocus.unfocus();
    titleFocus.unfocus();
  }

  Future<void> setPanelMode(bool value) async {
    editorKey.currentState?.finishComposition();
    _panelMode = value;
    if (value) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    _notifyHost();
  }

  Future<bool> suppressKeyboard(bool value) async {
    await setPanelMode(value);
    if (!value) _showKeyboardAfterBuild();
    return true;
  }

  Future<void> dismissKeyboard() async {
    await setPanelMode(false);
    await blur();
  }

  Future<void> flush() async {
    if (_disposed) return _changeDelivery;
    editorKey.currentState?.finishComposition();
    if (title.value.composing.isValid && !title.value.composing.isCollapsed) {
      title.value = title.value.copyWith(composing: TextRange.empty);
    }
    _titleChanged();
    _save?.cancel();
    await _deliverChange();
  }

  Future<void> _deliverChange() {
    _queuePendingChange();
    if (_changeDelivery case final delivery?) return delivery;
    late final Future<void> delivery;
    delivery = _deliverPendingChanges().whenComplete(() async {
      if (!identical(_changeDelivery, delivery)) return;
      _changeDelivery = null;
      if (_queuedChange != null) await _deliverChange();
    });
    _changeDelivery = delivery;
    return delivery;
  }

  Future<void> _deliverPendingChanges() async {
    while (_queuedChange != null) {
      final change = _queuedChange!;
      _queuedChange = null;
      _activeChange = change;
      final value = change.metadata;
      final metadata = value is Future<TiptapMetadata> ? await value : value;
      if (identical(_activeChange, change)) _activeChange = null;
      if (change.delivered) continue;
      _queuePendingChange();
      if (_queuedChange != null) continue;
      if (metadata != null) {
        change.deliver(metadata.plainText);
      }
    }
  }

  void _queuePendingChange() {
    if (_disposed || !_pending || readOnly) return;
    _pending = false;
    final doc = editor.state.doc;
    final configuration = _configuration;
    final json = doc.toJsonString();
    _queuedChange = _EditorChange(
      doc,
      json,
      configuration.onChangedWithText == null
          ? null
          : _metadataForDocument(doc),
      configuration.onChangedWithText,
    );
    configuration.onChanged?.call(json);
  }

  double getScrollY() => scroll.hasClients ? scroll.offset : 0;
  void setScrollY(double value) {
    if (!scroll.hasClients) return;
    scroll.jumpTo(
      value.clamp(
        scroll.position.minScrollExtent,
        scroll.position.maxScrollExtent,
      ),
    );
  }

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
    _count.value = null;
    _metadata = null;
    _metadataDocument = null;
    _pending = false;
    _held = null;
    _heldDocument = null;
    _loading = true;
    _protected = false;
    editor.clearSearch();
    this.title.text = _singleLineTitle(title);
    _lastTitle = this.title.text;
    _largeDocument = content.length >= _asyncLoadThreshold;
    if (_largeDocument) {
      editor.replaceDocument(_loadDocument('').doc);
      _notifyHost();
      _documentLoaded = _finishLoad(content, generation, contentText);
      await _documentLoaded;
      if (_disposed || generation != _generation) return;
    } else {
      _loadingContent = null;
      _installDocument(_loadDocument(content), contentText: contentText);
      _notifyHost();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && generation == _generation) {
        setScrollY(scrollY);
      }
    });
  }

  void _scrolled() {
    final geometry = editorKey.currentState?.geometry;
    if (geometry == null) return;
    final at = geometry.positionForOffset(const Offset(20, 1));
    final positions = _headings;
    var low = 0, high = positions.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (positions[mid] <= at) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    final index = low - 1;
    if (index != _lastHeading) {
      _lastHeading = index;
      _configuration.onActiveHeadingChanged?.call(index);
    }
  }

  Future<void> scrollToHeading(int index) async {
    final geometry = editorKey.currentState?.geometry;
    if (geometry == null) return;
    final positions = _headings;
    if (index >= 0 && index < positions.length) {
      setScrollY(
        geometry.rowRect(positions[index]).top + geometry.scrollOffset,
      );
    }
  }

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
    editor.state.doc.descendants((node, position, parent, index) {
      if (node.type == 'image' &&
          node.attrs['src'] is String &&
          !(node.attrs['src']! as String).startsWith('data:')) {
        images.add(node.attrs['src']! as String);
        positions.add(position);
      }
      return true;
    });
    final index = positions.indexOf(documentPosition);
    if (index < 0) return;
    _configuration.onImageTap?.call(images, index, [
      for (final position in positions) (this, position),
    ]);
  }

  Future<void> pasteImage(Object payload) => importImage(payload);

  Future<void> exec(EditorCommand command, Map<String, Object?>? args) =>
      _executeCommand(command, args);

  @override
  void dispose() {
    _queuePendingChange();
    final change = _queuedChange ?? _activeChange;
    _queuedChange = null;
    if (change != null && !change.delivered && change.withText != null) {
      final metadata = change.metadata;
      change.deliver(
        metadata is TiptapMetadata
            ? metadata.plainText
            : TiptapContent.fromDocument(change.doc.toJson()).plainText,
      );
    }
    _activeChange?.delivered = true;
    _disposed = true;
    _releaseAllMedia();
    _mediaSources.clear();
    _mediaRequests.clear();
    _imageRatios.clear();
    _pendingImageHeights.clear();
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
    _viewChanges.dispose();
    _imageChanges.dispose();
    _count.dispose();
    super.dispose();
  }
}
