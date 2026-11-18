import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

import 'mcp_service.dart';

enum KeepAlivePermission { batteryOptimization, notifications }

final class KeepAlivePermissionStatus {
  const KeepAlivePermissionStatus({
    required this.permission,
    required this.granted,
  });

  final KeepAlivePermission permission;

  final bool granted;
}

/// Runs Android's foreground service while MCP is running. Native calls
/// occur only when that state changes.
@lazySingleton
class McpKeepAlive implements BackgroundKeepAliveEvents {
  McpKeepAlive(this._server, this._notificationPermission) {
    BackgroundKeepAliveEvents.setUp(this);
    _server.state.addListener(_onServerStateChanged);
  }

  final McpService _server;
  final NotificationPermission _notificationPermission;

  @override
  Future<void> onStopRequested() => _server.disable();

  /// Last value handed to the native keep-alive; `null` means unknown.
  bool? _keepAliveRunning;

  Future<void> restore() => _apply();

  /// Failed native reads fall back to ungranted permissions.
  Future<List<KeepAlivePermissionStatus>> statuses() async {
    try {
      final api = BackgroundKeepAliveApi();
      final granted = await Future.wait([
        api.isExempt(),
        _notificationPermission.isEnabled(),
      ]);
      return [
        KeepAlivePermissionStatus(
          permission: KeepAlivePermission.batteryOptimization,
          granted: granted[0],
        ),
        KeepAlivePermissionStatus(
          permission: KeepAlivePermission.notifications,
          granted: granted[1],
        ),
      ];
    } catch (e, s) {
      logger.e(
        'McpKeepAlive: reading permissions failed',
        error: e,
        stackTrace: s,
      );
      return [
        for (final permission in KeepAlivePermission.values)
          KeepAlivePermissionStatus(permission: permission, granted: false),
      ];
    }
  }

  /// Permission dialogs are asynchronous; re-read [statuses] on resume.
  Future<void> request(KeepAlivePermission permission) async {
    final api = BackgroundKeepAliveApi();
    switch (permission) {
      case KeepAlivePermission.batteryOptimization:
        await api.requestExemption();
      case KeepAlivePermission.notifications:
        if (!await _notificationPermission.request()) {
          await _notificationPermission.openSettings();
        }
    }
  }

  Future<void> openAppSettings() => BackgroundKeepAliveApi().openAppSettings();

  void _onServerStateChanged() => unawaited(_apply());

  Future<void> _apply() async {
    try {
      final shouldRun = _server.state.value.running;
      if (shouldRun == _keepAliveRunning) return;
      if (!shouldRun && _keepAliveRunning == null) {
        // A cold start with MCP disabled must not call native code.
        _keepAliveRunning = false;
        return;
      }
      _keepAliveRunning = shouldRun;
      await BackgroundKeepAliveApi().setKeepAlive(
        shouldRun,
        l10n.app.mcpKeepAliveNotificationText,
        l10n.app.mcpKeepAliveStop,
      );
    } catch (e, s) {
      _keepAliveRunning = null;
      logger.e(
        'McpKeepAlive: toggling keep-alive failed',
        error: e,
        stackTrace: s,
      );
    }
  }
}
