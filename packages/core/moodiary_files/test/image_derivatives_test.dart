import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';

void main() {
  group('ImageTier.fit', () {
    test('向上取档：网格 / 日历落 s，正文 / 单图落 m', () {
      expect(ImageTier.fit(1), ImageTier.s);
      expect(ImageTier.fit(132), ImageTier.s);
      expect(ImageTier.fit(512), ImageTier.s);
      expect(ImageTier.fit(513), ImageTier.m);
      expect(ImageTier.fit(1280), ImageTier.m);
    });

    test('比最大档还宽也只给最大档：列表里永远不解原图', () {
      expect(ImageTier.fit(1281), ImageTier.m);
      expect(ImageTier.fit(4000), ImageTier.m);
    });
  });

  group('ImageDerivatives.derivativeNamesOf', () {
    const uuid = '0192a3b4-c5d6-7e8f-9a0b-c1d2e3f4a5b6';

    test('两档缩略图，名字不带源图后缀', () {
      expect(ImageDerivatives.derivativeNamesOf('image-$uuid.jpg'), [
        'image-${uuid}_512.webp',
        'image-${uuid}_1280.webp',
      ]);
    });

    test('同一张图换后缀（历史 heic）派生物名字一致，删图不会漏', () {
      expect(
        ImageDerivatives.derivativeNamesOf('image-$uuid.heic'),
        ImageDerivatives.derivativeNamesOf('image-$uuid.webp'),
      );
    });
  });
}
