import 'dart:ui' as ui;

import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';

import 'support/pump.dart';

Future<void> _cacheImage(WidgetTester tester, ImageProvider provider) async {
  final image = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const Color(0xFFFF0000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 100);
    picture.dispose();
    return image;
  });
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'browser preserves occurrence tags on its first frame and current page',
    (tester) async {
      const path = '/gallery.png';
      await _cacheImage(tester, const FastImage(path, tier: FastImageTier.s));
      await tester.pumpWidget(
        muiTestApp(
          const MImageBrowser(
            images: [path, path, path],
            heroTags: ['first', 'second', 'third'],
            initialIndex: 1,
            placeholderTier: FastImageTier.s,
          ),
        ),
      );
      expect(
        tester.widgetList<Hero>(find.byType(Hero)).map((hero) => hero.tag),
        contains('second'),
      );
      expect(find.text('2 / 3'), findsOneWidget);
      for (final hero in tester.widgetList<Hero>(find.byType(Hero))) {
        expect(hero.flightShuttleBuilder, isNull);
      }
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      final active = tester.widget<HeroMode>(
        find
            .ancestor(
              of: find.byWidgetPredicate((w) => w is Hero && w.tag == 'third'),
              matching: find.byType(HeroMode),
            )
            .first,
      );
      expect(active.enabled, isTrue);
      final tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((hero) => hero.tag)
          .toList();
      expect(tags.toSet(), hasLength(tags.length));
      final hero = tester.widget<Hero>(
        find.byWidgetPredicate((w) => w is Hero && w.tag == 'third'),
      );
      expect(hero.flightShuttleBuilder, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('browser preserves prefix Heroes', (tester) async {
    const path = '/prefixed.png';
    await _cacheImage(tester, const FastImage(path, tier: FastImageTier.s));
    await tester.pumpWidget(
      muiTestApp(
        const MImageBrowser(
          images: [path],
          heroPrefix: 'media',
          placeholderTier: FastImageTier.s,
        ),
      ),
    );
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'media-$path');
    expect(hero.flightShuttleBuilder, isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('browser requires a tag for each image', (tester) async {
    await tester.pumpWidget(
      muiTestApp(const MImageBrowser(images: ['a', 'a'], heroTags: ['a'])),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('browser requires unique tags for repeated images', (
    tester,
  ) async {
    await tester.pumpWidget(
      muiTestApp(
        const MImageBrowser(images: ['a', 'a'], heroTags: ['same', 'same']),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });
}
