// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_components/moodiary_components.dart' as components;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

import 'support/nodes.dart';
import 'support/settle.dart';

final _schema = ft.Schema.standard();
final _paragraph = TestNodes(_schema).p;
ft.Node _media(String type, [String name = 'same']) => _schema.node(
  type,
  attrs: {'src': 'https://example.com/$name', 'name': name},
);
String _document(List<ft.Node> nodes) =>
    jsonEncode(_schema.node('doc', attrs: {'v': 2}, content: nodes).toJson());
List<ft.Node> _tail() => [
  for (var index = 0; index < 100; index++) _paragraph('Paragraph $index'),
];

class _Audio implements components.AudioPlaybackController {
  @override
  final progress = ValueNotifier(components.AudioProgress.zero);
  @override
  final activePath = ValueNotifier<String?>(null);
  int prepares = 0, disposals = 0;

  void tick(Duration position, {bool playing = true}) {
    progress.value = components.AudioProgress(
      position: position,
      duration: const Duration(minutes: 1),
      playing: playing,
      muted: false,
    );
  }

  @override
  Future<void> prepare(String path) async {
    prepares++;
    activePath.value = path;
    tick(Duration.zero, playing: false);
  }

  @override
  Future<void> toggle(String path) async =>
      tick(progress.value.position, playing: !progress.value.playing);

  @override
  Future<void> pause() async => tick(progress.value.position, playing: false);

  @override
  Future<void> seek(double fraction, {Duration? fallbackTotal}) async => tick(
    Duration(milliseconds: (60000 * fraction).round()),
    playing: progress.value.playing,
  );

  @override
  void dispose() {
    disposals++;
    activePath.dispose();
    progress.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Video implements VideoPlaybackPort {
  final _snapshots = StreamController<VideoPortSnapshot>.broadcast(sync: true);
  int initializations = 0, disposals = 0, pauses = 0;
  final seeks = <Duration>[];
  @override
  VideoPortSnapshot snapshot = .empty;
  @override
  Stream<VideoPortSnapshot> get snapshots => _snapshots.stream;

  void tick(Duration position, {bool? playing}) {
    snapshot = VideoPortSnapshot(
      isInitialized: true,
      isPlaying: playing ?? snapshot.isPlaying,
      isBuffering: false,
      isCompleted: false,
      position: position,
      duration: const Duration(minutes: 1),
      width: 400,
      height: 225,
      rotationDegrees: 0,
      errorMessage: null,
    );
    _snapshots.add(snapshot);
  }

  @override
  Future<void> initialize() async {
    initializations++;
    tick(Duration.zero, playing: false);
  }

  @override
  Future<void> play() async => tick(snapshot.position, playing: true);
  @override
  Future<void> pause() async {
    pauses++;
    tick(snapshot.position, playing: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    tick(position);
  }

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> dispose() async {
    disposals++;
    await _snapshots.close();
  }
}

class _Harness {
  _Harness(List<ft.Node> nodes, {MoodiaryEditor? configuration}) {
    this.configuration =
        configuration ??
        MoodiaryEditor(initialContent: _document(nodes), readOnly: true);
    host = MoodiaryEditorHost(
      this.configuration,
      audioControllerFactory: () {
        final audio = _Audio();
        audios.add(audio);
        return audio;
      },
      videoPortFactory: (_) {
        final video = _Video();
        videos.add(video);
        return video;
      },
    );
  }

  late final MoodiaryEditor configuration;
  late final MoodiaryEditorHost host;
  final audios = <_Audio>[];
  final videos = <_Video>[];
  bool _disposed = false;

  void disposeHost() {
    if (_disposed) return;
    _disposed = true;
    host.dispose();
  }

  Widget build() => TranslationProvider(
    child: MaterialApp(
      theme: buildMuiTheme(brightness: Brightness.light),
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        GlobalMuiLocalizations.delegate,
      ],
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 360,
            child: ft.TiptapEditor(
              controller: host.editor,
              scrollController: host.scroll,
              readOnly: host.readOnly,
              nodeViews: host.nodeViews,
              nodeHeightEstimator: (node, width) => switch (node.type) {
                'audio' => 76,
                'video' => width * 9 / 16,
                _ => null,
              },
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      disposeHost();
      await tester.pump();
      expect(audios.every((audio) => audio.disposals == 1), true);
      expect(videos.every((video) => video.disposals == 1), true);
    });
    await tester.pumpWidget(build());
    await settleEditor(tester);
  }

  Future<void> away(WidgetTester tester) async {
    host.scroll.jumpTo(host.scroll.position.maxScrollExtent);
    await settleEditor(tester);
  }

  Future<void> back(WidgetTester tester) async {
    host.scroll.jumpTo(0);
    await settleEditor(tester);
  }

  Future<void> play(String type) async {
    if (type == 'audio') {
      await audios.first.toggle('https://example.com/same');
      audios.first.tick(const Duration(seconds: 5));
    } else {
      await host.resumeVideo(
        'https://example.com/same',
        const Duration(seconds: 5),
      );
    }
  }
}

void main() {
  for (final type in ['audio', 'video']) {
    testWidgets('playing $type survives scrolling out and back', (
      tester,
    ) async {
      final harness = _Harness([_media(type), ..._tail()]);
      await harness.mount(tester);
      await harness.play(type);
      await tester.pump();
      await harness.away(tester);
      expect(find.byTooltip(l10n.ui.pause), findsNothing);
      if (type == 'audio') {
        final audio = harness.audios.single;
        expect(audio.disposals, 0);
        expect(audio.progress.value.playing, true);
        audio.tick(const Duration(seconds: 9));
        await harness.back(tester);
        expect(harness.audios, [same(audio)]);
        expect(audio.prepares, 1);
        expect(find.text('0:09 / 1:00'), findsOneWidget);
      } else {
        final video = harness.videos.single;
        expect(video.disposals, 0);
        expect(video.snapshot.isPlaying, true);
        expect(video.pauses, 0);
        video.tick(const Duration(seconds: 9));
        final seeks = video.seeks.length;
        await harness.back(tester);
        expect(harness.videos, [same(video)]);
        expect(video.initializations, 1);
        expect(video.seeks, hasLength(seeks));
        expect(video.snapshot.position, const Duration(seconds: 9));
      }
      expect(find.byTooltip(l10n.ui.pause), findsOneWidget);
    });

    testWidgets('pauseMedia pauses offscreen $type and keeps it', (
      tester,
    ) async {
      final harness = _Harness([_media(type), ..._tail()]);
      await harness.mount(tester);
      await harness.play(type);
      await tester.pump();
      await harness.away(tester);
      await harness.host.pauseMedia();
      await tester.pump();
      if (type == 'audio') {
        final audio = harness.audios.single;
        expect(audio.progress.value.playing, false);
        expect(audio.progress.value.position, const Duration(seconds: 5));
        expect(audio.disposals, 0);
      } else {
        final video = harness.videos.single;
        expect(video.snapshot.isPlaying, false);
        expect(video.pauses, 1);
        expect(video.disposals, 0);
      }
      await harness.back(tester);
      expect(find.byTooltip(l10n.ui.play), findsOneWidget);
    });

    testWidgets('paused $type with progress survives unmount', (tester) async {
      final harness = _Harness([_media(type), ..._tail()]);
      await harness.mount(tester);
      await harness.play(type);
      if (type == 'audio') {
        harness.audios.single.tick(const Duration(seconds: 5), playing: false);
      } else {
        harness.videos.single.tick(const Duration(seconds: 5), playing: false);
      }
      await harness.away(tester);
      await harness.back(tester);
      if (type == 'audio') {
        expect(harness.audios.single.disposals, 0);
        expect(harness.audios.single.prepares, 1);
      } else {
        expect(harness.videos.single.disposals, 0);
        expect(harness.videos.single.initializations, 1);
        expect(
          harness.videos.single.snapshot.position,
          const Duration(seconds: 5),
        );
      }
      expect(find.byTooltip(l10n.ui.play), findsOneWidget);
    });

    testWidgets('idle $type has no offscreen cache', (tester) async {
      final harness = _Harness([
        for (var index = 0; index < 18; index++) ...[
          _media(type, 'idle-$index'),
          ..._tail().take(12),
        ],
      ]);
      await harness.mount(tester);
      final scroll = harness.host.scroll;
      for (
        var offset = 0.0;
        offset < scroll.position.maxScrollExtent;
        offset += 300
      ) {
        scroll.jumpTo(offset);
        await settleEditor(tester);
        final live = type == 'audio'
            ? harness.audios.where((entry) => entry.disposals == 0).length
            : harness.videos.where((entry) => entry.disposals == 0).length;
        expect(live, find.byTooltip(l10n.ui.play).evaluate().length);
      }
      await harness.away(tester);
      if (type == 'audio') {
        expect(harness.audios.length, greaterThan(8));
        expect(harness.audios.first.disposals, 1);
      } else {
        expect(harness.videos.length, greaterThan(8));
        expect(harness.videos.first.disposals, 1);
      }
    });

    testWidgets('deleting $type and undo/redo release each player once', (
      tester,
    ) async {
      final harness = _Harness([_media(type), ..._tail()]);
      await harness.mount(tester);
      await harness.play(type);
      await harness.away(tester);
      harness.host.editor.apply(harness.host.editor.state.tr.replace(0, 1));
      await tester.pump();
      expect(
        type == 'audio'
            ? harness.audios.first.disposals
            : harness.videos.first.disposals,
        1,
      );
      harness.host.editor.exec('undo');
      await harness.back(tester);
      if (type == 'audio') {
        expect(harness.audios, hasLength(2));
        await harness.audios.last.toggle('https://example.com/same');
      } else {
        expect(harness.videos, hasLength(2));
        await harness.host.resumeVideo(
          'https://example.com/same',
          const Duration(seconds: 3),
        );
      }
      harness.host.editor.exec('redo');
      await settleEditor(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(
        type == 'audio'
            ? harness.audios.last.disposals
            : harness.videos.last.disposals,
        1,
      );
    });

    for (final action in ['replace node', 'change source', 'host dispose']) {
      testWidgets('$action releases playing $type', (tester) async {
        final harness = _Harness([_media(type), ..._tail()]);
        await harness.mount(tester);
        await harness.play(type);
        final editor = harness.host.editor;
        switch (action) {
          case 'replace node':
            editor.apply(
              editor.state.tr.replace(
                0,
                1,
                ft.Slice(ft.Fragment([_media(type)]), 0, 0),
              ),
            );
          case 'change source':
            editor.apply(
              editor.state.tr.step(
                const ft.AttrStep(0, 'src', 'https://example.com/changed'),
              ),
            );
          case 'host dispose':
            harness.disposeHost();
        }
        expect(
          type == 'audio'
              ? harness.audios.first.disposals
              : harness.videos.first.disposals,
          1,
        );
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets(
      'mode switches reattach mounted $type without stale controllers',
      (tester) async {
        final harness = _Harness([_media(type), ..._tail()]);
        await harness.mount(tester);
        await harness.play(type);
        for (final readOnly in [false, true]) {
          harness.host.update(MoodiaryEditor(readOnly: readOnly));
          await tester.pumpWidget(harness.build());
          await settleEditor(tester);
        }
        if (type == 'audio') {
          expect(harness.audios, hasLength(3));
          expect(harness.audios.map((entry) => entry.disposals), [1, 1, 0]);
        } else {
          expect(harness.videos, hasLength(3));
          expect(harness.videos.map((entry) => entry.disposals), [1, 1, 0]);
        }
      },
    );

    testWidgets('seeking unplayed $type keeps its paused progress offscreen', (
      tester,
    ) async {
      final harness = _Harness([_media(type), ..._tail()]);
      await harness.mount(tester);
      final label = type == 'audio'
          ? l10n.editor.content.audioProgress
          : l10n.editor.content.videoProgress;
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final position = type == 'audio'
          ? harness.audios.single.progress.value.position
          : harness.videos.single.snapshot.position;
      expect(position, greaterThan(Duration.zero));
      await harness.away(tester);
      await harness.back(tester);
      if (type == 'audio') {
        expect(harness.audios.single.disposals, 0);
        expect(harness.audios.single.prepares, 1);
        expect(harness.audios.single.progress.value.position, position);
        expect(harness.audios.single.progress.value.playing, false);
      } else {
        expect(harness.videos.single.disposals, 0);
        expect(harness.videos.single.initializations, 1);
        expect(harness.videos.single.snapshot.position, position);
        expect(harness.videos.single.snapshot.isPlaying, false);
      }
    });

    testWidgets('late $type resolution after deletion creates no player', (
      tester,
    ) async {
      final source = Completer<({String path, String mime})?>();
      final harness = _Harness(
        [],
        configuration: MoodiaryEditor(
          readOnly: true,
          initialContent: _document([
            _schema.node(type, attrs: {'src': 'audio-delayed'}),
            ..._tail(),
          ]),
          mediaResolver: (_, {poster = false}) async =>
              poster ? null : source.future,
        ),
      );
      await harness.mount(tester);
      harness.host.editor.apply(harness.host.editor.state.tr.replace(0, 1));
      source.complete((path: '/resolved', mime: ''));
      await settleEditor(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(harness.audios, isEmpty);
      expect(harness.videos, isEmpty);
    });

    testWidgets(
      'two $type nodes with the same source stay independent across text edits',
      (tester) async {
        final harness = _Harness([
          _paragraph('top'),
          _media(type),
          _media(type),
          ..._tail(),
        ]);
        await harness.mount(tester);
        if (type == 'audio') {
          expect(harness.audios, hasLength(2));
          await harness.audios.first.toggle('https://example.com/same');
          expect(harness.audios.last.progress.value.playing, false);
        } else {
          expect(harness.videos, hasLength(2));
          await harness.host.resumeVideo(
            'https://example.com/same',
            const Duration(seconds: 7),
          );
          expect(harness.videos.first.snapshot.isPlaying, false);
          expect(
            harness.videos.last.snapshot.position,
            const Duration(seconds: 7),
          );
        }
        final editor = harness.host.editor;
        editor.setSelection(const ft.TextSelection(1));
        editor.exec('insertText', {'text': 'inserted above '});
        await settleEditor(tester);
        expect(
          type == 'audio' ? harness.audios.length : harness.videos.length,
          2,
        );
        expect(harness.audios.every((entry) => entry.disposals == 0), true);
        expect(harness.videos.every((entry) => entry.disposals == 0), true);
        await harness.away(tester);
        await harness.back(tester);
        if (type == 'audio') {
          expect(harness.audios.first.disposals, 0);
          expect(harness.audios.first.prepares, 1);
        } else {
          expect(harness.videos[1].disposals, 0);
          expect(harness.videos[1].initializations, 1);
        }
      },
    );

    for (final action in [
      'swapDocument',
      'replaceDocument',
      'parsed document replacement',
      'mode switch',
    ]) {
      testWidgets('$action releases offscreen $type', (tester) async {
        final harness = _Harness([_media(type), ..._tail()]);
        await harness.mount(tester);
        await harness.play(type);
        await harness.away(tester);
        switch (action) {
          case 'swapDocument':
            await harness.host.swapDocument(
              content: _document([_media(type)]),
              title: 'new',
            );
          case 'replaceDocument':
            harness.host.editor.replaceDocument(
              _schema.node('doc', content: [_media(type)]),
            );
          case 'parsed document replacement':
            harness.host.editor.replaceDocument(
              _schema.parse(_document([_media(type)])),
            );
          case 'mode switch':
            harness.host.update(
              MoodiaryEditor(
                initialContent: harness.configuration.initialContent,
              ),
            );
        }
        await settleEditor(tester);
        expect(
          type == 'audio'
              ? harness.audios.first.disposals
              : harness.videos.first.disposals,
          1,
        );
      });
    }
  }

  testWidgets('a late preview frame does not retain an unplayed video', (
    tester,
  ) async {
    final harness = _Harness([_media('video'), ..._tail()]);
    await harness.mount(tester);
    final video = harness.videos.single;
    video.tick(const Duration(milliseconds: 1), playing: false);
    await harness.away(tester);
    expect(video.disposals, 1);
  });

  testWidgets('fullscreen resumes its own duplicate video while offscreen', (
    tester,
  ) async {
    final returned = Completer<Duration?>();
    final requests = <(String, Duration)>[];
    final harness = _Harness(
      [],
      configuration: MoodiaryEditor(
        readOnly: true,
        initialContent: _document([
          _media('video'),
          _media('video'),
          ..._tail(),
        ]),
        onVideoFullscreen: (name, position) {
          requests.add((name, position));
          return returned.future;
        },
      ),
    );
    await harness.mount(tester);
    final first = harness.videos.first, second = harness.videos.last;
    await tester.tap(find.byTooltip(l10n.ui.play).first);
    first.tick(const Duration(seconds: 5));
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.editor.content.fullscreen).first);
    await tester.pump();
    expect(requests, [
      ('https://example.com/same', const Duration(seconds: 5)),
    ]);
    expect(first.pauses, 1);
    expect(second.pauses, 0);
    await harness.away(tester);
    await harness.host.resumeVideo(
      'https://example.com/same',
      const Duration(seconds: 8),
    );
    expect(first.snapshot.position, const Duration(seconds: 8));
    returned.complete(const Duration(seconds: 11));
    await tester.pump();
    expect(first.snapshot.position, const Duration(seconds: 11));
    expect(first.snapshot.isPlaying, true);
    expect(first.disposals, 0);
    await harness.back(tester);
    expect(first.initializations, 1);
    expect(first.snapshot.position, const Duration(seconds: 11));
  });

  testWidgets(
    'fullscreen return after document swap cannot revive an old video',
    (tester) async {
      final returned = Completer<Duration?>();
      final harness = _Harness(
        [],
        configuration: MoodiaryEditor(
          readOnly: true,
          initialContent: _document([_media('video'), ..._tail()]),
          onVideoFullscreen: (_, _) => returned.future,
        ),
      );
      await harness.mount(tester);
      final video = harness.videos.single;
      await tester.tap(find.byTooltip(l10n.editor.content.fullscreen));
      await tester.pump(const Duration(milliseconds: 400));
      await harness.host.swapDocument(
        content: _document([_paragraph('new')]),
        title: 'new',
      );
      final seeks = video.seeks.length;
      returned.complete(const Duration(seconds: 12));
      await settleEditor(tester);
      expect(video.disposals, 1);
      expect(video.seeks, hasLength(seeks));
    },
  );

  testWidgets('cancelled fullscreen releases an unplayed offscreen video', (
    tester,
  ) async {
    final returned = Completer<Duration?>();
    final harness = _Harness(
      [],
      configuration: MoodiaryEditor(
        readOnly: true,
        initialContent: _document([_media('video'), ..._tail()]),
        onVideoFullscreen: (_, _) => returned.future,
      ),
    );
    await harness.mount(tester);
    final video = harness.videos.single;
    await tester.tap(find.byTooltip(l10n.editor.content.fullscreen));
    await tester.pump(const Duration(milliseconds: 400));
    await harness.away(tester);
    expect(video.disposals, 0);
    returned.complete(null);
    await settleEditor(tester);
    expect(video.disposals, 1);
  });
}
