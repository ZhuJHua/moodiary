import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';

void main() {
  group('AppFiles.thumbnailNameOf', () {
    const uuid = '0123456789abcdef0123456789abcdef0123';

    test('标准名 → thumbnail-<uuid>.jpeg', () {
      expect(
        AppFiles.thumbnailNameOf('video-$uuid.mp4'),
        'thumbnail-$uuid.jpeg',
      );
    });

    test('扩展名长短不影响结果（按最后一个点定位，不靠定长）', () {
      expect(
        AppFiles.thumbnailNameOf('video-$uuid.mov'),
        'thumbnail-$uuid.jpeg',
      );
      expect(
        AppFiles.thumbnailNameOf('video-$uuid.webm'),
        'thumbnail-$uuid.jpeg',
      );
    });

    test('文件名里含多个点时取最后一个', () {
      expect(
        AppFiles.thumbnailNameOf('video-my.clip.name.mp4'),
        'thumbnail-my.clip.name.jpeg',
      );
    });

    test('前缀不对 → null（而不是切出一段乱码）', () {
      expect(AppFiles.thumbnailNameOf('image-$uuid.jpg'), isNull);
      expect(AppFiles.thumbnailNameOf('$uuid.mp4'), isNull);
    });

    test('短名 / 空名 / 无扩展名 → null，绝不抛 RangeError', () {
      for (final bad in ['', 'v', 'video-', 'video-.mp4', 'video-abc', 'mp4']) {
        expect(
          () => AppFiles.thumbnailNameOf(bad),
          returnsNormally,
          reason: '输入「$bad」不该抛异常',
        );
        expect(
          AppFiles.thumbnailNameOf(bad),
          isNull,
          reason: '输入「$bad」应判为不合约定',
        );
      }
    });
  });
}
