import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:moodiary_components/moodiary_components.dart';

class _FakePlayer implements AudioPlayer {
  final calls = <String>[];
  final seeks = <Duration>[];
  final states = StreamController<PlayerState>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration?>.broadcast();
  final errors = StreamController<PlayerException>.broadcast();

  Completer<Duration?>? pendingLoad;
  Completer<void>? pendingSeek;
  Object? loadError;
  Object? playError;

  bool _playing = false;
  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(seconds: 2);

  @override
  bool get playing => _playing;
  @override
  ProcessingState get processingState => _processingState;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  Stream<PlayerException> get errorStream => errors.stream;

  void emitState({bool? playing, ProcessingState? processingState}) {
    _playing = playing ?? _playing;
    _processingState = processingState ?? _processingState;
    if (!states.isClosed) states.add(PlayerState(_playing, _processingState));
  }

  Future<Duration?> _load(String label) async {
    calls.add(label);
    if (loadError != null) throw loadError!;
    final result = pendingLoad == null ? _duration : await pendingLoad!.future;
    _processingState = ProcessingState.ready;
    if (!durations.isClosed) durations.add(result);
    emitState(processingState: ProcessingState.ready);
    return result;
  }

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) => _load('file:$filePath');

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) => _load('url:$url');

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
    if (playError != null) throw playError!;
    emitState(playing: true, processingState: ProcessingState.ready);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emitState(playing: false);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    emitState(playing: false, processingState: ProcessingState.idle);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    final target = position ?? Duration.zero;
    seeks.add(target);
    _position = target;
    if (!positions.isClosed) positions.add(_position);
    if (pendingSeek != null) await pendingSeek!.future;
    if (target < _duration && _processingState == ProcessingState.completed) {
      emitState(processingState: ProcessingState.ready);
    }
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await states.close();
    await positions.close();
    await durations.close();
    await errors.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  tearDown(AudioPlaybackController.resetActiveForTest);

  test(
    'prepare preloads duration and allows seeking without autoplay',
    () async {
      final player = _FakePlayer();
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.prepare();
      await _pump();
      expect(audio.progress.value.duration, const Duration(seconds: 2));
      expect(audio.progress.value.playing, false);
      expect(player.calls, ['file:/audio.mp3']);

      await audio.seek(.5);
      expect(player.seeks, [const Duration(seconds: 1)]);

      await audio.toggle();
      await _pump();
      expect(player.calls, ['file:/audio.mp3', 'play']);
      expect(audio.progress.value.playing, true);
    },
  );

  test(
    'natural completion rewinds to zero and subsequent seek/replay works',
    () async {
      final player = _FakePlayer();
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.prepare();
      await audio.toggle();
      await _pump();

      player.emitState(
        playing: true,
        processingState: ProcessingState.completed,
      );
      await _pump();
      expect(audio.progress.value.playing, false);
      expect(audio.progress.value.position, Duration.zero);
      expect(player.calls, ['file:/audio.mp3', 'play', 'pause']);
      expect(player.seeks, [Duration.zero]);

      await audio.seek(.5);
      await audio.toggle();
      await _pump();
      expect(audio.progress.value.position, const Duration(seconds: 1));
      expect(audio.progress.value.playing, true);
    },
  );

  test(
    'paused scrub to 100% stays at end and next toggle rewinds and plays',
    () async {
      final player = _FakePlayer()..pendingSeek = Completer<void>();
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.prepare();
      // Simulates Android just_audio where seeking to 100% emits completed
      // without resolving the seek future.
      unawaited(audio.seek(1.0));
      await _pump();
      player.emitState(
        playing: false,
        processingState: ProcessingState.completed,
      );
      await _pump();
      expect(audio.progress.value.position, const Duration(seconds: 2));
      expect(audio.progress.value.playing, false);

      // Next toggle is not stranded: it rewinds to zero and plays.
      player.pendingSeek = null;
      await audio.toggle();
      await _pump();
      expect(player.seeks, [const Duration(seconds: 2), Duration.zero]);
      expect(audio.progress.value.playing, true);
    },
  );

  test(
    'external pause and automatic resume sync UI and toggle pauses',
    () async {
      final player = _FakePlayer();
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.toggle();
      await _pump();
      expect(audio.progress.value.playing, true);

      player.emitState(playing: false, processingState: ProcessingState.ready);
      await _pump();
      expect(audio.progress.value.playing, false);

      player.emitState(playing: true, processingState: ProcessingState.ready);
      await _pump();
      expect(audio.progress.value.playing, true);

      await audio.toggle();
      await _pump();
      expect(audio.progress.value.playing, false);
      expect(player.calls.last, 'pause');
    },
  );

  test('starting a second audio pauses the previously active one', () async {
    final playerA = _FakePlayer();
    final playerB = _FakePlayer();
    final a = AudioPlaybackController.forTesting('/a.mp3', playerA);
    final b = AudioPlaybackController.forTesting('/b.mp3', playerB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await a.toggle();
    await _pump();
    expect(a.progress.value.playing, true);

    await b.toggle();
    await _pump();
    expect(a.progress.value.playing, false);
    expect(b.progress.value.playing, true);
    expect(playerA.calls, ['file:/a.mp3', 'play', 'pause']);
    expect(playerB.calls, ['file:/b.mp3', 'play']);
  });

  test('pause during pending load cancels start cleanly', () async {
    final player = _FakePlayer()..pendingLoad = Completer<Duration?>();
    final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
    addTearDown(audio.dispose);

    final start = audio.toggle();
    await _pump();
    await audio.pause();
    player.pendingLoad!.complete(const Duration(seconds: 2));
    await start;
    await _pump();

    expect(audio.progress.value.playing, false);
    expect(player.calls, ['file:/audio.mp3']);
  });

  test('network URL uses setUrl and failure allows clean retry', () async {
    final player = _FakePlayer()..loadError = StateError('offline');
    final audio = AudioPlaybackController.forTesting(
      'https://example.com/clip.m4a',
      player,
    );
    addTearDown(audio.dispose);

    await expectLater(audio.prepare(), throwsStateError);
    player.loadError = null;

    await audio.toggle();
    await _pump();
    expect(player.calls, [
      'url:https://example.com/clip.m4a',
      'url:https://example.com/clip.m4a',
      'play',
    ]);
    expect(audio.progress.value.playing, true);
  });

  test('errorStream stops playback and invalidates cached load', () async {
    final player = _FakePlayer();
    final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
    addTearDown(audio.dispose);

    await audio.toggle();
    await _pump();
    expect(audio.progress.value.playing, true);

    player.errors.add(PlayerException(1, 'stream dropped', 0));
    await _pump();
    expect(audio.progress.value.playing, false);

    // Retrying reloads from scratch instead of assuming prior load is valid.
    await audio.toggle();
    await _pump();
    expect(player.calls, [
      'file:/audio.mp3',
      'play',
      'pause',
      'file:/audio.mp3',
      'play',
    ]);
  });

  test('disposal during preload never writes to disposed notifier', () async {
    final player = _FakePlayer()..pendingLoad = Completer<Duration?>();
    final audio = AudioPlaybackController.forTesting('/audio.mp3', player);

    final ready = audio.prepare();
    await _pump();
    audio.dispose();
    player.pendingLoad!.complete(const Duration(seconds: 2));
    await ready;
  });

  test(
    'play activation error resets player state so retry works cleanly',
    () async {
      final player = _FakePlayer()..playError = StateError('session busy');
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.toggle();
      await _pump();
      expect(audio.progress.value.playing, false);
      expect(player.playing, false);
      expect(player.calls, ['file:/audio.mp3', 'play', 'pause']);

      player.playError = null;
      await audio.toggle();
      await _pump();
      expect(audio.progress.value.playing, true);
      expect(player.calls.last, 'play');
    },
  );

  test('explicit pause on an already-interrupted clip calls stop to clear resume intent', () async {
    final player = _FakePlayer();
    final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
    addTearDown(audio.dispose);

    await audio.toggle();
    await _pump();
    player.emitState(playing: false, processingState: ProcessingState.ready);
    await _pump();

    await audio.pause();
    expect(player.calls, ['file:/audio.mp3', 'play', 'stop']);
  });

  test('disposing active player releases audio session, but handoff or idle disposal does not', () async {
    var releases = 0;
    final a = AudioPlaybackController.forTesting(
      '/a.mp3',
      _FakePlayer(),
      releaseSession: () async => releases++,
    );
    final b = AudioPlaybackController.forTesting(
      '/b.mp3',
      _FakePlayer(),
      releaseSession: () async => releases++,
    );
    final idle = AudioPlaybackController.forTesting(
      '/idle.mp3',
      _FakePlayer(),
      releaseSession: () async => releases++,
    );

    await a.toggle();
    await _pump();
    idle.dispose();
    expect(releases, 0);

    await b.toggle();
    await _pump();
    a.dispose();
    expect(releases, 0);

    b.dispose();
    await _pump();
    expect(releases, 1);
  });

  test(
    'terminal position event during completion does not cancel rewind',
    () async {
      final player = _FakePlayer();
      final audio = AudioPlaybackController.forTesting('/audio.mp3', player);
      addTearDown(audio.dispose);

      await audio.toggle();
      await _pump();
      player.emitState(
        playing: true,
        processingState: ProcessingState.completed,
      );
      player.positions.add(const Duration(seconds: 2));
      await _pump();

      expect(audio.progress.value.playing, false);
      expect(audio.progress.value.position, Duration.zero);
      expect(player.seeks, [Duration.zero]);
    },
  );
}
