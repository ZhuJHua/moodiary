import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'mcp_service.dart';

/// A permission the background keep-alive depends on, in the order the
/// settings page lists them.
enum KeepAlivePermission { batteryOptimization, notifications }

/// One row of the keep-alive section: the permission and whether the system
/// currently grants it.
@immutable
final class KeepAlivePermissionStatus {
  const KeepAlivePermissionStatus({
    required this.permission,
    required this.granted,
  });

  final KeepAlivePermission permission;

  final bool granted;

  @override
  bool operator ==(Object other) =>
      other is KeepAlivePermissionStatus &&
      other.permission == permission &&
      other.granted == granted;

  @override
  int get hashCode => Object.hash(permission, granted);

  @override
  String toString() =>
      'KeepAlivePermissionStatus(${permission.name}, granted: $granted)';
}

/// Keeps the local MCP endpoint reachable while the app sits in the background.
///
/// Both platforms need an OS-level reason to stay alive, and they differ:
///
/// * Android runs a `specialUse` foreground service with an ongoing
///   notification ([_apply] passes the notification copy through
///   [BackgroundKeepAliveApi.setKeepAlive]). The service keeps the process out
///   of the background bucket; [statuses] reports the two permissions it needs
///   (battery optimisation exemption for Doze and vendor ROMs, notification
///   permission for the visible ongoing notification) and [request] asks for
///   them. [openAppSettings] is the fallback once Android stops showing its own
///   dialog.
/// * iOS keeps the process alive through an active audio session, so the same
///   [BackgroundKeepAliveApi.setKeepAlive] call starts a silent looping track.
///
/// The switch itself is persisted, [restore] re-applies it after a restart, and
/// [_apply] only calls into native when the desired state actually changes, so
/// ordinary server state churn does not restart the service.
@lazySingleton
class McpKeepAlive {
  McpKeepAlive(this._server) {
    _server.state.addListener(_onServerStateChanged);
  }

  final McpService _server;

  /// Last value handed to the native keep-alive; `null` means unknown.
  bool? _keepAliveRunning;

  bool get enabled => MoodiaryKVs.mcpBackgroundKeepAlive.get() ?? false;

  /// Host platforms offer no background mode; tests then never touch native.
  bool get supported => Platform.isAndroid || Platform.isIOS;

  /// Re-applies the persisted switch after a restart, called from the bootstrap.
  Future<void> restore() => _apply();

  /// The permissions the keep-alive needs on this platform, in display order.
  ///
  /// Empty off Android: only Android gates the foreground service on
  /// permissions. A failed native read falls back to "not granted" rows so the
  /// page can still ask for them.
  Future<List<KeepAlivePermissionStatus>> statuses() async {
    if (!Platform.isAndroid) return const [];
    try {
      final api = BackgroundKeepAliveApi();
      final granted = await Future.wait([
        api.isExempt(),
        api.isNotificationsEnabled(),
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

  /// Asks for [permission] and returns the state the system reports right
  /// after the request.
  ///
  /// Android's dialogs are asynchronous, so `false` here only means "still not
  /// granted"; the page re-reads [statuses] when it comes back to the
  /// foreground instead of waiting on the dialog.
  Future<bool> request(KeepAlivePermission permission) async {
    if (!Platform.isAndroid) return true;
    try {
      final api = BackgroundKeepAliveApi();
      return switch (permission) {
        KeepAlivePermission.batteryOptimization => await api.requestExemption(),
        KeepAlivePermission.notifications => await api.requestNotifications(),
      };
    } catch (e, s) {
      logger.e(
        'McpKeepAlive: requesting a permission failed',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// Opens this app's page in the system settings, for permissions the system
  /// no longer asks about.
  Future<void> openAppSettings() async {
    if (!supported) return;
    try {
      await BackgroundKeepAliveApi().openAppSettings();
    } catch (e, s) {
      logger.e(
        'McpKeepAlive: opening the app settings failed',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Persists the switch and turns the background mode on or off right away.
  Future<void> setEnabled(bool on) async {
    MoodiaryKVs.mcpBackgroundKeepAlive.set(on);
    await _apply();
  }

  void _onServerStateChanged() => unawaited(_apply());

  /// Turns the native keep-alive on while the switch is on and the server
  /// actually runs, and off in every other case.
  ///
  /// The notification copy comes from `l10n` because the ongoing notification
  /// is built on the platform side, and this is a service, not a widget.
  Future<void> _apply() async {
    if (!supported) return;
    try {
      final shouldRun = enabled && _server.state.value.running;
      if (shouldRun == _keepAliveRunning) return;
      _keepAliveRunning = shouldRun;
      await BackgroundKeepAliveApi().setKeepAlive(
        shouldRun,
        l10n.app.mcpKeepAliveNotificationTitle,
        l10n.app.mcpKeepAliveNotificationText,
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
