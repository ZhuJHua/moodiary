import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/src/common/video/video_fullscreen_page.dart';

double _screenSeconds(Duration duration, double width) =>
    scrubMillisPerPixel(duration, width) * width / 1000;

void main() {
  group('scrubMillisPerPixel', () {
    const width = 400.0;

    test('短片：一屏正好是全片的 60%', () {
      expect(
        _screenSeconds(const Duration(seconds: 30), width),
        closeTo(18, 1e-9),
      );
      expect(
        _screenSeconds(const Duration(seconds: 60), width),
        closeTo(36, 1e-9),
      );
    });

    test('长片封顶：一屏最多约 67 秒，不再随时长膨胀', () {
      final tenMin = _screenSeconds(const Duration(minutes: 10), width);
      final oneHour = _screenSeconds(const Duration(hours: 1), width);
      expect(tenMin, closeTo(400 / 6, 1e-9));
      expect(oneHour, tenMin, reason: '封顶之后与时长无关');
    });

    test('拐点在两分钟左右：再长就进封顶区', () {
      final below = scrubMillisPerPixel(const Duration(seconds: 100), width);
      final above = scrubMillisPerPixel(const Duration(seconds: 200), width);
      expect(below, lessThan(1000 / 6));
      expect(above, closeTo(1000 / 6, 1e-9));
    });

    test('宽度未知（首帧还没量出来）返回 0，不会算出 Infinity', () {
      expect(scrubMillisPerPixel(const Duration(seconds: 30), 0), 0);
    });

    test('时长未知返回 0：不知道片长就没有可换算的东西', () {
      expect(scrubMillisPerPixel(.zero, width), 0);
    });
  });
}
