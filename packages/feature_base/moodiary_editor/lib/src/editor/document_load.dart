part of '../moodiary_editor.dart';

const _asyncLoadThreshold = 64 * 1024;

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
      }

      validate(doc);
      doc.descendants((node, position, parent, index) {
        validate(node);
        return true;
      });
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

extension _HostLoading on MoodiaryEditorHost {
  FutureOr<TiptapMetadata> _metadataForDocument(ft.Node doc) {
    if (identical(doc, _metadataDocument) && _metadata != null) {
      return _metadata!;
    }
    if (identical(doc, _countDocument) && _countResult != null) {
      return _countResult!;
    }
    _countDocument = doc;
    debugMetadataComputations++;
    final FutureOr<TiptapMetadata> result =
        _largeDocument || doc.content.size >= _asyncLoadThreshold
        ? _documentMetadataAsync(doc, null, null, false)
        : _documentMetadata(doc, null, null, false);
    _countResult = result;
    return result;
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
    _notifyHost();
  }

  void _installDocument(_LoadedDocument result, {String? contentText}) {
    _protected = result.error != null;
    editor.replaceDocument(result.doc);
    _lastDocument = editor.state.doc;
    _loading = false;
    _probeDocumentImages(result.doc);
    _deriveState();
    _scheduleCount(initial: result, contentText: contentText);
  }

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
      final FutureOr<TiptapMetadata> pending = initial == null
          ? _metadataForDocument(doc)
          : _largeDocument ||
                doc.content.size >= _asyncLoadThreshold ||
                (contentText?.length ?? 0) >= _asyncLoadThreshold
          ? _documentMetadataAsync(
              useRenderedContent ? doc : null,
              initial.source,
              contentText,
              useRenderedContent,
            )
          : _documentMetadata(
              doc,
              initial.source,
              contentText,
              useRenderedContent,
            );
      var value = pending is Future<TiptapMetadata> ? await pending : pending;
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
    _count.value = value.characterCount;
    _configuration.onMetadataChanged?.call(value);
    _notifyHost(view: false);
  }
}
