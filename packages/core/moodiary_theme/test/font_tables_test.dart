import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_theme/src/font_tables.dart';

const _fonts = '../../foundation/mui/assets/fonts';

void main() {
  test('可变字体：全名 + wght 轴默认值与命名实例（与旧 Rust 实现同值）', () async {
    expect(await FontTables.fullName('$_fonts/Dosis.ttf'), 'Dosis Regular');
    final wght = await FontTables.wghtAxis('$_fonts/Dosis.ttf');
    expect(wght['default'], 200.0);
    expect(wght['Regular'], 400.0);
    expect(wght['ExtraBold'], 800.0);
    expect(wght, hasLength(8));
  });

  test('非可变字体：有名字、没有 wght 轴', () async {
    expect(
      await FontTables.fullName('$_fonts/qweather-icons.ttf'),
      'qweather-icons',
    );
    expect(await FontTables.wghtAxis('$_fonts/qweather-icons.ttf'), isEmpty);
  });
}
