// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

import 'support/nodes.dart';

final _schema = ft.Schema.standard();
final _image = TestNodes(_schema).image;
String _document(ft.Node node) =>
    jsonEncode(_schema.node('doc', attrs: {'v': 2}, content: [node]).toJson());

Widget _view(MoodiaryEditorHost host, ft.Node? node, {Widget? child}) =>
    TranslationProvider(
      child: MaterialApp(
        theme: buildMuiTheme(brightness: Brightness.light),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        builder: (context, child) =>
            MaterialUiCompatibilityBridge(child: child!),
        home: Scaffold(
          body:
              child ??
              SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: node == null
                      ? const SizedBox.shrink()
                      : Builder(
                          builder: (context) => host.nodeViews[node.type]!(
                            context,
                            ft.TiptapNodeView(
                              node: node,
                              position: 0,
                              selected: false,
                              width: 150,
                              updateAttrs: (_) {},
                            ),
                          ),
                        ),
                ),
              ),
        ),
      ),
    );

Future<ui.Image> _portrait(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      final picture = recorder.endRecording();
      final image = await picture.toImage(20, 60);
      picture.dispose();
      return image;
    }))!;

void _seed(ImageProvider provider, ui.Image image) {
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image.clone())),
    ),
  );
}

FastImageProbe _header({int width = 20, int height = 60}) => FastImageProbe(
  format: FastImageFormat.jpeg,
  width: width,
  height: height,
  progressive: false,
  regionDecodable: false,
);

void main() {
  testWidgets('large documents load without waiting for image headers', (
    tester,
  ) async {
    final pending = Completer<FastImageProbe>();
    final node = _image('image-large.jpg');
    final content = jsonEncode(
      _schema
          .node(
            'doc',
            attrs: {'v': 2},
            content: [
              node,
              _schema.node(
                'paragraph',
                content: [_schema.node('text', text: 'Text ' * 14000)],
              ),
            ],
          )
          .toJson(),
    );
    var probes = 0;
    late MoodiaryEditorHost host;
    await tester.runAsync(() async {
      host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: content,
          mediaResolver: (name, {poster = false}) async =>
              (path: '/large.jpg', mime: 'image/jpeg'),
        ),
        imageProbe: ({required filePath}) {
          probes++;
          return pending.future;
        },
      );
      await host.documentLoaded;
    });
    addTearDown(host.dispose);
    expect(host.readOnly, isFalse);
    expect(host.editor.state.doc.content.first.type, 'image');
    expect(probes, 1);
    expect(pending.isCompleted, isFalse);
    expect(host.estimateNodeHeight(node, 150), 100);
    pending.complete(_header());
    await tester.pump();
    expect(host.estimateNodeHeight(node, 150), 450);
  });

  testWidgets('headers size the estimator and image before decode', (
    tester,
  ) async {
    final pending = Completer<FastImageProbe>();
    final node = _image('image-header.jpg');
    var resolutions = 0;
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _document(node),
        readOnly: true,
        mediaResolver: (name, {poster = false}) async {
          if (poster) return null;
          resolutions++;
          return (path: '/header.jpg', mime: 'image/jpeg');
        },
      ),
      imageProbe: ({required filePath}) => pending.future,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      host.dispose();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    expect(host.editor.state.doc.child(0).type, 'image');
    expect(host.estimateNodeHeight(node, 150), 100);
    pending.complete(_header(height: 80));
    await tester.pump();
    expect(host.estimateNodeHeight(node, 150), 600);
    await tester.pumpWidget(_view(host, node));
    expect(tester.getSize(find.byType(Image)).height, 600);
    expect(resolutions, 1);
    final portrait = await _portrait(tester);
    addTearDown(portrait.dispose);
    await tester.pumpWidget(_view(host, null));
    PaintingBinding.instance.imageCache.evict(
      const FastImage('/header.jpg', tier: FastImageTier.m),
    );
    _seed(const FastImage('/header.jpg', tier: FastImageTier.m), portrait);
    await tester.pumpWidget(_view(host, node));
    await tester.pump();
    expect(host.estimateNodeHeight(node, 150), 600);
    expect(tester.getSize(find.byType(Image)).height, 600);
  });

  testWidgets(
    'header arrival relayouts estimated media without moving content',
    (tester) async {
      final pending = Completer<FastImageProbe>();
      final node = _image('image-header.jpg');
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: jsonEncode(
            _schema
                .node(
                  'doc',
                  attrs: {'v': 2},
                  content: [
                    node,
                    for (var index = 0; index < 60; index++)
                      _schema.node(
                        'paragraph',
                        content: [_schema.node('text', text: 'Tail $index')],
                      ),
                  ],
                )
                .toJson(),
          ),
          readOnly: true,
          mediaResolver: (name, {poster = false}) async =>
              poster ? null : (path: '/header.jpg', mime: 'image/jpeg'),
        ),
        imageProbe: ({required filePath}) => pending.future,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        host.dispose();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: host,
          builder: (_, _) => _view(
            host,
            null,
            child: SizedBox(
              width: 150,
              height: 360,
              child: ft.TiptapEditor(
                key: host.editorKey,
                controller: host.editor,
                scrollController: host.scroll,
                readOnly: true,
                nodeViews: host.nodeViews,
                nodeHeightEstimator: host.estimateNodeHeight,
                style: const ft.TiptapEditorStyle(
                  cacheExtent: 0,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      host.scroll.jumpTo(50);
      await tester.pumpAndSettle();
      final geometry = host.editorKey.currentState!.geometry!;
      final before = geometry.rowRect(1).top;
      pending.complete(_header());
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byType(Image)).height, 450);
      expect(geometry.rowRect(1).top, closeTo(before, .01));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (together, depth) in [
    (false, 0),
    (true, 0),
    (false, 2),
    (true, 2),
  ]) {
    testWidgets(
      'offscreen image headers preserve measured paragraphs and scroll anchor ${together ? 'in one frame' : 'across frames'} at table depth $depth',
      (tester) async {
        final probes = <String, Completer<FastImageProbe>>{};
        ft.Node imageRow(String name) {
          var node = _image(name);
          for (var level = 0; level < depth; level++) {
            node = _schema.node(
              'table',
              content: [
                _schema.node(
                  'tableRow',
                  content: [
                    _schema.node('tableCell', content: [node]),
                  ],
                ),
              ],
            );
          }
          return node;
        }

        final host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: _schema
                .node(
                  'doc',
                  attrs: {'v': 2},
                  content: [
                    imageRow('image-above.jpg'),
                    for (var index = 0; index < 240; index++)
                      _schema.node(
                        'paragraph',
                        content: [_schema.node('text', text: 'Short $index')],
                      ),
                    imageRow('image-below.jpg'),
                    for (var index = 0; index < 30; index++)
                      _schema.node(
                        'paragraph',
                        content: [_schema.node('text', text: 'Tail $index')],
                      ),
                  ],
                )
                .toJsonString(),
            readOnly: true,
            mediaResolver: (name, {poster = false}) async =>
                (path: name, mime: 'image/jpeg'),
          ),
          imageProbe: ({required filePath}) =>
              (probes[filePath] = Completer<FastImageProbe>()).future,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          host.dispose();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });
        await tester.pumpWidget(
          _view(
            host,
            null,
            child: SizedBox(
              width: 150,
              height: 360,
              child: ft.TiptapEditor(
                key: host.editorKey,
                controller: host.editor,
                scrollController: host.scroll,
                readOnly: true,
                nodeViews: host.nodeViews,
                nodeHeightEstimator: host.estimateNodeHeight,
                style: const ft.TiptapEditorStyle(
                  cacheExtent: 0,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var step = 0; step < 24; step++) {
          host.scroll.jumpTo(host.scroll.offset + 150);
          await tester.pumpAndSettle();
        }
        expect(
          probes.keys,
          containsAll(['image-above.jpg', 'image-below.jpg']),
        );
        final geometry = host.editorKey.currentState!.geometry!;
        final position = geometry.positionForOffset(const Offset(10, 1));
        final before = geometry.rowRect(position).top;
        final scrollBefore = host.scroll.offset;
        final scans = host.editor.diagnostics.fullDocumentScans;
        expect(before, lessThanOrEqualTo(1));
        expect(
          geometry.rowRect(host.editor.state.doc.content.size - 1).top,
          greaterThan(360),
        );
        probes['image-above.jpg']!.complete(_header());
        double? afterAbove;
        if (!together) {
          await tester.pumpAndSettle();
          expect(geometry.rowRect(position).top, closeTo(before, .01));
          expect(host.scroll.offset, greaterThan(scrollBefore));
          afterAbove = host.scroll.offset;
        }
        probes['image-below.jpg']!.complete(_header());
        await tester.pumpAndSettle();
        expect(geometry.rowRect(position).top, closeTo(before, .01));
        expect(host.scroll.offset, greaterThan(scrollBefore));
        if (depth == 0) {
          expect(host.scroll.offset, closeTo(scrollBefore + 350, .01));
        }
        if (afterAbove != null) {
          expect(host.scroll.offset, closeTo(afterAbove, .01));
        }
        expect(host.editor.diagnostics.fullDocumentScans, scans);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'header results from a swapped or disposed document are ignored',
    (tester) async {
      final probes = <Completer<FastImageProbe>>[];
      final node = _image('image-header.jpg');
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: _document(node),
          mediaResolver: (name, {poster = false}) async =>
              poster ? null : (path: '/header.jpg', mime: 'image/jpeg'),
        ),
        imageProbe: ({required filePath}) {
          final pending = Completer<FastImageProbe>();
          probes.add(pending);
          return pending.future;
        },
      );
      await tester.pump();
      expect(probes, hasLength(1));
      await host.swapDocument(content: _document(node), title: 'Next diary');
      await tester.pump();
      expect(probes, hasLength(2));
      probes.first.complete(_header(height: 80));
      await tester.pump();
      expect(host.estimateNodeHeight(node, 150), 100);
      probes[1].complete(_header());
      await tester.pump();
      expect(host.estimateNodeHeight(node, 150), 450);
      await host.swapDocument(content: _document(node), title: 'Last diary');
      await tester.pump();
      expect(probes, hasLength(3));
      host.dispose();
      probes.last.complete(_header());
      await tester.pump();
      expect(host.estimateNodeHeight(node, 150), 100);
      expect(tester.takeException(), isNull);
    },
  );

  for (final invalid in [false, true]) {
    testWidgets(
      '${invalid ? 'invalid' : 'failed'} headers fall back to decoded frames',
      (tester) async {
        final portrait = await _portrait(tester);
        addTearDown(portrait.dispose);
        _seed(
          const FastImage('/fallback.jpg', tier: FastImageTier.m),
          portrait,
        );
        final node = _image('image-fallback.jpg');
        final host = MoodiaryEditorHost(
          MoodiaryEditor(
            initialContent: _document(node),
            mediaResolver: (name, {poster = false}) async =>
                poster ? null : (path: '/fallback.jpg', mime: 'image/jpeg'),
          ),
          imageProbe: ({required filePath}) async {
            if (invalid) return _header(height: 0);
            throw const FormatException('Invalid image header');
          },
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          host.dispose();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        });
        await tester.pump();
        expect(host.estimateNodeHeight(node, 150), 100);
        await tester.pumpWidget(_view(host, node));
        await tester.pump();
        expect(host.estimateNodeHeight(node, 150), 450);
        expect(tester.getSize(find.byType(Image)).height, 450);
      },
    );
  }

  testWidgets(
    'local header probing deduplicates names and limits concurrency',
    (tester) async {
      final nodes = [
        for (var index = 0; index < 9; index++) _image('image-$index.jpg'),
      ];
      final resolutions = <String>[];
      final pending = <Completer<FastImageProbe>>[];
      var active = 0, maximum = 0;
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: jsonEncode(
            _schema
                .node(
                  'doc',
                  attrs: {'v': 2},
                  content: [
                    ...nodes,
                    nodes.first,
                    _image('https://example.com/image.jpg'),
                    _image('data:image/png;base64,AA=='),
                    _schema.node(
                      'table',
                      content: [
                        _schema.node(
                          'tableRow',
                          content: [
                            _schema.node(
                              'tableCell',
                              content: [_image('image-nested.jpg')],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
                .toJson(),
          ),
          mediaResolver: (name, {poster = false}) async {
            resolutions.add(name);
            return (path: '/$name', mime: 'image/jpeg');
          },
        ),
        imageProbe: ({required filePath}) {
          active++;
          if (active > maximum) maximum = active;
          final probe = Completer<FastImageProbe>();
          pending.add(probe);
          return probe.future.whenComplete(() => active--);
        },
      );
      addTearDown(host.dispose);
      await tester.pump();
      expect(pending, hasLength(4));
      expect(resolutions, hasLength(4));
      for (var index = 0; index < 10; index++) {
        expect(pending.length, greaterThan(index));
        pending[index].complete(_header());
        await tester.pump();
      }
      expect(maximum, 4);
      expect(active, 0);
      expect(resolutions, hasLength(10));
      expect(resolutions.toSet(), hasLength(10));
      expect(host.estimateNodeHeight(_image('image-nested.jpg'), 150), 450);
    },
  );

  testWidgets('image probe concurrency stays bounded across document swaps', (
    tester,
  ) async {
    final pending = <Completer<FastImageProbe>>[];
    var active = 0, maximum = 0;
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: jsonEncode(
          _schema
              .node(
                'doc',
                attrs: {'v': 2},
                content: [
                  for (var index = 0; index < 8; index++)
                    _image('image-old-$index.jpg'),
                ],
              )
              .toJson(),
        ),
        mediaResolver: (name, {poster = false}) async =>
            (path: '/$name', mime: 'image/jpeg'),
      ),
      imageProbe: ({required filePath}) {
        active++;
        if (active > maximum) maximum = active;
        final probe = Completer<FastImageProbe>();
        pending.add(probe);
        return probe.future.whenComplete(() => active--);
      },
    );
    addTearDown(host.dispose);
    await tester.pump();
    expect(pending, hasLength(4));
    final next = _image('image-next.jpg');
    await host.swapDocument(content: _document(next), title: 'Next diary');
    await tester.pump();
    expect(pending, hasLength(4));
    pending.first.complete(_header());
    await tester.pump();
    expect(pending, hasLength(5));
    for (final probe in pending.skip(1)) {
      probe.complete(_header());
    }
    await tester.pump();
    expect(maximum, 4);
    expect(active, 0);
    expect(pending, hasLength(5));
    expect(host.estimateNodeHeight(_image('image-old-0.jpg'), 150), 100);
    expect(host.estimateNodeHeight(next, 150), 450);
  });

  test('media cache bounds and refreshes its least recently used entries', () {
    final cache = LRUCache<int, int>(maxSize: 512);
    for (var index = 0; index < 512; index++) {
      cache.put(index, index);
    }
    expect(cache.get(0), 0);
    cache.put(512, 512);
    expect(cache.get(1), isNull);
    expect(cache.get(0), 0);
    cache.put(0, 1000);
    cache.put(513, 513);
    expect(cache.get(2), isNull);
    expect(cache.get(0), 1000);
    cache.clear();
    expect(cache.get(0), isNull);
    expect(cache.get(513), isNull);
  });

  for (final kind in ['file', 'network', 'data']) {
    testWidgets('$kind image remount has final geometry on its first frame', (
      tester,
    ) async {
      final portrait = await _portrait(tester);
      addTearDown(portrait.dispose);
      final png = (await tester.runAsync(
        () => portrait.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      final directory = Directory.systemTemp.createTempSync('image-layout-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/portrait.png')
        ..writeAsBytesSync(png.buffer.asUint8List());
      final name = switch (kind) {
        'network' => 'https://example.com/portrait.png',
        'data' =>
          'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}',
        _ => 'image-portrait.png',
      };
      final node = _image(name);
      final calls = <bool>[];
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: _document(node),
          readOnly: true,
          mediaResolver: (name, {poster = false}) async {
            calls.add(poster);
            return (path: file.path, mime: 'image/png');
          },
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        host.dispose();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      if (kind == 'file') {
        _seed(FastImage(file.path, tier: FastImageTier.m), portrait);
      }
      if (kind == 'network') _seed(NetworkImage(name), portrait);
      expect(host.estimateNodeHeight(node, 150), 100);
      await tester.pumpWidget(_view(host, node));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(host.estimateNodeHeight(node, 150), 450);
      expect(tester.getSize(find.byType(Image)).height, 450);
      await tester.pumpWidget(_view(host, null));
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.pumpWidget(_view(host, node));
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(Image)).height, 450);
      if (kind == 'file') {
        expect(calls.where((poster) => !poster).length, 1);
        expect(calls.where((poster) => poster).length, 1);
      }
      await tester.pumpWidget(_view(host, null));
      await host.swapDocument(content: _document(node), title: 'Next diary');
      expect(host.estimateNodeHeight(node, 150), 100);
      if (kind == 'file') {
        PaintingBinding.instance.imageCache.evict(
          FastImage(file.path, tier: FastImageTier.m),
        );
        _seed(FastImage(file.path, tier: FastImageTier.m), portrait);
      }
      if (kind == 'network') _seed(NetworkImage(name), portrait);
      await tester.pumpWidget(_view(host, node));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      if (kind == 'file') {
        expect(calls.where((poster) => !poster).length, 2);
        expect(calls.where((poster) => poster).length, 2);
      }
      expect(host.estimateNodeHeight(node, 150), 450);
    });
  }

  testWidgets('scrolling back restores image geometry with widthPercent', (
    tester,
  ) async {
    final portrait = await _portrait(tester);
    addTearDown(portrait.dispose);
    const name = 'https://example.com/portrait.png';
    _seed(const NetworkImage(name), portrait);
    final node = _schema.node(
      'image',
      attrs: {'src': name, 'widthPercent': 25},
    );
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: jsonEncode(
          _schema
              .node(
                'doc',
                attrs: {'v': 2},
                content: [
                  node,
                  for (var index = 0; index < 100; index++)
                    _schema.node(
                      'paragraph',
                      content: [_schema.node('text', text: 'Tail $index')],
                    ),
                ],
              )
              .toJson(),
        ),
        readOnly: true,
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      host.dispose();
      expect(host.estimateNodeHeight(node, 150), 100);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    final key = GlobalKey<ft.TiptapEditorState>();
    await tester.pumpWidget(
      _view(
        host,
        null,
        child: SizedBox(
          width: 150,
          height: 360,
          child: ft.TiptapEditor(
            key: key,
            controller: host.editor,
            scrollController: host.scroll,
            readOnly: true,
            nodeViews: host.nodeViews,
            nodeHeightEstimator: host.estimateNodeHeight,
            style: const ft.TiptapEditorStyle(
              cacheExtent: 0,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Image)), const Size(37.5, 112.5));
    host.scroll.jumpTo(host.scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    host.scroll.jumpTo(0);
    await tester.pump();
    expect(tester.getSize(find.byType(Image)), const Size(37.5, 112.5));
    expect(key.currentState!.geometry!.rowRect(0).height, 112.5);
  });

  testWidgets('host caches evict old media sources and image ratios', (
    tester,
  ) async {
    final portrait = await _portrait(tester);
    addTearDown(portrait.dispose);
    _seed(const FastImage('/portrait.png', tier: FastImageTier.m), portrait);
    final calls = <String>[];
    final host = MoodiaryEditorHost(
      MoodiaryEditor(
        initialContent: _document(_image('image-0.png')),
        mediaResolver: (name, {poster = false}) async {
          if (poster) return null;
          calls.add(name);
          return (path: '/portrait.png', mime: 'image/png');
        },
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      host.dispose();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    for (var index = 0; index < 513; index++) {
      await tester.pumpWidget(_view(host, _image('image-$index.png')));
      await tester.pump();
    }
    expect(host.estimateNodeHeight(_image('image-0.png'), 150), 100);
    expect(host.estimateNodeHeight(_image('image-512.png'), 150), 450);
    await tester.pumpWidget(_view(host, _image('image-512.png')));
    await tester.pump();
    expect(calls.where((name) => name == 'image-512.png').length, 1);
    await tester.pumpWidget(_view(host, _image('image-0.png')));
    await tester.pump();
    expect(calls.where((name) => name == 'image-0.png').length, 2);
  });

  testWidgets(
    'a source finishing after document swap does not refill the cache',
    (tester) async {
      final pending = Completer<({String path, String mime})?>();
      var calls = 0;
      final node = _schema.node('attachment', attrs: {'src': 'file-test.pdf'});
      final host = MoodiaryEditorHost(
        MoodiaryEditor(
          initialContent: _document(node),
          mediaResolver: (name, {poster = false}) {
            if (poster) return Future.value();
            calls++;
            return pending.future;
          },
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        host.dispose();
      });
      await tester.pumpWidget(_view(host, node));
      await tester.pumpWidget(_view(host, null));
      await host.swapDocument(content: _document(node), title: 'Next diary');
      pending.complete((path: '/file.pdf', mime: 'application/pdf'));
      await tester.pump();
      await tester.pumpWidget(_view(host, node));
      expect(calls, 2);
    },
  );
}
