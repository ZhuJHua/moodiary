/// 把正文媒体文件名解析为磁盘路径 + MIME 的注入式回调（由宿主 app 实现，注入给
/// [EditorLocalServer]）。返回 null 表示无法解析（按 404 处理）。宿主据自身存储布局
/// 决定目录（图片取 image 目录、音频取 audio 目录、视频取 video 目录）。
///
/// [poster] 为 true 时请求的是「海报/缩略图」而非媒体本身：视频节点的 webview 内播放器
/// 用它当封面（宿主返回 thumbnail 目录的 jpeg）；非视频忽略该标志。
typedef MediaResolver =
    ({String path, String mime})? Function(String name, {bool poster});

/// 根据文件名后缀推断图片 MIME（自包含，供宿主实现 [MediaResolver] 时复用）。
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

/// 根据文件名后缀推断音频 MIME（webview 内 <audio> 据此选解码器，故须尽量准确）。
/// 录音落库为 `.m4a`（MP4 容器/AAC），选取文件保留原后缀。
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

/// 根据文件名后缀推断视频 MIME（webview 内 <video> 据此选解码器）。落库视频统一为 `.mp4`。
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
