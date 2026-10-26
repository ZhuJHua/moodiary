import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';
import 'package:skeletonizer/skeletonizer.dart'
    show SkeletonizerConfig, ShimmerEffect, SolidColorEffect;

void main() {
  for (final enabled in [true, false]) {
    testWidgets('enabled=$enabled paints bones or the untouched child', (
      tester,
    ) async {
      const surface = Color(0xFF123456);
      const ink = Color(0xFFFF0000);
      const child = SizedBox(
        width: 180,
        height: 60,
        child: ColoredBox(
          color: surface,
          child: Center(
            child: Text('Loaded content', style: TextStyle(color: ink)),
          ),
        ),
      );
      final theme = buildMuiTheme(brightness: .light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Center(
              child: RepaintBoundary(
                key: const ValueKey('image'),
                child: MSkeleton(enabled: enabled, child: child),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<MSkeleton>(find.byType(MSkeleton)).child,
        same(child),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('image')),
        );
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int pixels(Color color) {
          final argb = color.toARGB32();
          var count = 0;
          for (var i = 0; i < bytes.lengthInBytes; i += 4) {
            if (bytes.getUint8(i) == (argb >> 16 & 255) &&
                bytes.getUint8(i + 1) == (argb >> 8 & 255) &&
                bytes.getUint8(i + 2) == (argb & 255)) {
              count++;
            }
          }
          return count;
        }

        expect(pixels(surface), greaterThan(100));
        expect(pixels(ink), enabled ? 0 : greaterThan(10));
        expect(
          pixels(theme.colorScheme.surfaceContainerHighest),
          enabled ? greaterThan(10) : 0,
        );
        image.dispose();
      });
    });
  }

  testWidgets('app brightness and reduced motion drive the configuration', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final reduceMotion in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildMuiTheme(brightness: brightness),
            themeAnimationDuration: Duration.zero,
            home: MediaQuery(
              data: MediaQueryData(
                platformBrightness: brightness == .light ? .dark : .light,
                disableAnimations: reduceMotion,
              ),
              child: const MSkeleton(enabled: true, child: Text('Content')),
            ),
          ),
        );
        final config = tester
            .widget<SkeletonizerConfig>(find.byType(SkeletonizerConfig))
            .data;
        expect(config.brightness, brightness);
        final effect = config.resolveEffect(brightness);
        if (reduceMotion) {
          expect(effect, isA<SolidColorEffect>());
          expect(effect.duration, Duration.zero);
          await tester.pumpAndSettle();
          expect(tester.binding.transientCallbackCount, 0);
        } else {
          expect(effect, isA<ShimmerEffect>());
        }
      }
    }
  });
}
