import 'package:material_ui/material_ui.dart';

RectTween _arcRectTween(Rect? begin, Rect? end) =>
    MaterialRectArcTween(begin: begin, end: end);

/// [Hero] 的补充：飞行轨迹默认走 material 的弧线，而不是直线。
///
/// 这条弧线平时由 `MaterialApp` 装的 hero controller 给，但页面飞在 go_router 自己的
/// Navigator 下——go_router 认不出 material_ui 的 `MaterialApp`（详见 moodiary_router
/// 的 route_page.dart），装的是不带 `createRectTween` 的裸 [HeroController]，弧线于是
/// 退成直线。Hero 自带的 `createRectTween` 优先级高于 controller（heroes.dart 的
/// `_HeroFlightManifest.createRectTween`），从这一侧补回来即可。
class MHero extends Hero {
  const MHero({
    super.key,
    required super.tag,
    required super.child,
    super.flightShuttleBuilder,
    super.placeholderBuilder,
    super.transitionOnUserGestures,
  }) : super(createRectTween: _arcRectTween);
}
