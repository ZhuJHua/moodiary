library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_content/moodiary_content.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../media/diary_media.dart';
import '../ops/diary_writes.dart';
import 'arguments.dart';
import 'diary_write_lock.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'tool_def.dart';
import 'tool_values.dart';

final RegExp _mimeTypePattern = RegExp(
  r'^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$',
);

const List<String> _positions = ['end', 'start'];

const List<String> _mediaKinds = ['image', 'audio', 'video', 'file'];

const int _maxPayloadBytes = 16 * 1024 * 1024;

@internal
final List<ToolDef> mediaTools = [
  ToolDef(
    name: 'list_diary_media',
    title: 'List the media of a diary',
    description: (_) =>
        'Lists every media file one diary references: images, audio, videos '
        'and file attachments. Each entry carries name, mimeType, bytes and '
        'exists; bytes is -1 when the file is missing from this device, and '
        'exists says whether the app media directory has it. Image names can '
        'be passed to read_diary_media.',
    input: (_) => S.object(properties: {'id': diaryIdSchema}, required: ['id']),
    surfaces: const {ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _listDiaryMediaOutput,
    parse: (raw) => ToolArguments('list_diary_media', raw).requireText('id'),
    run: (input, ctx) => _listDiaryMedia(input, ctx),
  ),
  ToolDef(
    name: 'read_diary_media',
    title: 'Read one media file of a diary',
    description: (_) =>
        'Returns one image of one diary as an MCP '
        'image content item (base64) plus a JSON metadata text item; images '
        'larger than 8 MB are refused instead of truncated. Audio, video and '
        'file attachments return a tool error: only images can be read. '
        'kind is inferred from the diary references when omitted. The name '
        'must be one of the images that diary references.',
    input: (_) => S.object(
      properties: {
        'id': diaryIdSchema,
        'name': mediaNameSchema,
        'kind': nullableSchema(
          S.string(
            enumValues: _mediaKinds,
            description:
                'Media kind, inferred from the diary references when omitted. '
                'Only image can be read; other kinds return a tool error.',
          ),
          JsonType.string,
        ),
      },
      required: ['id', 'name'],
    ),
    surfaces: const {ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _readDiaryMediaOutput,
    parse: _parseReadDiaryMedia,
    run: (input, ctx) => _readDiaryMedia(input, ctx),
  ),
  ToolDef(
    name: 'add_diary_image',
    title: 'Attach an image to a diary',
    description: (_) =>
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
    input: (_) => S.object(
      properties: {
        'id': diaryIdSchema,
        'data': S.string(
          description:
              'Base64 of the image file, no data: URL prefix. At most 16 MB '
              'decoded.',
        ),
        'mimeType': nullableSchema(
          S.string(
            description:
                'MIME type of the image: image/png, image/jpeg, image/webp, '
                'image/gif, image/heic or image/heif. Omitted: sniffed from data.',
          ),
          JsonType.string,
        ),
        'name': nullableSchema(
          S.string(
            description:
                'Display name stored on the image node, usually the original '
                'file name. Defaults to the stored file name.',
          ),
          JsonType.string,
        ),
        'position': nullableSchema(
          schemaWithDefault(
            S.string(
              enumValues: _positions,
              description:
                  'Where in the top-level body the image node goes: end '
                  '(default) appends it after the last block, start puts it '
                  'before the first.',
            ),
            'end',
          ),
          JsonType.string,
        ),
        'widthPercent': nullableSchema(
          S.integer(
            description:
                'Image width as a percentage of the content width, clamped '
                'into ${imageWidth.min}..${imageWidth.max}. Omitted or null writes no width attribute, so '
                'the document default applies. The document store keeps values '
                'from 25 to 100, so 10..24 is raised to 25.',
          ),
          JsonType.int,
        ),
      },
      required: ['id', 'data'],
    ),
    surfaces: const {ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: _addDiaryImageOutput,
    parse: _parseAddDiaryImage,
    run: (input, ctx) => _addDiaryImage(input, ctx),
  ),
  ToolDef(
    name: 'add_diary_attachment',
    title: 'Attach a file to a diary',
    description: (_) =>
        'Attaches one file to an existing diary: the bytes are written into '
        'the app file directory with the app naming scheme and an attachment '
        'node (src, name, mime, size) is inserted at the end of the document '
        'body, then the diary is persisted. data is base64 of the file, at '
        'most 16 MB decoded. fileName is required and supplies both the '
        'display name on the node and the stored extension; an unusable '
        'extension becomes .bin. mimeType is sniffed from the bytes and the '
        'name when omitted. The response reports the stored file name and '
        'the updated media lists instead of the whole body.',
    input: (_) => S.object(
      properties: {
        'id': diaryIdSchema,
        'data': S.string(
          description:
              'Base64 of the file, no data: URL prefix. At most 16 MB '
              'decoded.',
        ),
        'fileName': S.string(
          description:
              'Original file name, e.g. "report.pdf"; used as the display '
              'name and for the stored extension.',
        ),
        'mimeType': nullableSchema(
          S.string(
            description:
                'MIME type of the file, e.g. application/pdf. Omitted: '
                'sniffed from data and the file name.',
          ),
          JsonType.string,
        ),
      },
      required: ['id', 'data', 'fileName'],
    ),
    surfaces: const {ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: _addDiaryAttachmentOutput,
    parse: _parseAddDiaryAttachment,
    run: (input, ctx) => _addDiaryAttachment(input, ctx),
  ),
];

Future<ToolResult> _listDiaryMedia(String id, ToolContext ctx) async {
  final diaries = ctx.diaries;
  final media = ctx.mediaStore;

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolFailure('list_diary_media: no diary with id="$id".');
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
  return ToolResult({
    'id': diary.id,
    'title': diary.title,
    'media': entries,
    'count': entries.values.fold<int>(0, (count, rows) => count + rows.length),
  });
}

Future<ToolResult> _readDiaryMedia(
  _ReadDiaryMediaInput input,
  ToolContext ctx,
) async {
  final diaries = ctx.diaries;
  final media = ctx.mediaStore;

  final (:id, :name, :kindName) = input;
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolFailure('read_diary_media: no diary with id="$id".');
  }
  final kind = kindName == null
      ? diary.mediaKindOf(name)
      : MediaType.values.byName(kindName);
  // Require diary membership even when the client supplies a kind.
  if (!isSafeMediaName(name) ||
      kind == null ||
      !diary.mediaNamesOf(kind).contains(name)) {
    return toolFailure(
      'read_diary_media: diary id="$id" has no ${kind?.value ?? 'image'} media named '
      '"$name"; list_diary_media shows the names and kinds that may be read.',
    );
  }
  if (kind != MediaType.image) {
    return toolFailure('read_diary_media: only images can be read.');
  }
  final stat = await media.stat(kind, name);
  if (!stat.exists) {
    return toolFailure(
      'read_diary_media: "$name" is listed in diary id="$id" but is missing '
      'from the ${kind.value} media directory on this device.',
    );
  }
  if (stat.bytes > _inlineBytes) {
    return toolFailure(
      'read_diary_media: the image "$name" is ${_megabytes(stat.bytes)} '
      'MB, more than the ${_megabytes(_inlineBytes)} MB inline '
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
    return toolFailure(
      'read_diary_media: "$name" of diary id="$id" disappeared while it was '
      'being read; call list_diary_media and try again.',
    );
  }
  if (bytes.length > _inlineBytes) {
    return toolFailure(
      'read_diary_media: the image "$name" is ${_megabytes(bytes.length)} '
      'MB, more than the ${_megabytes(_inlineBytes)} MB inline '
      'limit, so it is not returned. The file is still on the device; open the '
      'diary in the app to view it.',
    );
  }
  return ToolResult(
    metadata,
    media: [ToolMedia(bytes: bytes, mimeType: stat.mimeType)],
  );
}

Future<ToolResult> _addDiaryImage(
  _AddDiaryImageInput input,
  ToolContext ctx,
) async {
  final diaries = ctx.diaries;
  final media = ctx.mediaStore;
  final categories = ctx.categories;

  const subject = 'add_diary_image';
  final (:id, :data, :position, :requestedMime, :displayName, :widthPercent) =
      input;
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolFailure('$subject: no diary with id="$id".');
  }
  _requireDocument(subject, diary);
  final bytes = _decodePayload(subject, data);

  final mime = _resolveImageMime(subject, requestedMime, bytes);
  final SavedDiaryMedia saved;
  try {
    saved = await _saveMedia(
      media,
      bytes,
      kind: MediaType.image,
      fileName: 'upload.${mime.split('/').last}',
      mimeType: mime,
      heifDecoder: ctx.heifDecoder,
    );
  } on DiaryMediaException catch (e) {
    return toolFailure('$subject: ${e.message}');
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
    ctx.tags,
    subject: subject,
    diary: diary,
    node: node,
    atStart: position == 'start',
    saved: saved,
  );
}

Future<ToolResult> _addDiaryAttachment(
  _AddDiaryAttachmentInput input,
  ToolContext ctx,
) async {
  final diaries = ctx.diaries;
  final media = ctx.mediaStore;
  final categories = ctx.categories;

  const subject = 'add_diary_attachment';
  final (:id, :data, :fileName, :requestedMime) = input;
  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null || !diary.show) {
    return toolFailure('$subject: no diary with id="$id".');
  }
  _requireDocument(subject, diary);
  final bytes = _decodePayload(subject, data);

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
    return toolFailure('$subject: ${e.message}');
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
    ctx.tags,
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
  IHeifDecoder? heifDecoder,
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
      final name = await MediaManager.saveImage(
        input,
        decoder: heifDecoder,
        reuseExisting: false,
      );
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

Future<ToolResult> _persistNode(
  DiaryRepository diaries,
  CategoryRepository categories,
  TagRepository tags, {
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
      tags,
      diaryId: diary.id,
      node: node,
      atStart: atStart,
      newMediaName: saved.name,
    );
  } on DiaryMediaException catch (e) {
    return toolFailure('$subject: ${e.message}');
  } on DiaryOpsException catch (e) {
    return toolFailure('$subject: ${_opsFailureMessage(e, diary.id)}');
  }
  return ToolResult({
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

Future<Diary> _insertNode(
  DiaryRepository diaries,
  CategoryRepository categories,
  TagRepository tags, {
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
  return DiaryWrites(
    tags: tags,
    diaries: diaries,
    categories: categories,
  ).update(
    id: diary.id,
    patch: DiaryPatch(content: jsonEncode(document)),
    format: DiaryContentFormat.document,
    // Only the newly saved file may extend the diary media allowlist.
    enforceOwnMedia: true,
    extraAllowedMedia: {newMediaName},
  );
});

String _noDocumentMessage(Diary diary) =>
    'diary id="${diary.id}" stores ${diary.type} content instead of a Tiptap '
    'document, so no media node can be inserted; rewrite the body with '
    'update_diary contentFormat="document" first.';

/// Rejects legacy bodies before writing files to avoid orphan media.
void _requireDocument(String subject, Diary diary) {
  if (!TiptapContent.parse(diary.content).isDoc) {
    toolFailure('$subject: ${_noDocumentMessage(diary)}');
  }
}

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

/// Check the encoded size before allocating decoded bytes.
Uint8List _decodePayload(String subject, String data) {
  final estimate = (data.length * 3) ~/ 4;
  if (estimate > _maxPayloadBytes) {
    _tooLarge(subject, estimate);
  }
  final bytes = _decodeBase64(subject, data);
  if (bytes.length > _maxPayloadBytes) {
    _tooLarge(subject, bytes.length);
  }
  return bytes;
}

Never _tooLarge(String subject, int bytes) => toolFailure(
  '$subject: data decodes to ${_megabytes(bytes)} MB, more than the '
  '${_megabytes(_maxPayloadBytes)} MB limit per file; send a smaller file '
  'or attach it in the app.',
);

Uint8List _decodeBase64(String subject, String data) {
  final Uint8List bytes;
  try {
    bytes = base64Decode(data);
  } on FormatException {
    throw ToolArgumentException('$subject: data is not valid base64');
  }
  if (bytes.isEmpty) {
    throw ToolArgumentException('$subject: data decodes to zero bytes');
  }
  return bytes;
}

/// Sniffs image headers first; trusts explicit MIME only for unknown headers.
String _resolveImageMime(String subject, String? requested, Uint8List bytes) {
  final sniffed = _sniffMime(bytes);
  final mime = requested ?? sniffed;
  if (mime == null) {
    toolFailure(
      '$subject: the image type could not be determined; send mimeType '
      '(${DiaryMediaStore.supportedImageMimeTypes.join(', ')}).',
    );
  }
  if (!DiaryMediaStore.supportedImageMimeTypes.contains(mime)) {
    toolFailure(
      '$subject: mimeType "$mime" is not supported; supported image types are '
      '${DiaryMediaStore.supportedImageMimeTypes.join(', ')}.',
    );
  }
  if (sniffed != null && sniffed != mime) {
    toolFailure(
      '$subject: data looks like $sniffed but mimeType is $mime; send the actual '
      'image type or convert the image first.',
    );
  }
  return mime;
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

typedef _ReadDiaryMediaInput = ({String id, String name, String? kindName});

_ReadDiaryMediaInput _parseReadDiaryMedia(Map<String, Object?> raw) {
  final args = ToolArguments('read_diary_media', raw);
  final id = args.requireText('id');
  final name = args.requireText('name');
  final kindName = args.optionalText('kind');
  return (id: id, name: name, kindName: kindName);
}

typedef _AddDiaryImageInput = ({
  String id,
  String data,
  String position,
  String? requestedMime,
  String? displayName,
  int? widthPercent,
});

_AddDiaryImageInput _parseAddDiaryImage(Map<String, Object?> raw) {
  const subject = 'add_diary_image';
  final args = ToolArguments(subject, raw);
  final id = args.requireText('id');
  final data = args.requireText('data');
  final position = args.optionalText('position') ?? 'end';
  final requestedMime = _normalizeMime(args.optionalText('mimeType'));
  final displayName = args.optionalText('name');
  final widthPercent = args.contains('widthPercent')
      ? args.optionalInt('widthPercent', imageWidth)
      : null;

  return (
    id: id,
    data: data,
    position: position,
    requestedMime: requestedMime,
    displayName: displayName,
    widthPercent: widthPercent,
  );
}

typedef _AddDiaryAttachmentInput = ({
  String id,
  String data,
  String fileName,
  String? requestedMime,
});

_AddDiaryAttachmentInput _parseAddDiaryAttachment(Map<String, Object?> raw) {
  const subject = 'add_diary_attachment';
  final args = ToolArguments(subject, raw);
  final id = args.requireText('id');
  final data = args.requireText('data');
  final fileName = _displayFileName(args.requireText('fileName'));
  final requestedMime = _normalizeMime(args.optionalText('mimeType'));
  if (requestedMime != null && !_mimeTypePattern.hasMatch(requestedMime)) {
    throw const ToolArgumentException(
      '$subject: mimeType must look like "type/subtype"',
    );
  }

  return (id: id, data: data, fileName: fileName, requestedMime: requestedMime);
}

const int _inlineBytes = 8 * 1024 * 1024;
String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

final _listDiaryMediaOutput = objectSchema({
  'id': stringOutputSchema,
  'title': stringOutputSchema,
  'media': objectSchema({
    for (final key in ['images', 'audio', 'videos', 'files'])
      key: listOutputSchema(mediaEntryOutputSchema),
  }),
  'count': integerOutputSchema,
});

final _readDiaryMediaOutput = objectSchema({
  'id': stringOutputSchema,
  'title': stringOutputSchema,
  'name': stringOutputSchema,
  'kind': stringOutputSchema,
  'mimeType': stringOutputSchema,
  'bytes': integerOutputSchema,
  'exists': booleanOutputSchema,
});

final _addDiaryImageOutput = objectSchema({
  'added': booleanOutputSchema,
  'name': stringOutputSchema,
  'mimeType': stringOutputSchema,
  'bytes': integerOutputSchema,
  'diary': objectSchema({
    'id': stringOutputSchema,
    'title': stringOutputSchema,
    'media': mediaListsOutputSchema,
  }),
});

final _addDiaryAttachmentOutput = objectSchema({
  'added': booleanOutputSchema,
  'name': stringOutputSchema,
  'mimeType': stringOutputSchema,
  'bytes': integerOutputSchema,
  'diary': objectSchema({
    'id': stringOutputSchema,
    'title': stringOutputSchema,
    'media': mediaListsOutputSchema,
  }),
});
