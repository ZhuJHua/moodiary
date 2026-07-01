import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 所有应用路由的基类：每个具体路由持有参数并编码成 [location]（go_router 用的 URL）。
/// 导航走 [MoodiaryRouteNav] 扩展（`XxxRoute(...).push(context)`）。
abstract class MoodiaryRouteBase {
  const MoodiaryRouteBase();

  /// 填好参数后的完整 location，例如 `/diary/abc?type=markdown`。
  String get location;
}

extension MoodiaryRouteNav on MoodiaryRouteBase {
  Future<T?> push<T extends Object?>(BuildContext context) =>
      context.push<T>(location);

  void go(BuildContext context) => context.go(location);

  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  void replace(BuildContext context) => context.replace(location);
}

/// 把 `path` 与可选 query 拼成 location，剔除值为 null 的 query 项。
/// 路径参数（如 `:diaryId`）须由调用方先 [Uri.encodeComponent] 拼进 [path]。
/// 刻意沿用 go_router 原 `GoRouteData.$location` 语义（`Uri.parse` 不二次编码已编码
/// 的 path），以保持 location 编码契约不变。
String buildLocation(String path, [Map<String, String?> query = const {}]) {
  final params = <String, String>{};
  query.forEach((key, value) {
    if (value != null) params[key] = value;
  });
  return Uri.parse(
    path,
  ).replace(queryParameters: params.isEmpty ? null : params).toString();
}
