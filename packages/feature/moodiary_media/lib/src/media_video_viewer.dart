import 'package:moodiary_components/moodiary_components.dart';

class MediaVideoViewer {
  const MediaVideoViewer._();

  static Future<void> show(BuildContext context, {required String name}) =>
      MVideoPlayerPage.showByName(context, name: name);
}
