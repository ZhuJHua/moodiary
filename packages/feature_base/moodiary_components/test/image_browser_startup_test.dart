import 'dart:async';
import 'dart:ui' as ui;

import 'package:dismissible_page/dismissible_page.dart';
import 'package:fast_image/fast_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:photo_view/photo_view.dart';

import 'support/pump.dart';

class _Work {
  int keys = 0;
  int loads = 0;
  int probes = 0;
  final paths = <String>[];
  final phases = <SchedulerPhase>[];
}

class _CountingImage extends ImageProvider<_CountingImage> {
  const _CountingImage(this.frame, this.work, {this.pending});

  final ui.Image frame;
  final _Work work;
  final Future<ImageInfo>? pending;

  @override
  Future<_CountingImage> obtainKey(ImageConfiguration configuration) {
    work.keys++;
    work.phases.add(SchedulerBinding.instance.schedulerPhase);
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CountingImage key,
    ImageDecoderCallback decode,
  ) {
    work.loads++;
    return OneFrameImageStreamCompleter(
      pending ?? SynchronousFuture(ImageInfo(image: frame.clone())),
    );
  }
}

Future<ui.Image> _image(WidgetTester tester) async {
  final image = (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xffff0000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(240, 160);
    picture.dispose();
    return image;
  }))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    image.dispose();
  });
  return image;
}

void main() {
  for (final warm in [false, true]) {
    testWidgets('push first frames start no image or viewer work warm=$warm', (
      tester,
    ) async {
      final image = await _image(tester);
      final work = _Work();
      final provider = _CountingImage(image, work);
      if (warm) {
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: image.clone())),
          ),
        );
      }
      final probe = Completer<FastTileSource?>();
      late BuildContext origin;
      await tester.pumpWidget(
        muiTestApp(
          Builder(
            builder: (context) {
              origin = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      unawaited(
        MImageBrowser.show(
          origin,
          images: List.generate(51, (index) => '/page-$index.png'),
          initialIndex: 25,
          heroPrefix: 'page',
          placeholderTier: FastImageTier.s,
          imageProviderBuilder: (path, _) {
            work.paths.add(path);
            return provider;
          },
          regionResolver: (_) {
            work.probes++;
            return warm ? SynchronousFuture(null) : probe.future;
          },
        ),
      );
      await tester.pump();
      if (!warm) {
        await tester.pump(const Duration(milliseconds: 149));
        expect(find.byType(MImageBrowser), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(work.keys, 1);
      expect(work.loads, warm ? 0 : 1);
      expect(work.probes, 1);
      expect(
        work.phases,
        everyElement(isNot(SchedulerPhase.persistentCallbacks)),
      );
      final keysBeforePush = work.keys;
      final loadsBeforePush = work.loads;
      final probesBeforePush = work.probes;
      await tester.pump();
      final browserContext = tester.element(find.byType(MImageBrowser));
      final route = ModalRoute.of(browserContext)!;
      expect(route.animation!.value, 0);
      expect(find.byType(PhotoView), findsNothing);
      expect(find.byType(FastTileImageViewer), findsNothing);
      expect(find.byType(PageView), findsNothing);
      await tester.pump(const Duration(milliseconds: 80));
      expect(route.animation!.value, 0);
      expect(work.keys - keysBeforePush, 0);
      expect(work.loads - loadsBeforePush, 0);
      expect(work.probes - probesBeforePush, 0);
      expect(work.paths.toSet(), {'/page-25.png'});
      await tester.pump(const Duration(milliseconds: 16));
      expect(route.animation!.value, greaterThan(0));
      expect(find.byType(PhotoView), findsNothing);
      if (!warm) probe.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(PhotoView), findsWidgets);
      expect(work.probes, 1);
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('27 / 51'), findsOneWidget);
      expect(work.probes, 2);
      expect(work.paths, contains('/page-26.png'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('stalled image and region preparation push after 150 ms', (
    tester,
  ) async {
    final image = await _image(tester);
    final work = _Work();
    final decoded = Completer<ImageInfo>();
    final probe = Completer<FastTileSource?>();
    final provider = _CountingImage(image, work, pending: decoded.future);
    late BuildContext origin;
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    unawaited(
      MImageBrowser.show(
        origin,
        images: const ['/stalled.png'],
        imageProviderBuilder: (_, _) => provider,
        regionResolver: (_) => probe.future,
      ),
    );
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byType(MImageBrowser), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(MImageBrowser), findsOneWidget);
    expect(find.byType(PhotoView), findsNothing);
    expect(work.loads, 1);
    decoded.complete(ImageInfo(image: image.clone()));
    probe.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final duringPush in [true, false]) {
    testWidgets('X closes once and shields diary duringPush=$duringPush', (
      tester,
    ) async {
      final image = await _image(tester);
      final provider = _CountingImage(image, _Work());
      late BuildContext home;
      late BuildContext diary;
      var underlyingTaps = 0;
      await tester.pumpWidget(
        muiTestApp(
          Builder(
            builder: (context) {
              home = context;
              return const Text('home');
            },
          ),
        ),
      );
      unawaited(
        Navigator.of(home).push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (context) {
                  diary = context;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      underlyingTaps++;
                      Navigator.of(context).pop();
                    },
                    child: const SizedBox.expand(child: Text('diary')),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        MImageBrowser.show(
          diary,
          images: const ['/close.png'],
          imageProviderBuilder: (_, _) => provider,
          regionResolver: (_) => SynchronousFuture(null),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      if (duringPush) {
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 16));
      } else {
        await tester.pumpAndSettle();
      }
      final dismissed = tester
          .widget<DismissiblePage>(find.byType(DismissiblePage))
          .onDismissed;
      expect(
        ModalRoute.of(tester.element(find.byType(MImageBrowser)))!
            .animation!
            .value,
        greaterThan(0),
      );
      final close = find.widgetWithIcon(IconButton, LucideIcons.x);
      final position = tester.getCenter(close);
      await tester.tapAt(position);
      await tester.pump();
      expect(ModalRoute.of(diary)!.isCurrent, isTrue);
      await tester.tapAt(position);
      dismissed();
      dismissed();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.tapAt(position);
      await tester.pumpAndSettle();
      expect(find.byType(MImageBrowser), findsNothing);
      expect(find.text('diary'), findsOneWidget);
      expect(underlyingTaps, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('X works on the zero-progress first frame', (tester) async {
    final image = await _image(tester);
    final provider = _CountingImage(image, _Work());
    late BuildContext origin;
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return const Text('origin');
          },
        ),
      ),
    );
    unawaited(
      MImageBrowser.show(
        origin,
        images: const ['/early-close.png'],
        imageProviderBuilder: (_, _) => provider,
        regionResolver: (_) => SynchronousFuture(null),
      ),
    );
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.byType(MImageBrowser)))!;
    expect(route.animation!.value, 0);
    await tester.tap(find.widgetWithIcon(IconButton, LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.byType(MImageBrowser), findsNothing);
    expect(find.text('origin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prepared route preserves reduced motion timing', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final image = await _image(tester);
    final provider = _CountingImage(image, _Work());
    late BuildContext origin;
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    unawaited(
      MImageBrowser.show(
        origin,
        images: const ['/reduced-motion.png'],
        imageProviderBuilder: (_, _) => provider,
        regionResolver: (_) => SynchronousFuture(null),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final route = ModalRoute.of(tester.element(find.byType(MImageBrowser)))!;
    expect(route.animation!.value, 0);
    await tester.pump(const Duration(milliseconds: 13));
    expect(route.animation!.isCompleted, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(PhotoView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preparation abandons a caller removed before the push', (
    tester,
  ) async {
    final image = await _image(tester);
    final provider = _CountingImage(image, _Work());
    final probe = Completer<FastTileSource?>();
    late BuildContext origin;
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) {
            origin = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final shown = MImageBrowser.show(
      origin,
      images: const ['/abandoned.png'],
      imageProviderBuilder: (_, _) => provider,
      regionResolver: (_) => probe.future,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 150));
    await shown;
    probe.complete(null);
    await tester.pump();
    expect(find.byType(MImageBrowser), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
