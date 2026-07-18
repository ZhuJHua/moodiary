import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

void main() {
  test('uuidV7 前 48 位是毫秒时间戳（extractDateFromUUID 依赖此布局）', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final id = uuidV7();
    final after = DateTime.now().millisecondsSinceEpoch;
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    final ms = int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(ms, inInclusiveRange(before, after));
  });

  test('uuidV4 格式合法且不重复', () {
    final a = uuidV4();
    final b = uuidV4();
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(a, isNot(b));
  });
}
