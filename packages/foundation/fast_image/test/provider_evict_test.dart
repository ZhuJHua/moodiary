import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fast_image/fast_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a failed load is evicted so the next attempt retries', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('fast_image_evict');
      addTearDown(() => dir.delete(recursive: true));
      final provider = FastImage('${dir.path}/late.png');

      Future<Object?> attempt() {
        final done = Completer<Object?>();
        provider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (_, _) => done.complete(null),
                onError: (error, _) => done.complete(error),
              ),
            );
        return done.future;
      }

      expect(await attempt(), isNotNull, reason: '文件不存在，第一次必失败');
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
        reason: '失败后 pending 条目应被踢出，否则永远拿到同一次失败',
      );

      await File(provider.path).writeAsBytes(await _onePixelPng());
      expect(await attempt(), isNull);
    });
  });
}

Future<List<int>> _onePixelPng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 1, 1), ui.Paint());
  final image = await recorder.endRecording().toImage(1, 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
