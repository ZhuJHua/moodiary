import 'dart:io';

import 'package:mime/mime.dart';

Future<String?> sniffFileMime(String path) async {
  try {
    final file = await File(path).open();
    try {
      final header = await file.read(defaultMagicNumbersMaxLength);
      return lookupMimeType(path, headerBytes: header);
    } finally {
      await file.close();
    }
  } on FileSystemException {
    return lookupMimeType(path);
  }
}
