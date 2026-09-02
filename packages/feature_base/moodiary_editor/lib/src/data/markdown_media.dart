import 'package:moodiary_editor/moodiary_editor.dart'
    show audioMimeOf, imageMimeOf, videoMimeOf;
import 'package:moodiary_files/moodiary_files.dart';

/// app 侧媒体解析器：把正文媒体文件名解析为磁盘路径 + MIME，注入给编辑器包的
/// EditorLocalServer 按需读字节（支持 Range）。图片取 `image` 目录、音频取 `audio` 目录、
/// 视频取 `video` 目录的原片；视频海报（[poster] = true）取 `thumbnail`（落在 video 目录）的 jpeg。
Future<({String path, String mime})?> appMediaResolver(
  String name, {
  bool poster = false,
}) async {
  if (name.startsWith('video-')) {
    if (poster) {
      return (
        path: AppFiles.getRealPath('thumbnail', name),
        mime: 'image/jpeg',
      );
    }
    return (path: AppFiles.getRealPath('video', name), mime: videoMimeOf(name));
  }
  if (name.startsWith('audio-')) {
    return (path: AppFiles.getRealPath('audio', name), mime: audioMimeOf(name));
  }
  // 正文供 m 档缩略图；档位还没生成的（存量图片）供原图，webview 自己解——那是唯一
  // 一处原图会进 webview 的路，用户跑过「图片优化」就没有了。历史 `.heic` 这里不转码
  // （照旧破图），同样由「图片优化」一次性转成 JPG。MIME 按实际供出的文件定，不按正文里的名字。
  final display = await ImageDerivatives.resolve(
    AppFiles.getRealPath('image', name),
    tier: .m,
  );
  return (path: display, mime: imageMimeOf(display));
}
