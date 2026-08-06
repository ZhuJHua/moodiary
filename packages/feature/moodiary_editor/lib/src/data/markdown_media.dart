import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show audioMimeOf, imageMimeOf, videoMimeOf;

/// app 侧媒体解析器：把正文媒体文件名解析为磁盘路径 + MIME，注入给编辑器包的
/// EditorLocalServer 按需读字节（支持 Range）。图片取 `image` 目录、音频取 `audio` 目录、
/// 视频取 `video` 目录的原片；视频海报（[poster] = true）取 `thumbnail`（落在 video 目录）的 jpeg。
({String path, String mime})? appMediaResolver(
  String name, {
  bool poster = false,
}) {
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
  return (path: AppFiles.getRealPath('image', name), mime: imageMimeOf(name));
}
