import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

void main() {
  // go_router 的 Navigator 装的是裸 HeroController（认不出 material_ui 的
  // MaterialApp），弧线只能由 Hero 自己带；Hero 侧的 createRectTween 优先。
  test('MHero 自带 material 的弧线补间', () {
    const hero = MHero(tag: 'x', child: SizedBox());
    final tween = hero.createRectTween!(
      const Rect.fromLTWH(0, 0, 10, 10),
      const Rect.fromLTWH(50, 80, 100, 100),
    );
    expect(tween, isA<MaterialRectArcTween>());
  });
}
