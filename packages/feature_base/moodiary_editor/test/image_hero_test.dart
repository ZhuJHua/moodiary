// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui' as ui;

import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

Future<ui.Image> _seedImage(WidgetTester tester, String path) async {
  final image = (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xffff1234), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(240, 160);
    picture.dispose();
    return image;
  }))!;
  PaintingBinding.instance.imageCache.putIfAbsent(
    FastImage(path, tier: FastImageTier.m),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image.clone())),
    ),
  );
  return image;
}

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, .5));
  expect(actual.top, closeTo(expected.top, .5));
  expect(actual.right, closeTo(expected.right, .5));
  expect(actual.bottom, closeTo(expected.bottom, .5));
}

void _expectFlight(WidgetTester tester, Rect card, ui.Image image) {
  final flight = find.byType(RawImage);
  expect(flight, findsOneWidget);
  _expectRect(tester.getRect(flight), card);
  expect(tester.widget<RawImage>(flight).image!.isCloneOf(image), isTrue);
  expect(tester.widget<RawImage>(flight).filterQuality, FilterQuality.medium);
  final clip = tester.widget<ClipRRect>(
    find.ancestor(of: flight, matching: find.byType(ClipRRect)).first,
  );
  final radius = clip.borderRadius.resolve(TextDirection.ltr);
  for (final corner in [
    radius.topLeft,
    radius.topRight,
    radius.bottomLeft,
    radius.bottomRight,
  ]) {
    expect(corner.x, closeTo(12, .5));
    expect(corner.y, closeTo(12, .5));
  }
}

void main() {
  for (final readOnly in [true, false]) {
    for (final percent in [100, 45]) {
      testWidgets(
        'image flight matches painted card at width $percent readOnly=$readOnly',
        (tester) async {
          tester.view.physicalSize = const Size(400, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const path = '/image-flight.png';
          final image = await _seedImage(tester, path);
          final schema = ft.Schema.standard();
          ft.Node paragraph(String text) => schema.node(
            'paragraph',
            content: [schema.node('text', text: text)],
          );
          final probe = Completer<FastTileSource?>();
          var laterOpen = false;
          late BuildContext editorContext;
          final host = MoodiaryEditorHost(
            MoodiaryEditor(
              initialContent: schema
                  .node(
                    'doc',
                    attrs: {'v': 2},
                    content: [
                      paragraph('Lead'),
                      schema.node(
                        'image',
                        attrs: {
                          'src': 'image-flight.png',
                          'widthPercent': percent,
                        },
                      ),
                      for (var index = 0; index < 40; index++)
                        paragraph('Tail $index'),
                    ],
                  )
                  .toJsonString(),
              readOnly: readOnly,
              mediaResolver: (_, {poster = false}) =>
                  poster ? null : (path: path, mime: 'image/png'),
              onImageTap: (images, index, tags) {
                MImageBrowser.show(
                  editorContext,
                  images: [for (final _ in images) path],
                  initialIndex: index,
                  heroTags: tags,
                  regionResolver: (_) => laterOpen
                      ? SynchronousFuture(
                          const FastTileSource(
                            size: Size(240, 160),
                            decodePath: path,
                          ),
                        )
                      : probe.future,
                );
              },
            ),
            imageProbe: ({required filePath}) => SynchronousFuture(
              const FastImageProbe(
                format: FastImageFormat.png,
                width: 240,
                height: 160,
                progressive: false,
                regionDecodable: true,
              ),
            ),
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            host.dispose();
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            image.dispose();
          });
          await tester.pumpWidget(
            TranslationProvider(
              child: MaterialApp(
                theme: buildMuiTheme(brightness: Brightness.light),
                localizationsDelegates: const [
                  ...GlobalMaterialLocalizations.delegates,
                  GlobalMuiLocalizations.delegate,
                ],
                builder: (_, child) =>
                    MaterialUiCompatibilityBridge(child: child!),
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      editorContext = context;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(13, 43, 27, 50),
                        child: ft.TiptapEditor(
                          key: host.editorKey,
                          controller: host.editor,
                          scrollController: host.scroll,
                          readOnly: readOnly,
                          nodeViews: host.nodeViews,
                          nodeHeightEstimator: host.estimateNodeHeight,
                          style: const ft.TiptapEditorStyle(
                            centerMedia: true,
                            padding: EdgeInsets.fromLTRB(10, 30, 18, 40),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          host.scroll.jumpTo(18);
          await tester.pumpAndSettle();
          final position = host.editor.state.doc
              .rows()
              .firstWhere((row) => row.node.type == 'image')
              .position;
          final tag = (host, position);
          final source = find.byWidgetPredicate(
            (widget) => widget is Hero && widget.tag == tag,
          );
          final geometry = host.editorKey.currentState!.geometry!;
          final card = geometry
              .rowRect(position)
              .shift(tester.getTopLeft(find.byType(ft.TiptapEditor)));
          _expectRect(tester.getRect(source), card);
          expect(card.width, closeTo((360 - 28) * percent / 100, .01));
          expect(host.scroll.offset, 18);
          expect(find.byType(RawImage), findsOneWidget);

          for (final resolved in [false, true]) {
            laterOpen = resolved;
            if (readOnly) {
              await tester.tapAt(card.center);
              await tester.pump(const Duration(milliseconds: 300));
            } else {
              await tester.tapAt(card.center);
              await tester.pump(const Duration(milliseconds: 50));
              await tester.tapAt(card.center);
            }
            await tester.pump();
            if (find.byType(MImageBrowser).evaluate().isEmpty) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            await tester.pump(const Duration(milliseconds: 80));
            await tester.pump();
            expect(find.byType(MImageBrowser), findsOneWidget);
            _expectFlight(tester, card, image);
            expect(
              find.descendant(of: source.first, matching: find.byType(Image)),
              findsNothing,
            );
            final galleryHero = tester.widget<Hero>(
              find.descendant(
                of: find.byType(MImageBrowser),
                matching: find.byType(Hero),
              ),
            );
            expect(galleryHero.child, isNot(isA<FastTileImageViewer>()));
            await tester.pump(const Duration(milliseconds: 100));
            final midFlight = find.byType(RawImage);
            final midClip = tester.widget<ClipRRect>(
              find
                  .ancestor(of: midFlight, matching: find.byType(ClipRRect))
                  .first,
            );
            final midRadius = midClip.borderRadius.resolve(TextDirection.ltr);
            expect(midRadius.topLeft.x, greaterThan(0));
            expect(midRadius.topLeft.x, lessThan(12));
            if (!resolved) {
              final midRect = tester.getRect(midFlight);
              probe.complete(
                const FastTileSource(size: Size(240, 160), decodePath: path),
              );
              await tester.pump();
              _expectRect(tester.getRect(find.byType(RawImage)), midRect);
              expect(
                tester
                    .widget<RawImage>(find.byType(RawImage))
                    .image!
                    .isCloneOf(image),
                isTrue,
              );
            }
            await tester.pumpAndSettle();
            expect(
              find.descendant(of: source.first, matching: find.byType(Image)),
              findsNothing,
            );
            final galleryImages = find.descendant(
              of: find.byType(MImageBrowser),
              matching: find.byType(RawImage),
            );
            expect(galleryImages, findsWidgets);
            for (
              var index = 0;
              index < galleryImages.evaluate().length;
              index++
            ) {
              _expectRect(
                tester.getRect(galleryImages.at(index)),
                const Rect.fromLTWH(0, 700 / 2 - 400 / 3, 400, 800 / 3),
              );
            }
            Navigator.of(editorContext).pop();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 249));
            _expectFlight(tester, card, image);
            await tester.pumpAndSettle();
            expect(find.byType(MImageBrowser), findsNothing);
            expect(find.byType(RawImage), findsOneWidget);
            _expectRect(tester.getRect(source), card);
            expect(
              find.descendant(of: source, matching: find.byType(Image)),
              findsOneWidget,
            );
            expect(host.scroll.offset, 18);
            expect(tester.takeException(), isNull);
          }

          host.previewImage(position);
          await tester.pump();
          if (find.byType(MImageBrowser).evaluate().isEmpty) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          await tester.pump();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final interruptedRect = tester.getRect(find.byType(RawImage));
          Navigator.of(editorContext).pop();
          await tester.pump();
          _expectRect(tester.getRect(find.byType(RawImage)), interruptedRect);
          await tester.pump(const Duration(milliseconds: 99));
          _expectFlight(tester, card, image);
          await tester.pumpAndSettle();
          _expectRect(tester.getRect(source), card);
          expect(
            find.descendant(of: source, matching: find.byType(Image)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
        }),
      );
    }
  }
}
