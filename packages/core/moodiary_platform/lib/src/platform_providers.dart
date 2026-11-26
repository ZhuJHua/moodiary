import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'notification_permission.dart';

part 'platform_providers.g.dart';

@Riverpod(keepAlive: true)
NotificationPermission notificationPermission(Ref ref) =>
    throw UnimplementedError(
      'notificationPermissionProvider must be overridden',
    );
