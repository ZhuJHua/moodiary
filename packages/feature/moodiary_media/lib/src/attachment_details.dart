import 'dart:convert';
import 'dart:io';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:path/path.dart' as path;

String attachmentExtension(String displayName, String storedName) {
  final extension = path.extension(displayName);
  final value = extension.length > 1 ? extension : path.extension(storedName);
  return value.length > 1 ? value.substring(1) : '';
}

String attachmentSubtitle(String extension, int? bytes, String waitingSync) {
  if (bytes == null) return waitingSync;
  final units = AppFiles.bytesToUnits(bytes);
  final size = '${units['size']} ${units['unit']}';
  return extension.isEmpty ? size : '${extension.toUpperCase()} · $size';
}

String attachmentDetailMeta({
  String extension = '',
  String? duration,
  required int? bytes,
  required String waitingSync,
  required String date,
}) => [
  if (extension.isNotEmpty) extension.toUpperCase(),
  ?duration,
  attachmentSubtitle('', bytes, waitingSync),
  date,
].join(' · ');

String attachmentShareName(String displayName, String storedName) {
  final basename = path.posix.basename(displayName.replaceAll('\\', '/'));
  final sanitized = basename
      .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[. ]+$'), '');
  final name = sanitized.isEmpty ? path.basename(storedName) : sanitized;
  final storedExtension = path.extension(storedName);
  final displayExtension = path.extension(name);
  final desiredExtension =
      storedExtension.toLowerCase() == '.bin' && displayExtension.isNotEmpty
      ? displayExtension
      : storedExtension;
  const maxBytes = 255;
  final suffix = utf8.encode(desiredExtension).length < maxBytes
      ? desiredExtension
      : '';
  final hasExtension = name.toLowerCase().endsWith(suffix.toLowerCase());
  final stemEnd = hasExtension ? name.length - suffix.length : name.length;
  final extension = hasExtension ? name.substring(stemEnd) : suffix;
  final stem = name.substring(0, stemEnd);
  final labelBytes = utf8.encode(stem);
  var end = maxBytes - utf8.encode(extension).length;
  if (labelBytes.length <= end) return '$stem$extension';
  while ((labelBytes[end] & 0xc0) == 0x80) {
    end--;
  }
  return '${utf8.decode(labelBytes.sublist(0, end))}$extension';
}

Future<File> stageAttachmentCopy(
  Directory cache,
  File source,
  String displayName, {
  required String prefix,
}) async {
  await for (final entry in cache.list(followLinks: false)) {
    if (entry is Directory && path.basename(entry.path).startsWith(prefix)) {
      await entry.delete(recursive: true);
    }
  }
  final directory = await cache.createTemp(prefix);
  try {
    final name = attachmentShareName(displayName, path.basename(source.path));
    return await source.copy(path.join(directory.path, name));
  } catch (_) {
    await AppFiles.deleteDir(directory.path);
    rethrow;
  }
}
