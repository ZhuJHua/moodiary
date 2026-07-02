import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract class MoodiaryRouteBase {
  const MoodiaryRouteBase();

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

String buildLocation(String path, [Map<String, String?> query = const {}]) {
  final params = <String, String>{};
  query.forEach((key, value) {
    if (value != null) params[key] = value;
  });
  return Uri.parse(
    path,
  ).replace(queryParameters: params.isEmpty ? null : params).toString();
}
