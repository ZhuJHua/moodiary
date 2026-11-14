import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';

class _Player implements AudioPlayer {
  final calls = <String>[];
  Completer<Duration?>? metadata;
  final metadataStarted = Completer<void>();
  Duration? seekTarget;
  final completed = StreamController<void>.broadcast(sync: true);
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => completed.stream;
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async =>
      calls.add('release:${mode.name}');
  @override
  Future<void> setSource(Source source) async => calls.add('source');
  @override
  Future<Duration?> getDuration() async {
    if (!metadataStarted.isCompleted) metadataStarted.complete();
    return metadata == null ? const Duration(seconds: 2) : metadata!.future;
  }

  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async => calls.add('play');
  @override
  Future<void> seek(Duration position) async => seekTarget = position;
  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await completed.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'metadata preload publishes duration and allows seeking without autoplay',
    () async {
      final player = _Player();
      final audio = AudioPlaybackController.forTesting(player);
      addTearDown(audio.dispose);
      await audio.prepare('/audio.mp3');
      expect(audio.progress.value.duration, const Duration(seconds: 2));
      expect(audio.progress.value.playing, false);
      expect(player.calls, ['release:stop', 'source']);
      await audio.seek(.5);
      expect(player.seekTarget, const Duration(seconds: 1));
      await audio.toggle('/audio.mp3');
      expect(player.calls, ['release:stop', 'source', 'resume']);
      expect(audio.progress.value.playing, true);
    },
  );
  test(
    'prepared audio can seek and resume after completion without reloading',
    () async {
      final player = _Player();
      final audio = AudioPlaybackController.forTesting(player);
      addTearDown(audio.dispose);
      await audio.prepare('/audio.mp3');
      await audio.toggle('/audio.mp3');
      player.completed.add(null);
      expect(audio.progress.value.playing, false);
      await audio.seek(.5);
      expect(audio.progress.value.position, const Duration(seconds: 1));
      await audio.toggle('/audio.mp3');
      expect(player.calls, ['release:stop', 'source', 'resume', 'resume']);
      expect(audio.progress.value.playing, true);
    },
  );
  test(
    'metadata completion after disposal never publishes to a disposed notifier',
    () async {
      final player = _Player()..metadata = Completer<Duration?>();
      final audio = AudioPlaybackController.forTesting(player);
      final ready = audio.prepare('/audio.mp3');
      await player.metadataStarted.future;
      audio.dispose();
      player.metadata!.complete(const Duration(seconds: 2));
      await ready;
    },
  );
  test('an unprepared player reloads for replay after an end seek', () async {
    final player = _Player();
    final audio = AudioPlaybackController.forTesting(player);
    addTearDown(audio.dispose);
    await audio.toggle('/audio.mp3');
    player.completed.add(null);
    await audio.seek(.5, fallbackTotal: const Duration(seconds: 2));
    await audio.toggle('/audio.mp3');
    expect(player.calls, ['play', 'play']);
    expect(audio.progress.value.playing, true);
  });
}
