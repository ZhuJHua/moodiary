import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FastImageTier.fit', () {
    test('向上取档：网格 / 日历落 s，正文 / 单图落 m', () {
      expect(FastImageTier.fit(1), FastImageTier.s);
      expect(FastImageTier.fit(132), FastImageTier.s);
      expect(FastImageTier.fit(512), FastImageTier.s);
      expect(FastImageTier.fit(513), FastImageTier.m);
      expect(FastImageTier.fit(1280), FastImageTier.m);
    });

    test('比最大档还宽也只给最大档：列表里永远不解原图', () {
      expect(FastImageTier.fit(1281), FastImageTier.m);
      expect(FastImageTier.fit(4000), FastImageTier.m);
    });
  });

  group('FastImageDerivatives.derivativeNamesOf', () {
    const uuid = '0192a3b4-c5d6-7e8f-9a0b-c1d2e3f4a5b6';

    test('两档 × 两种后缀 + baseline 副本，名字不带源图后缀', () {
      expect(FastImageDerivatives.derivativeNamesOf('image-$uuid.jpg'), [
        'image-${uuid}_512.jpg',
        'image-${uuid}_512.png',
        'image-${uuid}_1280.jpg',
        'image-${uuid}_1280.png',
        'image-${uuid}_base.jpg',
      ]);
    });

    test('同一张图换后缀（历史 heic）派生物名字一致，删图不会漏', () {
      expect(
        FastImageDerivatives.derivativeNamesOf('image-$uuid.heic'),
        FastImageDerivatives.derivativeNamesOf('image-$uuid.webp'),
      );
    });
  });

  group('FastImageDerivatives.candidateNames', () {
    const uuid = '0192a3b4-c5d6-7e8f-9a0b-c1d2e3f4a5b6';

    test('后缀由内容定，源是什么后缀都先 .jpg 再 .png', () {
      expect(FastImageDerivatives.candidateNames('image-$uuid.jpg', .s), [
        'image-${uuid}_512.jpg',
        'image-${uuid}_512.png',
      ]);
      expect(FastImageDerivatives.candidateNames('image-$uuid.png', .m), [
        'image-${uuid}_1280.jpg',
        'image-${uuid}_1280.png',
      ]);
    });
  });
}
