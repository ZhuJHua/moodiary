import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('remote media uses a network video controller with its full URI', () async {
    final uri = Uri.parse('https://example.com/video.mp4?token=test');
    final port = VideoPlayerPluginPort(VideoSource.network(uri));
    final surface = port.buildSurface() as VideoPlayer;
    expect(surface.controller.dataSourceType, DataSourceType.network);
    expect(surface.controller.dataSource, uri.toString());
    await port.dispose();
  });
}
