import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';

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
  testWidgets('video page opens an uppercase URL scheme as a network source', (
    tester,
  ) async {
    final port = _VideoPort();
    VideoSource? source;
    await tester.pumpWidget(
      muiTestApp(
        const MVideoPlayerPage(
          videoPath: 'HTTPS://example.com/video.mp4?token=test',
        ),
        overrides: [
          videoPlayerPortFactoryProvider.overrideWithValue((value) {
            source = value;
            return port;
          }),
          videoAmbientPortFactoryProvider.overrideWithValue(() => const {}),
          videoSurfaceBuilderProvider.overrideWithValue(
            (_) => const SizedBox(),
          ),
        ],
      ),
    );
    port.initialized.complete();
    await tester.pump();
    expect(
      source,
      isA<VideoNetworkSource>().having(
        (value) => value.uri,
        'uri',
        Uri.parse('https://example.com/video.mp4?token=test'),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
