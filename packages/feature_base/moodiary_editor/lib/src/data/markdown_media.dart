import 'package:fast_image/fast_image.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show audioMimeOf, imageMimeOf, videoMimeOf;
import 'package:moodiary_files/moodiary_files.dart';

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
  final display = await FastImageDerivatives.resolve(
    AppFiles.getRealPath('image', name),
    tier: .m,
  );
  return (path: display, mime: imageMimeOf(display));
}
