import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_core/moodiary_core.dart';

void main() {
  // 这条派生规则以前散在六处、还分两套公式（定长 substring(6,42) 与按点号定位），
  // 其中两处裸 substring 会同步抛 RangeError。收成一份之后用测试钉住边界。
  group('AppFiles.thumbnailNameOf', () {
    const uuid = '0123456789abcdef0123456789abcdef0123'; // 36 位

    test('标准名 → thumbnail-<uuid>.jpeg', () {
      expect(AppFiles.thumbnailNameOf('video-$uuid.mp4'), 'thumbnail-$uuid.jpeg');
    });

    test('扩展名长短不影响结果（按最后一个点定位，不靠定长）', () {
      expect(AppFiles.thumbnailNameOf('video-$uuid.mov'), 'thumbnail-$uuid.jpeg');
      expect(AppFiles.thumbnailNameOf('video-$uuid.webm'), 'thumbnail-$uuid.jpeg');
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
      // 这几个就是原来 substring(6, 42) 直接在 build 里红屏的输入。
      for (final bad in ['', 'v', 'video-', 'video-.mp4', 'video-abc', 'mp4']) {
        expect(
          () => AppFiles.thumbnailNameOf(bad),
          returnsNormally,
          reason: '输入「$bad」不该抛异常',
        );
        expect(AppFiles.thumbnailNameOf(bad), isNull, reason: '输入「$bad」应判为不合约定');
      }
    });
  });
}
