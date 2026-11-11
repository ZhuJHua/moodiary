/// Media tools: list the media of one diary, return one file as MCP content and
/// attach a new image or attachment.
///
/// The tools write through [DiaryMediaStore] into the app media directories and
/// insert the same Tiptap nodes the editor inserts, so the editor shows what an
/// external client wrote. Returning media reuses the app's storage names: an
/// image comes back inline because a model can use it; larger media comes back
/// as metadata plus a `resource_link` so the client fetches bytes through
/// `moodiary://diary/{id}/media/{name}` without inflating the model context.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../media/diary_media.dart';
import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'schemas.dart';

/// Cheap shape check for a client supplied MIME type of an attachment; the
/// value ends up in the media node and in the resource link, so a malformed one
/// is refused instead of being stored verbatim.
final RegExp _mimeTypePattern = RegExp(
  r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$',
);

/// The two places a media node can go in the top-level content.
const List<String> _positions = ['end', 'start'];

/// Values of the `kind` argument of `read_diary_media`.
const List<String> _mediaKinds = ['image', 'audio', 'video', 'file'];

/// HEIF containers need the native decoder this feature package does not
/// depend on, so they are refused with a hint instead of being stored as a file
/// the editor cannot display.
const Set<String> _heicMimeTypes = {
  'image/heic',
  'image/heif',
  'image/heic-sequence',
  'image/heif-sequence',
};

/// Decoded cap for one `data` payload. Base64 grows it by a third, and a model
/// context does not need a bigger file; the editor is still the place for very
/// large media.
const int _maxPayloadBytes = 16 * 1024 * 1024;

/// Inline cap for an image returned by `read_diary_media`. Base64 adds a third
/// on the wire, and some clients keep tool results in the model context.
const int _maxInlineImageBytes = 8 * 1024 * 1024;

/// Registers the media tools.
///
/// [store] is `null` when the composition root did not install one; the default
/// store then writes into the real `AppFiles` directories, which is what the app
/// needs. Tests pass a store whose `pathOf` points at a temporary directory.
void registerMediaTools(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required CategoryRepository categories,
  DiaryMediaStore? store,
}) {
  final media = store ?? DiaryMediaStore();

  registry.addTool(
    const McpTool(
      name: 'list_diary_media',
      title: 'List the media of a diary',
      description:
          'Lists every media file one diary references: images, audio, videos '
          'and file attachments. Each entry carries name, mimeType, bytes and '
          'exists; bytes is -1 when the file is missing from this device, and '
          'exists says whether the app media directory has it. The names can be '
          'passed to read_diary_media or used in '
          'moodiary://diary/{id}/media/{name}.',
      inputSchema: {
        'type': 'object',
        'properties': {'id': diaryIdSchema},
        'required': ['id'],
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) => _listDiaryMedia(diaries, media, arguments),
  );

  registry.addTool(
    const McpTool(
      name: 'read_diary_media',
      title: 'Read one media file of a diary',
      description:
          'Returns one media file of one diary. An image comes back as an MCP '
          'image content item (base64) plus a JSON metadata text item; images '
          'larger than 8 MB are refused instead of truncated. Audio, video and '
          'file attachments come back as a JSON metadata text item plus a '
          'resource_link to moodiary://diary/{id}/media/{name}, so a client can '
          'fetch the bytes without inlining them; that resource also refuses '
          'files above 8 MB. kind is inferred from the name prefix when it is '
          'omitted. The name must be one of the media files that diary '
          'references.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': diaryIdSchema,
          'name': mediaNameSchema,
          'kind': {
            'type': 'string',
            'enum': _mediaKinds,
            'description':
                'Media directory to read from. Omitted: inferred from the '
                'name (video-…, audio-…, file-…, otherwise an image).',
          },
        },
        'required': ['id', 'name'],
      },
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) => _readDiaryMedia(diaries, media, arguments),
  );

  registry.addTool(
    const McpTool(
      name: 'add_diary_image',
      title: 'Attach an image to a diary',
      description:
          'Attaches one image to an existing diary: the bytes are written into '
          'the app image directory with the app naming scheme and an image '
          'node is inserted at the end (position=end, default) or the start of '
          'the document body, then the diary is persisted. data is base64 of '
          'the image file, at most 16 MB decoded. Accepted types are '
          'image/png, image/jpeg, image/webp and image/gif; the type is sniffed '
          'from the bytes when mimeType is omitted, and HEIC/HEIF is refused '
          'because this build has no decoder for it. name is the display name '
          'stored on the node (defaults to the stored file name); '
          'widthPercent is the node width 10..100, and omitting it or sending '
          'null keeps the document default. An unknown diary id is a tool '
          'error. The response reports the '
          'stored file name and the updated media lists instead of the whole '
          'body.',
      inputSchema: {
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
                'MIME type of the image: image/png, image/jpeg, image/webp or '
                'image/gif. Omitted: sniffed from data.',
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
      },
    ),
    (call, arguments) => _addDiaryImage(diaries, categories, media, arguments),
  );

  registry.addTool(
    const McpTool(
      name: 'add_diary_attachment',
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
      inputSchema: {
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
      },
    ),
    (call, arguments) =>
        _addDiaryAttachment(diaries, categories, media, arguments),
  );
}

Future<McpToolResult> _listDiaryMedia(
  DiaryRepository diaries,
  DiaryMediaStore media,
  Map<String, dynamic> arguments,
) async {
  final args = Args('list_diary_media', arguments);
  final id = args.requireText('id');
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return McpToolResult.error('list_diary_media: no diary with id="$id".');
  }
  final images = await _mediaEntries(
    media,
    DiaryMediaKind.image,
    diary.imageName,
  );
  final audio = await _mediaEntries(
    media,
    DiaryMediaKind.audio,
    diary.audioName,
  );
  final videos = await _mediaEntries(
    media,
    DiaryMediaKind.video,
    diary.videoName,
  );
  final files = await _mediaEntries(media, DiaryMediaKind.file, diary.fileName);
  return McpToolResult.json({
    'id': diary.id,
    'title': diary.title,
    'media': {
      'images': images,
      'audio': audio,
      'videos': videos,
      'files': files,
    },
    'count': images.length + audio.length + videos.length + files.length,
  });
}

Future<McpToolResult> _readDiaryMedia(
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
    return McpToolResult.error('read_diary_media: no diary with id="$id".');
  }
  final kind = kindName == null
      ? DiaryMediaKind.fromName(name)
      : DiaryMediaKind.values.byName(kindName);
  // A client supplied name is only acceptable when the diary itself references
  // it in the list of that kind; that allowlist also keeps `..`, `/` and
  // absolute paths out of the path join.
  if (!diary.hasMedia(name) || !diary.mediaNamesOf(kind).contains(name)) {
    return McpToolResult.error(
      'read_diary_media: diary id="$id" has no ${kind.directory} media named '
      '"$name"; list_diary_media shows the names and kinds that may be read.',
    );
  }
  final stat = await media.stat(kind, name);
  if (!stat.exists) {
    return McpToolResult.error(
      'read_diary_media: "$name" is listed in diary id="$id" but is missing '
      'from the ${kind.directory} media directory on this device.',
    );
  }
  final uri = _mediaUri(diary.id, name);
  final metadata = <String, dynamic>{
    'id': diary.id,
    'title': diary.title,
    'name': name,
    'kind': kind.name,
    'mimeType': stat.mimeType,
    'bytes': stat.bytes,
    'exists': true,
    'uri': uri,
  };
  if (kind != DiaryMediaKind.image) {
    return McpToolResult(
      content: [
        McpContent.text(jsonEncode(metadata)),
        McpContent.resourceLink(
          uri: uri,
          name: name,
          mimeType: stat.mimeType,
          description: '${kind.name} media of diary "${diary.title}"',
        ),
      ],
      structuredContent: metadata,
    );
  }
  final bytes = await media.read(kind, name);
  if (bytes == null) {
    return McpToolResult.error(
      'read_diary_media: "$name" of diary id="$id" disappeared while it was '
      'being read; call list_diary_media and try again.',
    );
  }
  if (bytes.length > _maxInlineImageBytes) {
    return McpToolResult.error(
      'read_diary_media: the image "$name" is ${formatMegabytes(bytes.length)} '
      'MB, more than the ${_maxInlineImageBytes ~/ (1024 * 1024)} MB inline '
      'limit, so it is not returned. The file is still on the device; open the '
      'diary in the app to view it.',
    );
  }
  return McpToolResult(
    content: [
      McpContent.image(
        base64Data: base64Encode(bytes),
        mimeType: stat.mimeType,
      ),
      McpContent.text(jsonEncode(metadata)),
    ],
    structuredContent: metadata,
  );
}

Future<McpToolResult> _addDiaryImage(
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
    return McpToolResult.error('$subject: no diary with id="$id".');
  }
  if (_documentError(subject, diary) case final error?) return error;
  final payload = _decodePayload(subject, data);
  if (payload.error case final error?) return error;
  final bytes = payload.bytes!;

  final resolvedMime = _resolveImageMime(requestedMime, bytes);
  if (resolvedMime.error case final error?) {
    return McpToolResult.error('$subject: $error');
  }
  final SavedDiaryMedia saved;
  try {
    saved = await media.saveImage(bytes, mimeType: resolvedMime.mime!);
  } on DiaryMediaException catch (e) {
    return McpToolResult.error('$subject: ${e.message}');
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

Future<McpToolResult> _addDiaryAttachment(
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
    throw const JsonRpcException(
      JsonRpcCode.invalidParams,
      '$subject: mimeType must look like "type/subtype"',
    );
  }

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return McpToolResult.error('$subject: no diary with id="$id".');
  }
  if (_documentError(subject, diary) case final error?) return error;
  final payload = _decodePayload(subject, data);
  if (payload.error case final error?) return error;
  final bytes = payload.bytes!;

  final SavedDiaryMedia saved;
  try {
    saved = await media.saveAttachment(
      bytes,
      fileName: fileName,
      mimeType: requestedMime,
    );
  } on DiaryMediaException catch (e) {
    return McpToolResult.error('$subject: ${e.message}');
  }

  final node = <String, dynamic>{
    'type': 'attachment',
    'attrs': {
      'src': saved.name,
      'name': fileName,
      'mime': saved.mimeType,
      'size': saved.bytes,
    },
  };
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

/// Inserts [node] into the diary document and persists it, then answers with
/// the stored file name and the updated media lists.
Future<McpToolResult> _persistNode(
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
      diary: diary,
      node: node,
      atStart: atStart,
      newMediaName: saved.name,
    );
  } on DiaryMediaException catch (e) {
    return McpToolResult.error('$subject: ${e.message}');
  } on DiaryOpsException catch (e) {
    return McpToolResult.error('$subject: ${_opsFailureMessage(e, diary.id)}');
  }
  return McpToolResult.json({
    'added': true,
    'name': saved.name,
    'mimeType': saved.mimeType,
    'bytes': saved.bytes,
    'diary': {
      'id': updated.id,
      'title': updated.title,
      'media': {
        'images': updated.imageName,
        'audio': updated.audioName,
        'videos': updated.videoName,
        'files': updated.fileName,
      },
    },
  });
}

/// Parses the stored document, inserts [node] and persists the body with the
/// `document` write format so `DiaryWrites` re-derives the media lists.
Future<Diary> _insertNode(
  DiaryRepository diaries,
  CategoryRepository categories, {
  required Diary diary,
  required Map<String, dynamic> node,
  required bool atStart,
  required String newMediaName,
}) async {
  final parsed = TiptapContent.parse(diary.content);
  if (!parsed.isDoc) throw DiaryMediaException(_noDocumentMessage(diary));
  final document = jsonDecode(parsed.normalized) as Map<String, dynamic>;
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
    requireVisible: true,
    // The file was just written, so it is the one media name the body may add;
    // every other name has to be media the diary already references.
    enforceOwnMedia: true,
    extraAllowedMedia: {newMediaName},
  );
}

/// The message for a diary whose body is not a Tiptap document, so it cannot
/// carry a media node: the editor only shows nodes in a document body.
String _noDocumentMessage(Diary diary) =>
    'diary id="${diary.id}" stores ${diary.type} content instead of a Tiptap '
    'document, so no media node can be inserted; rewrite the body with '
    'update_diary contentFormat="document" first.';

/// Tool error when [diary] cannot hold a media node, `null` when it can.
///
/// The check runs before the payload is written, so a legacy diary does not
/// leave an orphan file behind.
McpToolResult? _documentError(String subject, Diary diary) =>
    TiptapContent.parse(diary.content).isDoc
    ? null
    : McpToolResult.error('$subject: ${_noDocumentMessage(diary)}');

/// Tool error text for a failed `DiaryWrites.update`.
String _opsFailureMessage(DiaryOpsException e, String id) =>
    switch (e.failure) {
      DiaryOpsFailure.notFound => 'no diary with id="$id".',
      DiaryOpsFailure.foreignMedia =>
        'content references a media file this diary does not own.',
      final failure => 'the diary could not be updated (${failure.name}).',
    };

/// Entries for [names], skipping names that could never be served safely.
Future<List<Map<String, dynamic>>> _mediaEntries(
  DiaryMediaStore media,
  DiaryMediaKind kind,
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

/// Decodes the `data` argument, checking the documented decoded size cap first.
///
/// A malformed payload is invalid params (the client can see its argument is
/// wrong); a payload over the cap is a tool error, because it is a limit of
/// this server rather than a protocol problem. The size estimate avoids
/// decoding a huge string only to reject it.
({Uint8List? bytes, McpToolResult? error}) _decodePayload(
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

McpToolResult _tooLarge(String subject, int bytes) => McpToolResult.error(
  '$subject: data decodes to ${formatMegabytes(bytes)} MB, more than the '
  '${_maxPayloadBytes ~/ (1024 * 1024)} MB limit per file; send a smaller file '
  'or attach it in the app.',
);

Uint8List _decodeBase64(String subject, String data) {
  final Uint8List bytes;
  try {
    bytes = base64Decode(data);
  } on FormatException {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$subject: data is not valid base64',
    );
  }
  if (bytes.isEmpty) {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$subject: data decodes to zero bytes',
    );
  }
  return bytes;
}

/// The image MIME type to store, or the reason it cannot be accepted.
///
/// The header is magic-number sniffed, so a client that lies about the type
/// cannot make the app store PNG bytes as a GIF; when the header matches
/// nothing, an explicit `mimeType` is trusted.
({String? mime, String? error}) _resolveImageMime(
  String? requested,
  Uint8List bytes,
) {
  final sniffed = _sniffMime(bytes);
  if (_heicMimeTypes.contains(requested) || _heicMimeTypes.contains(sniffed)) {
    return (
      mime: null,
      error:
          'HEIC/HEIF images are not supported by this build; convert the '
          'image to image/png, image/jpeg, image/webp or image/gif and call '
          'again.',
    );
  }
  final mime = requested ?? sniffed;
  if (mime == null) {
    return (
      mime: null,
      error:
          'the image type could not be determined; send mimeType (image/png, '
          'image/jpeg, image/webp or image/gif).',
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

/// Lowercased bare MIME type, with the common `image/jpg` alias normalized.
String? _normalizeMime(String? value) {
  if (value == null) return null;
  final base = value.split(';').first.trim().toLowerCase();
  if (base.isEmpty) return null;
  return base == 'image/jpg' ? 'image/jpeg' : base;
}

String? _sniffMime(Uint8List bytes) =>
    _normalizeMime(DiaryMediaStore.sniffMime('', bytes));

/// Last path segment of a client supplied file name, used as display name.
String _displayFileName(String fileName) {
  final base = fileName.replaceAll(r'\', '/').split('/').last.trim();
  return base.isEmpty ? 'attachment' : base;
}

String _mediaUri(String id, String name) =>
    'moodiary://diary/$id/media/${Uri.encodeComponent(name)}';
