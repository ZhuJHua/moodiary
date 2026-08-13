import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 带转场动画的 [GoRoute]：只把 `builder` 换成 `pageBuilder`，其余原样透传。
///
/// go_router 用 `findAncestorWidgetOfExactType<MaterialApp>()` 猜宿主类型来决定
/// `builder:` 路由包成哪种 Page（builder.dart 的 `_cacheAppType`）。它认的是
/// legacy `package:flutter/material.dart` 的 `MaterialApp`，而我们挂的是
/// material_ui 里的同名新类——类型不同，探测就落到 WidgetsApp 分支，所有页面被包成
/// [NoTransitionPage]，切页因此完全没有动画。
///
/// 在 go_router 认识 material_ui 之前（17.5.0 仍未），Page 由路由自己给：
/// [MaterialPage] 走 `MaterialRouteTransitionMixin`，转场取自
/// `ThemeData.pageTransitionsTheme`（Android 预测性返回 / iOS 侧滑）。
///
/// 各字段与 go_router 自己的 material 分支一致（key/name/arguments/restorationId）。
class MoodiaryGoRoute extends GoRoute {
  MoodiaryGoRoute({
    required super.path,
    required GoRouterWidgetBuilder builder,
    super.name,
    super.parentNavigatorKey,
    super.redirect,
    super.metadata,
    super.onExit,
    super.caseSensitive,
    super.routes,
  }) : super(
         pageBuilder: (context, state) => MaterialPage<void>(
           key: state.pageKey,
           name: state.name ?? state.path,
           arguments: <String, String>{
             ...state.pathParameters,
             ...state.uri.queryParameters,
           },
           restorationId: state.pageKey.value,
           child: builder(context, state),
         ),
       );
}
