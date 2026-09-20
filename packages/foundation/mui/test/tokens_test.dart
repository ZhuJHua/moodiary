import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  test('同心圆角：内层 = 外层 − 间距', () {
    expect(
      MuiRadius.inside(MuiRadius.xl, 8),
      const BorderRadius.all(Radius.circular(16)),
    );
    expect(
      MuiRadius.inside(MuiRadius.xl, 16),
      const BorderRadius.all(Radius.circular(8)),
    );
  });

  test('间距大过外层半径时夹到直角，不给负数', () {
    expect(MuiRadius.inside(MuiRadius.md, 20), BorderRadius.zero);
  });

  test('逐角计算，不把非对称圆角抹平', () {
    const outer = BorderRadius.only(
      topLeft: Radius.circular(24),
      bottomRight: Radius.circular(8),
    );
    final inner = MuiRadius.inside(outer, 6);
    expect(inner.topLeft, const Radius.circular(18));
    expect(inner.bottomRight, const Radius.circular(2));
    expect(inner.topRight, Radius.zero);
  });

  test('uses explicit color when set', () {
    expect(
      categoryColorOf(colorValue: 0xFF42A5F5, id: 'x'),
      const Color(0xFF42A5F5),
    );
  });

  test('derives a stable palette color when unset', () {
    final a = categoryColorOf(colorValue: null, id: 'cat-123');
    final b = categoryColorOf(colorValue: null, id: 'cat-123');
    expect(a, b);
    expect(kCategoryPalette.contains(a), isTrue);
  });
}
