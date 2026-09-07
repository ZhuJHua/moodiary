import 'dart:async';

typedef MediaResolver = FutureOr<({String path, String mime})?> Function(
  String name, {
  bool poster,
});

String imageMimeOf(String name) {
  return switch (_ext(name)) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'gif' => 'image/gif',
    _ => 'image/png',
  };
}

String audioMimeOf(String name) {
  return switch (_ext(name)) {
    'm4a' || 'mp4' => 'audio/mp4',
    'aac' => 'audio/aac',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'ogg' || 'oga' || 'opus' => 'audio/ogg',
    'flac' => 'audio/flac',
    'aiff' || 'aif' => 'audio/aiff',
    'amr' => 'audio/amr',
    '3gp' || '3gpp' => 'audio/3gpp',
    'caf' => 'audio/x-caf',
    _ => 'audio/mpeg',
  };
}

String videoMimeOf(String name) {
  return switch (_ext(name)) {
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    'avi' => 'video/x-msvideo',
    '3gp' || '3gpp' => 'video/3gpp',
    _ => 'video/mp4',
  };
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}
