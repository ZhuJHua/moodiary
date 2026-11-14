import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:mui/mui.dart';

void main() {
  test(
    'a paused initialized video requests its first frame without autoplay',
    () async {
      final port = _PreviewPort();
      final video = MVideoPlaybackController(
        source: const VideoSource.file('/video.mp4'),
        portFactory: (_) => port,
        autoPlay: false,
      );
      addTearDown(video.dispose);
      await video.initialize();
      await revealVideoFirstFrame(video);
      expect(port.seeks, [const Duration(milliseconds: 1), Duration.zero]);
      expect(port.played, false);
      expect(video.state.value.isPlayIntent, false);
    },
  );
  test(
    'unregistered code language uses the common auto highlighter and themes',
    () {
      const code = '// B18 Code\nfinal value = 42;\nprint(value);';
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final span = buildCodeHighlight('dart', code, brightness);
        expect(span.toPlainText(), code);
        final runs = <(String, Color?)>[];
        void visit(TextSpan s, Color? inherited) {
          final color = s.style?.color ?? inherited;
          if (s.text != null) runs.add((s.text!, color));
          for (final c in s.children ?? <InlineSpan>[]) {
            if (c is TextSpan) visit(c, color);
          }
        }

        visit(span, null);
        final blue = brightness == Brightness.light
            ? const Color(0xff005cc5)
            : const Color(0xff79c0ff);
        expect(runs.any((r) => r.$1.contains('42') && r.$2 == blue), true);
        expect(
          runs.any((r) => r.$1.contains('value') && r.$2 == blue),
          true,
          reason: '$runs',
        );
      }
    },
  );
}

class _PreviewPort implements VideoPlaybackPort {
  final seeks = <Duration>[];
  bool played = false;
  @override
  Stream<VideoPortSnapshot> get snapshots => const Stream.empty();
  @override
  VideoPortSnapshot get snapshot => const VideoPortSnapshot(
    isInitialized: true,
    isPlaying: false,
    isBuffering: false,
    isCompleted: false,
    position: Duration.zero,
    duration: Duration(seconds: 5),
    width: 400,
    height: 225,
    rotationDegrees: 0,
    errorMessage: null,
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> seekTo(Duration position) async => seeks.add(position);
  @override
  Future<void> play() async => played = true;
  @override
  Future<void> pause() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> dispose() async {}
}
