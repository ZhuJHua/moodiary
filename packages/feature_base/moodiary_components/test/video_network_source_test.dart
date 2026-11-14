import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:video_player/video_player.dart';

import 'support/pump.dart';

class _VideoPort implements VideoPlaybackPort {
  final initialized = Completer<void>();
  final events = StreamController<VideoPortSnapshot>.broadcast();
  @override
  Stream<VideoPortSnapshot> get snapshots => events.stream;
  @override
  VideoPortSnapshot get snapshot => const VideoPortSnapshot(
    isInitialized: true,
    isPlaying: false,
    isBuffering: false,
    isCompleted: false,
    position: Duration.zero,
    duration: Duration(seconds: 10),
    width: 200,
    height: 100,
    rotationDegrees: 0,
    errorMessage: null,
  );
  @override
  Future<void> initialize() => initialized.future;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> dispose() => events.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'remote media uses a network video controller with its full URI',
    () async {
      final uri = Uri.parse('https://example.com/video.mp4?token=test');
      final port = VideoPlayerPluginPort(VideoSource.network(uri));
      final surface = port.buildSurface() as VideoPlayer;
      expect(surface.controller.dataSourceType, DataSourceType.network);
      expect(surface.controller.dataSource, uri.toString());
      await port.dispose();
    },
  );
  testWidgets('video page opens an uppercase URL scheme as a network source', (
    tester,
  ) async {
    final port = _VideoPort();
    VideoSource? source;
    await tester.pumpWidget(
      muiTestApp(
        MVideoPlayerPage(
          videoPath: 'HTTPS://example.com/video.mp4',
          portFactory: (value) {
            source = value;
            return port;
          },
          ambientPorts: const {},
          surfaceBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    port.initialized.complete();
    await tester.pump();
    expect(
      source,
      isA<VideoNetworkSource>().having(
        (value) => value.uri,
        'uri',
        Uri.parse('https://example.com/video.mp4'),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
