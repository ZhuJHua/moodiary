part of '../moodiary_editor.dart';

final _markdownInline = RegExp(
  r'\*\*[^*\n]+\*\*|~~[^~\n]+~~|`[^`\n]+`|!?\[[^\]\n]+\]\([^)\s]+\)',
);
final _markdownHeadingOrRule = RegExp(
  r'^\s{0,3}(?:#{1,6}\s+\S|-{3,}\s*$|\*{3,}\s*$|_{3,}\s*$)',
);
final _markdownBlock = RegExp(
  r'^\s{0,3}(?:[-*+]\s+\S|\d+[.)]\s+\S|>\s?\S|```|~~~|\|.*\|\s*$)',
);

// A single line only counts when it can't be an ordinary list-like note.
bool _looksLikeMarkdown(String text) {
  if (_markdownInline.hasMatch(text)) return true;
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  return lines.any(
    (line) =>
        _markdownHeadingOrRule.hasMatch(line) ||
        lines.length > 1 && _markdownBlock.hasMatch(line),
  );
}

@visibleForTesting
Map<String, dynamic>? parsePastedMarkdown(String text) {
  if (!_looksLikeMarkdown(text)) return null;
  final json = MarkdownToTiptap.convert(text, hardBreaks: true);
  return json == null ? null : jsonDecode(json) as Map<String, dynamic>;
}

class _SystemPaste implements SystemPasteClient {
  static final instance = _SystemPaste._();
  _SystemPaste._() {
    SystemPasteClient.setUp(this);
  }
  MoodiaryEditorHost? _owner;

  void setOwner(MoodiaryEditorHost host, bool owns) {
    if (!owns && _owner != host) return;
    _owner = owns ? host : null;
    unawaited(SystemPasteApi().setEnabled(owns).catchError((Object _) {}));
  }

  @override
  void onPaste() => _owner?.editorKey.currentState?.paste();
}

extension _HostTransfer on MoodiaryEditorHost {
  Future<void> copyClipboard(String text, String html) async {
    try {
      await HtmlClipboardApi().write(
        HtmlClipboardContent(text: text, html: html),
      );
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<bool> pasteClipboard() async {
    if (readOnly) return false;
    final generation = _generation, revision = editor.revision;
    try {
      HtmlClipboardContent? content;
      try {
        content = await HtmlClipboardApi().read();
      } on MissingPluginException {
        /* Desktop/plain-text fallback. */
      } on PlatformException {
        /* Fall through to image/plain-text clipboard. */
      }
      if (_disposed ||
          readOnly ||
          generation != _generation ||
          revision != editor.revision) {
        return true;
      }
      if (content?.html?.isNotEmpty == true) {
        await editor.pasteHtml(
          content!.html!,
          text: content.text,
          onPasteText: parsePastedMarkdown,
        );
        return true;
      }
      final image = await ImageTransferApi().readClipboardImage();
      if (_disposed ||
          generation != _generation ||
          revision != editor.revision) {
        return true;
      }
      if (image == null) {
        if (content?.text.isNotEmpty != true) return false;
        await editor.paste(
          text: content!.text,
          onPasteText: parsePastedMarkdown,
        );
        return true;
      }
      await importImage(image);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stack) {
      // Desktop has no mobile Pigeon implementation; retain plain-text paste.
      _log(
        'image clipboard read failed',
        error: error,
        stack: stack,
        level: 1000,
      );
      return false;
    }
  }

  Future<void> importImage(Object payload) async {
    if (readOnly || _disposed) return;
    final generation = _generation, revision = editor.revision;
    String? dataUri;
    var name = 'image.png';
    try {
      if (payload is TransferredImage) {
        if (!payload.mime.startsWith('image/')) return;
        name = payload.name;
        dataUri = 'data:${payload.mime};base64,${base64Encode(payload.bytes)}';
      }
      if (payload is String && payload.startsWith('data:image/')) {
        dataUri = payload;
      }
      if (payload is Uint8List) {
        dataUri = 'data:image/png;base64,${base64Encode(payload)}';
      }
      if (payload is KeyboardInsertedContent) {
        if (!payload.mimeType.startsWith('image/')) return;
        name = 'image.${payload.mimeType.split('/').last}';
        var bytes = payload.data;
        if (bytes == null &&
            Uri.tryParse(payload.uri)?.scheme == 'content' &&
            defaultTargetPlatform == TargetPlatform.android) {
          bytes = await ImageTransferApi().readContentUri(payload.uri);
        }
        if (bytes != null) {
          dataUri = 'data:${payload.mimeType};base64,${base64Encode(bytes)}';
        }
      }
      if (payload is Map) {
        dataUri = payload['dataUri'] as String?;
        name = payload['name'] as String? ?? name;
      }
      final uri = switch (payload) {
        final Uri value => value,
        final String value => Uri.tryParse(value),
        final KeyboardInsertedContent value => Uri.tryParse(value.uri),
        final File value => value.uri,
        _ => null,
      };
      if (dataUri == null && uri?.scheme == 'file') {
        name = uri!.pathSegments.last;
        if (!RegExp(
          r'\.(png|jpe?g|webp|gif|heic|heif|tiff?|bmp)$',
          caseSensitive: false,
        ).hasMatch(name)) {
          return;
        }
        dataUri =
            'data:${imageMimeOf(name)};base64,${base64Encode(await File.fromUri(uri).readAsBytes())}';
      }
      if (dataUri == null ||
          !dataUri.startsWith('data:image/') ||
          _disposed ||
          generation != _generation ||
          revision != editor.revision) {
        return;
      }
      final saved = await _configuration.onSaveImage?.call(dataUri, name);
      if (!_disposed &&
          !readOnly &&
          generation == _generation &&
          revision == editor.revision &&
          saved != null) {
        await exec(EditorCommand.insertImage, {'name': saved});
      }
    } catch (error, stack) {
      _log('image import failed', error: error, stack: stack, level: 1000);
    }
  }
}
