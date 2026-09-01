import 'package:flutter/widgets.dart';

/// 全局页面路由观察者：app 侧挂到 GoRouter.observers。页面混入 [RouteAware]
/// 订阅后可感知 didPushNext / didPopNext / didPop，做焦点保存恢复等路由级联动。
/// 只观察 [PageRoute]（对话框等 PopupRoute 不触发）。
final RouteObserver<PageRoute<dynamic>> moodiaryRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
