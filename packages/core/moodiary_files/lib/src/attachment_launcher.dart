import 'dart:io';

import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';

import 'app_files.dart';
import 'mime_sniff.dart';

abstract final class AttachmentLauncher {
  static bool isValidName(String fileName) =>
      fileName.isNotEmpty &&
      fileName != '.' &&
      fileName != '..' &&
      !fileName.contains('/') &&
      !fileName.contains(r'\') &&
      !fileName.contains('\x00');

  static File? localFile(String fileName) {
    if (!isValidName(fileName)) return null;
    return File(AppFiles.getRealPath('file', fileName));
  }

  static Future<String?> mimeOf(String fileName) async {
    final path = localFile(fileName)?.path;
    return path == null ? null : _mimeForPath(path);
  }

  static Future<String?> _mimeForPath(String path) async {
    final mime = lookupMimeType(path);
    return mime == null || mime == 'application/octet-stream'
        ? sniffFileMime(path)
        : mime;
  }

  static Future<bool> open(String fileName, {String? mime}) async {
    try {
      final path = localFile(fileName)?.path;
      if (path == null) return false;
      return await openPath(path, mime: mime);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openPath(String path, {String? mime}) async {
    try {
      final result = await OpenFile.open(
        path,
        type: mime ?? await _mimeForPath(path),
      );
      return result.type == .done;
    } catch (_) {
      return false;
    }
  }
}
