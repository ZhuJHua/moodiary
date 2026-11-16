/// Reads diary media and attaches files using the editor's Tiptap nodes.
/// Images are returned inline.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../media/diary_media.dart';
import 'arguments.dart';
import 'diary_write_lock.dart';
import 'mcp_results.dart';
import 'schemas.dart';

/// Validates a client supplied MIME type before storing it in a media node.
final RegExp _mimeTypePattern = RegExp(
  r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$',
);

/// The two places a media node can go in the top-level content.
const List<String> _positions = ['end', 'start'];

/// Values of the `kind` argument of `read_diary_media`.
const List<String> _mediaKinds = ['image', 'audio', 'video', 'file'];

/// Decoded cap for one `data` payload. Base64 grows it by a third, and a model
/// context does not need a bigger file; the editor is still the place for very
/// large media.
const int _maxPayloadBytes = 16 * 1024 * 1024;

void registerMediaTools(
  McpServer server, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  DiaryMediaStore? store,
}) {
  final media = store ?? DiaryMediaStore();

  server.registerTool(
    'list_diary_media',
    title: 'List the media of a diary',
    description:
        'Lists every media file one diary references: images, audio, videos '
        'and file attachments. Each entry carries name, mimeType, bytes and '
        'exists; bytes is -1 when the file is missing from this device, and '
        'exists says whether the app media directory has it. Image names can '
        'be passed to read_diary_media.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {'id': diaryIdSchema},
      'required': ['id'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) => _listDiaryMedia(diaries, media, arguments),
  );

  server.registerTool(
    'read_diary_media',
    title: 'Read one media file of a diary',
    description:
        'Returns one image of one diary as an MCP '
        'image content item (base64) plus a JSON metadata text item; images '
        'larger than 8 MB are refused instead of truncated. Audio, video and '
        'file attachments return a tool error: only images can be read. '
        'kind is inferred from the diary references when omitted. The name '
        'must be one of the images that diary references.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {
        'id': diaryIdSchema,
        'name': mediaNameSchema,
        'kind': {
          'type': 'string',
          'enum': _mediaKinds,
          'description':
              'Media kind, inferred from the diary references when omitted. '
              'Only image can be read; other kinds return a tool error.',
        },
      },
      'required': ['id', 'name'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) => _readDiaryMedia(diaries, media, arguments),
  );

  server.registerTool(
    'add_diary_image',
    title: 'Attach an image to a diary',
    description:
        'Attaches one image to an existing diary: the bytes are written into '
        'the app image directory with the app naming scheme and an image '
        'node is inserted at the end (position=end, default) or the start of '
        'the document body, then the diary is persisted. data is base64 of '
        'the image file, at most 16 MB decoded. Accepted types are '
        'image/png, image/jpeg, image/webp, image/gif, image/heic and '
        'image/heif; the type is sniffed from the bytes when mimeType is '
        'omitted. HEIC/HEIF is converted to JPEG. name is the display name '
        'stored on the node (defaults to the stored file name); '
        'widthPercent is the node width 10..100, and omitting it or sending '
        'null keeps the document default. An unknown diary id is a tool '
        'error. The response reports the '
        'stored file name and the updated media lists instead of the whole '
        'body.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {
        'id': diaryIdSchema,
        'data': {
          'type': 'string',
          'description':
              'Base64 of the image file, no data: URL prefix. At most 16 MB '
              'decoded.',
        },
        'mimeType': {
          'type': 'string',
          'description':
              'MIME type of the image: image/png, image/jpeg, image/webp, '
              'image/gif, image/heic or image/heif. Omitted: sniffed from data.',
        },
        'name': {
          'type': 'string',
          'description':
              'Display name stored on the image node, usually the original '
              'file name. Defaults to the stored file name.',
        },
        'position': {
          'type': 'string',
          'enum': _positions,
          'default': 'end',
          'description':
              'Where in the top-level body the image node goes: end '
              '(default) appends it after the last block, start puts it '
              'before the first.',
        },
        'widthPercent': {
          'type': ['integer', 'null'],
          'minimum': 10,
          'maximum': 100,
          'description':
              'Image width as a percentage of the content width, clamped '
              'into 10..100. Omitted or null writes no width attribute, so '
              'the document default applies. The document store keeps values '
              'from 25 to 100, so 10..24 is raised to 25.',
        },
      },
      'required': ['id', 'data'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    ),
    callback: (arguments, call) =>
        _addDiaryImage(diaries, categories, media, arguments),
  );

  server.registerTool(
    'add_diary_attachment',
    title: 'Attach a file to a diary',
    description:
        'Attaches one file to an existing diary: the bytes are written into '
        'the app file directory with the app naming scheme and an attachment '
        'node (src, name, mime, size) is inserted at the end of the document '
        'body, then the diary is persisted. data is base64 of the file, at '
        'most 16 MB decoded. fileName is required and supplies both the '
        'display name on the node and the stored extension; an unusable '
        'extension becomes .bin. mimeType is sniffed from the bytes and the '
        'name when omitted. The response reports the stored file name and '
        'the updated media lists instead of the whole body.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {
        'id': diaryIdSchema,
        'data': {
          'type': 'string',
          'description':
              'Base64 of the file, no data: URL prefix. At most 16 MB '
              'decoded.',
        },
        'fileName': {
          'type': 'string',
          'description':
              'Original file name, e.g. "report.pdf"; used as the display '
              'name and for the stored extension.',
        },
        'mimeType': {
          'type': 'string',
          'description':
              'MIME type of the file, e.g. application/pdf. Omitted: '
              'sniffed from data and the file name.',
        },
      },
      'required': ['id', 'data', 'fileName'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    ),
    callback: (arguments, call) =>
        _addDiaryAttachment(diaries, categories, media, arguments),
  );
}

Future<CallToolResult> _listDiaryMedia(
  DiaryRepository diaries,
  DiaryMediaStore media,
  Map<String, dynamic> arguments,
) async {
  final args = Args('list_diary_media', arguments);
  final id = args.requireText('id');
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolError('list_diary_media: no diary with id="$id".');
  }
  final entries = <String, List<Map<String, dynamic>>>{};
  final lists = mediaLists(diary);
  for (final kind in MediaType.values) {
    final key = switch (kind) {
      .image => 'images',
      .audio => 'audio',
      .video => 'videos',
      .file => 'files',
    };
    entries[key] = await _mediaEntries(media, kind, lists[key]!);
  }
  return jsonToolResult({
    'id': diary.id,
    'title': diary.title,
    'media': entries,
    'count': entries.values.fold(0, (count, rows) => count + rows.length),
  });
}

Future<CallToolResult> _readDiaryMedia(
  DiaryRepository diaries,
  DiaryMediaStore media,
  Map<String, dynamic> arguments,
) async {
  final args = Args('read_diary_media', arguments);
  final id = args.requireText('id');
  final name = args.requireText('name');
  final kindName = args.optionalEnum('kind', _mediaKinds);
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolError('read_diary_media: no diary with id="$id".');
  }
  final kind = kindName == null
      ? diary.mediaKindOf(name)
      : MediaType.values.byName(kindName);
  // Require diary membership even when the client supplies a kind.
  if (!isSafeMediaName(name) ||
      kind == null ||
      !diary.mediaNamesOf(kind).contains(name)) {
    return toolError(
      'read_diary_media: diary id="$id" has no ${kind?.value ?? 'image'} media named '
      '"$name"; list_diary_media shows the names and kinds that may be read.',
    );
  }
  if (kind != MediaType.image) {
    return toolError('read_diary_media: only images can be read.');
  }
  final stat = await media.stat(kind, name);
  if (!stat.exists) {
    return toolError(
      'read_diary_media: "$name" is listed in diary id="$id" but is missing '
      'from the ${kind.value} media directory on this device.',
    );
  }
  if (stat.bytes > mcpInlineBytes) {
    return toolError(
      'read_diary_media: the image "$name" is ${formatMegabytes(stat.bytes)} '
      'MB, more than the ${formatMegabytes(mcpInlineBytes)} MB inline '
      'limit, so it is not returned. The file is still on the device; open the '
      'diary in the app to view it.',
    );
  }
  final metadata = <String, dynamic>{
    'id': diary.id,
    'title': diary.title,
    'name': name,
    'kind': kind.name,
    'mimeType': stat.mimeType,
    'bytes': stat.bytes,
    'exists': true,
  };
  final bytes = await media.read(kind, name);
  if (bytes == null) {
    return toolError(
      'read_diary_media: "$name" of diary id="$id" disappeared while it was '
      'being read; call list_diary_media and try again.',
    );
  }
  if (bytes.length > mcpInlineBytes) {
    return toolError(
      'read_diary_media: the image "$name" is ${formatMegabytes(bytes.length)} '
      'MB, more than the ${formatMegabytes(mcpInlineBytes)} MB inline '
      'limit, so it is not returned. The file is still on the device; open the '
      'diary in the app to view it.',
    );
  }
  return CallToolResult(
    content: [
      ImageContent(data: base64Encode(bytes), mimeType: stat.mimeType),
      TextContent(text: jsonEncode(metadata)),
    ],
    structuredContent: metadata,
  );
}

Future<CallToolResult> _addDiaryImage(
  DiaryRepository diaries,
  CategoryRepository categories,
  DiaryMediaStore media,
  Map<String, dynamic> arguments,
) async {
  const subject = 'add_diary_image';
  final args = Args(subject, arguments);
  final id = args.requireText('id');
  final data = args.requireText('data');
  final position = args.optionalEnum('position', _positions) ?? 'end';
  final requestedMime = _normalizeMime(args.optionalText('mimeType'));
  final displayName = args.optionalText('name');
  // A null widthPercent is the same as omitting it: the node is written
  // without a width attribute and the document default applies, so the
  // present-with-a-value test is the right reader here rather than [has].
  final widthPercent = args.contains('widthPercent')
      ? args.optionalInt('widthPercent', fallback: 100, min: 10, max: 100)
      : null;

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolError('$subject: no diary with id="$id".');
  }
  if (_documentError(subject, diary) case final error?) return error;
  final payload = _decodePayload(subject, data);
  if (payload.error case final error?) return error;
  final bytes = payload.bytes!;

  final resolvedMime = _resolveImageMime(requestedMime, bytes);
  if (resolvedMime.error case final error?) {
    return toolError('$subject: $error');
  }
  final SavedDiaryMedia saved;
  try {
    saved = await _saveMedia(
      media,
      bytes,
      kind: MediaType.image,
      fileName: 'upload.${resolvedMime.mime!.split('/').last}',
      mimeType: resolvedMime.mime,
    );
  } on DiaryMediaException catch (e) {
    return toolError('$subject: ${e.message}');
  }

  final node = <String, dynamic>{
    'type': 'image',
    'attrs': {
      'src': saved.name,
      'name': displayName ?? saved.name,
      'widthPercent': ?widthPercent,
    },
  };
  return _persistNode(
    diaries,
    categories,
    subject: subject,
    diary: diary,
    node: node,
    atStart: position == 'start',
    saved: saved,
  );
}

Future<CallToolResult> _addDiaryAttachment(
  DiaryRepository diaries,
  CategoryRepository categories,
  DiaryMediaStore media,
  Map<String, dynamic> arguments,
) async {
  const subject = 'add_diary_attachment';
  final args = Args(subject, arguments);
  final id = args.requireText('id');
  final data = args.requireText('data');
  final fileName = _displayFileName(args.requireText('fileName'));
  final requestedMime = _normalizeMime(args.optionalText('mimeType'));
  if (requestedMime != null && !_mimeTypePattern.hasMatch(requestedMime)) {
    throw McpError(
      ErrorCode.invalidParams.value,
      '$subject: mimeType must look like "type/subtype"',
    );
  }

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolError('$subject: no diary with id="$id".');
  }
  if (_documentError(subject, diary) case final error?) return error;
  final payload = _decodePayload(subject, data);
  if (payload.error case final error?) return error;
  final bytes = payload.bytes!;

  final SavedDiaryMedia saved;
  try {
    saved = await _saveMedia(
      media,
      bytes,
      kind: MediaType.file,
      fileName: fileName,
      mimeType: requestedMime,
    );
  } on DiaryMediaException catch (e) {
    return toolError('$subject: ${e.message}');
  }

  final node = TiptapContent.attachmentNode(
    src: saved.name,
    name: fileName,
    mime: saved.mimeType,
    size: saved.bytes,
  );
  return _persistNode(
    diaries,
    categories,
    subject: subject,
    diary: diary,
    node: node,
    atStart: false,
    saved: saved,
  );
}

Future<SavedDiaryMedia> _saveMedia(
  DiaryMediaStore media,
  Uint8List bytes, {
  required MediaType kind,
  required String fileName,
  String? mimeType,
}) async {
  final cache = Directory(AppFiles.getCachePath('import/mcp'));
  Directory? scratch;
  try {
    await cache.create(recursive: true);
    scratch = await cache.createTemp('media-');
    final file = File(
      '${scratch.path}/${kind == MediaType.image ? fileName : 'upload'}',
    );
    await file.writeAsBytes(bytes, flush: true);
    final input = XFile(file.path, name: fileName, mimeType: mimeType);
    if (kind == MediaType.image) {
      final name = await MediaManager.saveImage(input, reuseExisting: false);
      if (name != null) {
        final stat = await media.stat(kind, name);
        return SavedDiaryMedia(
          name: name,
          mimeType: stat.mimeType,
          bytes: stat.bytes,
        );
      }
    } else {
      final saved = await MediaManager.saveAttachment(
        input,
        originalFileName: fileName,
      );
      if (saved != null) {
        return SavedDiaryMedia(
          name: saved.name,
          mimeType: saved.mime ?? 'application/octet-stream',
          bytes: saved.size,
        );
      }
    }
  } on FileSystemException catch (e) {
    logger.d('MCP media save failed: $e');
  } finally {
    await scratch?.delete(recursive: true).catchError((_) => scratch!);
  }
  throw DiaryMediaException(
    'the app could not write "$fileName" to the ${kind.value} directory',
  );
}

/// Inserts [node] into the diary document and persists it, then answers with
/// the stored file name and the updated media lists.
Future<CallToolResult> _persistNode(
  DiaryRepository diaries,
  CategoryRepository categories, {
  required String subject,
  required Diary diary,
  required Map<String, dynamic> node,
  required bool atStart,
  required SavedDiaryMedia saved,
}) async {
  final Diary updated;
  try {
    updated = await _insertNode(
      diaries,
      categories,
      diaryId: diary.id,
      node: node,
      atStart: atStart,
      newMediaName: saved.name,
    );
  } on DiaryMediaException catch (e) {
    return toolError('$subject: ${e.message}');
  } on DiaryOpsException catch (e) {
    return toolError('$subject: ${_opsFailureMessage(e, diary.id)}');
  }
  return jsonToolResult({
    'added': true,
    'name': saved.name,
    'mimeType': saved.mimeType,
    'bytes': saved.bytes,
    'diary': {
      'id': updated.id,
      'title': updated.title,
      'media': mediaLists(updated),
    },
  });
}

/// Parses the stored document, inserts [node] and persists the body with the
/// `document` write format so `DiaryWrites` re-derives the media lists.
Future<Diary> _insertNode(
  DiaryRepository diaries,
  CategoryRepository categories, {
  required String diaryId,
  required Map<String, dynamic> node,
  required bool atStart,
  required String newMediaName,
}) => withDiaryWriteLock(diaryId, () async {
  final diary = await diaries.getDiaryByBusinessId(diaryId);
  if (diary == null || !diary.show) {
    throw DiaryOpsException(DiaryOpsFailure.notFound, id: diaryId);
  }
  final parsed = TiptapContent.parse(diary.content);
  if (!parsed.isDoc) throw DiaryMediaException(_noDocumentMessage(diary));
  final document = Map<String, dynamic>.from(parsed.document!);
  final content = document['content'];
  final nodes = content is List ? List<dynamic>.from(content) : <dynamic>[];
  if (atStart) {
    nodes.insert(0, node);
  } else {
    nodes.add(node);
  }
  document['content'] = nodes;
  return DiaryWrites(diaries: diaries, categories: categories).update(
    id: diary.id,
    patch: DiaryPatch(content: jsonEncode(document)),
    format: DiaryContentFormat.document,
    // Only the newly saved file may extend the diary media allowlist.
    enforceOwnMedia: true,
    extraAllowedMedia: {newMediaName},
  );
});

/// The message for a diary whose body is not a Tiptap document, so it cannot
/// carry a media node: the editor only shows nodes in a document body.
String _noDocumentMessage(Diary diary) =>
    'diary id="${diary.id}" stores ${diary.type} content instead of a Tiptap '
    'document, so no media node can be inserted; rewrite the body with '
    'update_diary contentFormat="document" first.';

/// Rejects legacy bodies before writing files to avoid orphan media.
CallToolResult? _documentError(String subject, Diary diary) =>
    TiptapContent.parse(diary.content).isDoc
    ? null
    : toolError('$subject: ${_noDocumentMessage(diary)}');

String _opsFailureMessage(DiaryOpsException e, String id) =>
    switch (e.failure) {
      DiaryOpsFailure.notFound => 'no diary with id="$id".',
      DiaryOpsFailure.foreignMedia =>
        'content references a media file this diary does not own.',
      final failure => 'the diary could not be updated (${failure.name}).',
    };

Future<List<Map<String, dynamic>>> _mediaEntries(
  DiaryMediaStore media,
  MediaType kind,
  List<String> names,
) async {
  final entries = <Map<String, dynamic>>[];
  for (final name in names) {
    if (!isSafeMediaName(name)) continue;
    final stat = await media.stat(kind, name);
    entries.add({
      'name': name,
      'mimeType': stat.mimeType,
      'bytes': stat.bytes,
      'exists': stat.exists,
    });
  }
  return entries;
}

/// Checks the size estimate before decoding. Malformed data is invalid
/// params; exceeding the server's size cap is a tool error.
({Uint8List? bytes, CallToolResult? error}) _decodePayload(
  String subject,
  String data,
) {
  final estimate = (data.length * 3) ~/ 4;
  if (estimate > _maxPayloadBytes) {
    return (bytes: null, error: _tooLarge(subject, estimate));
  }
  final bytes = _decodeBase64(subject, data);
  if (bytes.length > _maxPayloadBytes) {
    return (bytes: null, error: _tooLarge(subject, bytes.length));
  }
  return (bytes: bytes, error: null);
}

CallToolResult _tooLarge(String subject, int bytes) => toolError(
  '$subject: data decodes to ${formatMegabytes(bytes)} MB, more than the '
  '${formatMegabytes(_maxPayloadBytes)} MB limit per file; send a smaller file '
  'or attach it in the app.',
);

Uint8List _decodeBase64(String subject, String data) {
  final Uint8List bytes;
  try {
    bytes = base64Decode(data);
  } on FormatException {
    throw McpError(
      ErrorCode.invalidParams.value,
      '$subject: data is not valid base64',
    );
  }
  if (bytes.isEmpty) {
    throw McpError(
      ErrorCode.invalidParams.value,
      '$subject: data decodes to zero bytes',
    );
  }
  return bytes;
}

/// Sniffs image headers first; trusts explicit MIME only for unknown headers.
({String? mime, String? error}) _resolveImageMime(
  String? requested,
  Uint8List bytes,
) {
  final sniffed = _sniffMime(bytes);
  final mime = requested ?? sniffed;
  if (mime == null) {
    return (
      mime: null,
      error:
          'the image type could not be determined; send mimeType '
          '(${DiaryMediaStore.supportedImageMimeTypes.join(', ')}).',
    );
  }
  if (!DiaryMediaStore.supportedImageMimeTypes.contains(mime)) {
    return (
      mime: null,
      error:
          'mimeType "$mime" is not supported; supported image types are '
          '${DiaryMediaStore.supportedImageMimeTypes.join(', ')}.',
    );
  }
  if (sniffed != null && sniffed != mime) {
    return (
      mime: null,
      error:
          'data looks like $sniffed but mimeType is $mime; send the actual '
          'image type or convert the image first.',
    );
  }
  return (mime: mime, error: null);
}

String? _normalizeMime(String? value) {
  if (value == null) return null;
  final base = value.split(';').first.trim().toLowerCase();
  if (base.isEmpty) return null;
  return base == 'image/jpg' ? 'image/jpeg' : base;
}

String? _sniffMime(Uint8List bytes) =>
    _normalizeMime(DiaryMediaStore.sniffMime('', bytes));

String _displayFileName(String fileName) {
  final base = fileName.replaceAll(r'\', '/').split('/').last.trim();
  return base.isEmpty ? 'attachment' : base;
}
