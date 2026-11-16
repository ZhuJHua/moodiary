/// Reads media using the app's directories.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// One file saved through the app's media manager.
class SavedDiaryMedia {
  const SavedDiaryMedia({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;

  final String mimeType;

  final int bytes;
}

/// Presence and type of one media file a diary references.
class DiaryMediaStat {
  const DiaryMediaStat({
    required this.mimeType,
    required this.bytes,
    required this.exists,
  });

  final String mimeType;

  final int bytes;

  final bool exists;
}

/// Storage validation failure returned to the client as a tool error.
class DiaryMediaException implements Exception {
  const DiaryMediaException(this.message);

  final String message;

  @override
  String toString() => 'DiaryMediaException($message)';
}

/// Rejects path traversal even if a diary's media allowlist is corrupt.
bool isSafeMediaName(String name) =>
    name.isNotEmpty &&
    !name.startsWith('.') &&
    !name.contains('/') &&
    !name.contains(r'\') &&
    !name.contains('..');

Map<String, List<String>> mediaLists(Diary diary) => {
  'images': diary.imageName,
  'audio': diary.audioName,
  'videos': diary.videoName,
  'files': diary.fileName,
};

/// Document-derived media lists used as the read allowlist.
extension DiaryMediaReferences on Diary {
  List<String> mediaNamesOf(MediaType kind) => switch (kind) {
    MediaType.image => imageName,
    MediaType.audio => audioName,
    MediaType.video => videoName,
    MediaType.file => fileName,
  };

  MediaType? mediaKindOf(String name) {
    for (final kind in MediaType.values) {
      if (mediaNamesOf(kind).contains(name)) return kind;
    }
    return null;
  }
}

/// Reads app media. [pathOf] joins a fixed kind directory and
/// file name, allowing tests to use temporary storage.
class DiaryMediaStore {
  DiaryMediaStore({String Function(String kind, String name)? pathOf})
    : _pathOf = pathOf ?? AppFiles.getRealPath;

  static const List<String> supportedImageMimeTypes = [
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',
  ];

  final String Function(String kind, String name) _pathOf;

  static String? sniffMime(String name, Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final header = bytes.length > defaultMagicNumbersMaxLength
        ? bytes.sublist(0, defaultMagicNumbersMaxLength)
        : bytes;
    return lookupMimeType(name, headerBytes: header);
  }

  /// Callers validate the name and diary membership before resolving a path.
  String pathOf(MediaType kind, String name) => _pathOf(kind.value, name);

  Future<DiaryMediaStat> stat(MediaType kind, String name) async {
    final file = File(pathOf(kind, name));
    if (!await file.exists()) {
      return DiaryMediaStat(
        mimeType: _mimeTypeOf(kind, name, null),
        bytes: -1,
        exists: false,
      );
    }
    final header = await _readHeader(file);
    final bytes = await file.length();
    return DiaryMediaStat(
      mimeType: _mimeTypeOf(kind, name, header),
      bytes: bytes,
      exists: true,
    );
  }

  Future<Uint8List?> read(MediaType kind, String name) async {
    final file = File(pathOf(kind, name));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  String _mimeTypeOf(MediaType kind, String name, Uint8List? header) {
    final byName = lookupMimeType(name);
    final byHeader = header == null
        ? null
        : lookupMimeType(name, headerBytes: header);
    return switch (kind) {
      // The header is the truth for an image; the name is the app's extension.
      MediaType.image => byHeader ?? byName ?? 'image/png',
      // Playback follows the app's extension mapping, so prefer it here too.
      MediaType.audio => byName ?? byHeader ?? 'audio/mpeg',
      MediaType.video => byName ?? byHeader ?? 'video/mp4',
      // An attachment's extension can be anything; its bytes say more.
      MediaType.file => byHeader ?? byName ?? 'application/octet-stream',
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
