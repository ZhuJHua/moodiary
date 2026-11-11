/// Storage layer for the media files an MCP client reads and writes.
///
/// The layout is the app's own: images live in `image/`, audio in `audio/`,
/// video in `video/` and attachments in `file/` under the application support
/// directory, with the app's `image-<uuid v7>.<ext>` and
/// `file-<uuid v7><ext>` naming. Writing through this store therefore makes a
/// file visible in the editor without an import step, and a file the app wrote
/// can be handed back to a client unchanged.
///
/// The store deliberately does not depend on the HEIF decoder or on the image
/// pipeline (`getIt`, thumbnails, derivatives): MCP only attaches the common
/// web image formats and returns bytes, so a build without the native decoders
/// still works. It also does not touch the diary database; the tools insert
/// the Tiptap node and persist the diary through `DiaryWrites`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// The app's four media directories, in the order the editor shows them.
///
/// The directory name matches `MediaType.value` one to one; [fromName] follows
/// the same prefix rule the editor's `appMediaResolver` uses.
enum DiaryMediaKind {
  image('image'),
  audio('audio'),
  video('video'),
  file('file');

  const DiaryMediaKind(this.directory);

  /// Directory under the application support path, e.g. `image`.
  final String directory;

  /// Kind inferred from the app's file naming convention.
  ///
  /// The app names video files `video-…`, audio files `audio-…`, attachments
  /// `file-…` and everything else (images) `image-…`. Only the tools use this
  /// shortcut when a client omits `kind`; membership in a diary's media lists
  /// is still checked afterwards.
  static DiaryMediaKind fromName(String name) {
    if (name.startsWith('video-')) return video;
    if (name.startsWith('audio-')) return audio;
    if (name.startsWith('file-')) return file;
    return image;
  }

  /// The core media type, needed only to reserve the name in [MediaHolds].
  MediaType get _mediaType => switch (this) {
    .image => MediaType.image,
    .audio => MediaType.audio,
    .video => MediaType.video,
    .file => MediaType.file,
  };
}

/// One file the store just wrote.
class SavedDiaryMedia {
  const SavedDiaryMedia({
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.bytes,
  });

  /// Stored file name, i.e. the `src` of the Tiptap media node.
  final String name;

  final DiaryMediaKind kind;

  /// MIME type the file is served as; never empty.
  final String mimeType;

  /// Size of the written file.
  final int bytes;
}

/// Presence and type of one media file a diary references.
class DiaryMediaStat {
  const DiaryMediaStat({
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.bytes,
    required this.exists,
  });

  final String name;
  final DiaryMediaKind kind;

  /// MIME type derived from the header bytes when the file exists, otherwise
  /// from the name's extension; never empty.
  final String mimeType;

  /// File size in bytes, or `-1` when the file could not be read.
  final int bytes;

  /// Whether the file is present in the media directory.
  final bool exists;
}

/// A media operation the store refused, with text a tool can show a model.
///
/// Validation failures that are the client's mistake (bad MIME type, node the
/// store cannot write) use this exception; the tools turn it into a readable
/// tool error instead of a protocol error, because the client can act on it.
class DiaryMediaException implements Exception {
  const DiaryMediaException(this.message);

  /// Already user facing English.
  final String message;

  @override
  String toString() => 'DiaryMediaException($message)';
}

/// Whether [name] may be used as exactly one path segment of a media path.
///
/// Media names are the app's own file names, but they also reach the server
/// from clients (`read_diary_media` and the media resource). Membership in a
/// diary's media list is the primary check; this guard is the second layer so
/// a corrupt list still cannot make the server read `..`, absolute paths or a
/// Windows drive path.
bool isSafeMediaName(String name) =>
    name.isNotEmpty &&
    !name.startsWith('.') &&
    !name.contains('/') &&
    !name.contains(r'\') &&
    !name.contains('..');

/// [bytes] as megabytes with one decimal, for the limit messages a tool shows.
String formatMegabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

/// The media references a stored [Diary] carries.
///
/// The four lists are derived from the document's media nodes, so they are the
/// allowlist the server checks a client supplied name against.
extension DiaryMediaReferences on Diary {
  /// Names of [kind] this diary references, in document order.
  List<String> mediaNamesOf(DiaryMediaKind kind) => switch (kind) {
    DiaryMediaKind.image => imageName,
    DiaryMediaKind.audio => audioName,
    DiaryMediaKind.video => videoName,
    DiaryMediaKind.file => fileName,
  };

  /// The kind whose list holds [name], or `null` when the diary does not
  /// reference it.
  DiaryMediaKind? mediaKindOf(String name) {
    for (final kind in DiaryMediaKind.values) {
      if (mediaNamesOf(kind).contains(name)) return kind;
    }
    return null;
  }

  /// Whether [name] is exactly one of the media files this diary references.
  bool hasMedia(String name) =>
      isSafeMediaName(name) && mediaKindOf(name) != null;
}

/// Writes and reads files in the app media directories.
///
/// [pathOf] exists so tests (and a host with a custom support directory) can
/// redirect every path without touching `PlatformService`; it receives the
/// fixed kind directory and the file name, so joining them is the only thing an
/// implementation should do.
class DiaryMediaStore {
  DiaryMediaStore({String Function(String kind, String name)? pathOf})
    : _pathOf = pathOf ?? AppFiles.getRealPath;

  /// MIME types `add_diary_image` accepts, in error text order.
  static const List<String> supportedImageMimeTypes = [
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  ];

  /// Extension the app uses for each accepted image MIME type.
  static const Map<String, String> _imageExtensions = {
    'image/png': '.png',
    'image/jpeg': '.jpg',
    'image/webp': '.webp',
    'image/gif': '.gif',
  };

  /// Same rule as `MediaManager.saveAttachment`: one dot, then a short and
  /// alphanumeric extension, otherwise the attachment gets `.bin`.
  static final RegExp _safeExtension = RegExp(r'^\.[a-z0-9]{1,10}$');

  final String Function(String kind, String name) _pathOf;

  /// MIME type [bytes] (and [name], when it has an extension) identify, or
  /// `null` when neither the header nor the name says anything.
  ///
  /// The tools sniff a client payload with this before [saveImage], so one rule
  /// decides both what is accepted and what the file is served as.
  static String? sniffMime(String name, Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final header = bytes.length > defaultMagicNumbersMaxLength
        ? bytes.sublist(0, defaultMagicNumbersMaxLength)
        : bytes;
    return lookupMimeType(name, headerBytes: header);
  }

  /// Absolute path of [name] inside the fixed directory of [kind].
  ///
  /// The kind directory always comes from the store; a client supplied name is
  /// only appended after [isSafeMediaName] and the diary allowlist passed.
  String pathOf(DiaryMediaKind kind, String name) =>
      _pathOf(kind.directory, name);

  /// Writes one image and returns its app file name.
  ///
  /// [mimeType] must be one of [supportedImageMimeTypes]; the caller sniffs and
  /// validates the payload first, because this layer has no image decoder and
  /// cannot turn another format into a supported one.
  Future<SavedDiaryMedia> saveImage(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final extension = _imageExtensions[mimeType];
    if (extension == null) {
      throw DiaryMediaException(
        'unsupported image type "$mimeType"; supported types are '
        '${supportedImageMimeTypes.join(', ')}',
      );
    }
    final name = 'image-${uuidV7()}$extension';
    return _write(DiaryMediaKind.image, name, bytes, mimeType: mimeType);
  }

  /// Writes one attachment and returns its app file name.
  ///
  /// The extension comes from [fileName] and is sanitized exactly like the
  /// editor's attachment pipeline; an unusable extension becomes `.bin`, which
  /// keeps the stored name a single safe path segment.
  Future<SavedDiaryMedia> saveAttachment(
    Uint8List bytes, {
    required String fileName,
    String? mimeType,
  }) async {
    final name = 'file-${uuidV7()}${_extensionOf(fileName)}';
    final mime =
        _nonEmptyMime(mimeType) ??
        DiaryMediaStore.sniffMime(name, bytes) ??
        'application/octet-stream';
    return _write(DiaryMediaKind.file, name, bytes, mimeType: mime);
  }

  /// Presence, size and MIME type of [name].
  ///
  /// Never throws for a missing file: `exists` is `false` and `bytes` is `-1`,
  /// so a tool can report a diary that references a file the device no longer
  /// has without failing the whole listing.
  Future<DiaryMediaStat> stat(DiaryMediaKind kind, String name) async {
    final file = File(pathOf(kind, name));
    if (!await file.exists()) {
      return DiaryMediaStat(
        name: name,
        kind: kind,
        mimeType: _mimeTypeOf(kind, name, null),
        bytes: -1,
        exists: false,
      );
    }
    final header = await _readHeader(file);
    final bytes = await file.length();
    return DiaryMediaStat(
      name: name,
      kind: kind,
      mimeType: _mimeTypeOf(kind, name, header),
      bytes: bytes,
      exists: true,
    );
  }

  /// Bytes of [name], or `null` when the file is not on disk.
  Future<Uint8List?> read(DiaryMediaKind kind, String name) async {
    final file = File(pathOf(kind, name));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<SavedDiaryMedia> _write(
    DiaryMediaKind kind,
    String name,
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final path = pathOf(kind, name);
    // Reserve the name before the write, exactly like MediaManager does: the
    // unused-media cleaner must not delete an in-flight (or not yet committed)
    // file. Holds last until the process ends, so a diary commit failure leaves
    // an orphan the next launch cleans up instead of a live reference to a
    // deleted file.
    MediaHolds.add(kind._mediaType, name);
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      await _deleteQuietly(path);
      throw DiaryMediaException(
        'the app could not write "$name" to the ${kind.directory} directory',
      );
    }
    return SavedDiaryMedia(
      name: name,
      kind: kind,
      mimeType: mimeType,
      bytes: bytes.length,
    );
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The write already failed; a leftover partial file is not actionable.
    }
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '.bin';
    final extension = fileName.substring(dot).toLowerCase();
    return _safeExtension.hasMatch(extension) ? extension : '.bin';
  }

  String? _nonEmptyMime(String? mimeType) {
    final trimmed = mimeType?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _mimeTypeOf(DiaryMediaKind kind, String name, Uint8List? header) {
    final byName = lookupMimeType(name);
    final byHeader = header == null
        ? null
        : lookupMimeType(name, headerBytes: header);
    return switch (kind) {
      // The header is the truth for an image; the name is the app's extension.
      DiaryMediaKind.image => byHeader ?? byName ?? 'image/png',
      // Playback follows the app's extension mapping, so prefer it here too.
      DiaryMediaKind.audio => byName ?? byHeader ?? 'audio/mpeg',
      DiaryMediaKind.video => byName ?? byHeader ?? 'video/mp4',
      // An attachment's extension can be anything; its bytes say more.
      DiaryMediaKind.file => byHeader ?? byName ?? 'application/octet-stream',
    };
  }

  Future<Uint8List?> _readHeader(File file) async {
    RandomAccessFile? reader;
    try {
      reader = await file.open();
      return await reader.read(defaultMagicNumbersMaxLength);
    } catch (_) {
      return null;
    } finally {
      await reader?.close();
    }
  }
}
