import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
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
/// On Android reachability is decided by the permissions [statuses] reports:
/// the battery optimisation exemption and the notification permission. Losing
/// either one makes the system stop the process (or hide the ongoing
/// notification) sooner or later, so the page renders one row per permission
/// and calls [request] on the row the user taps; [openAppSettings] is the
/// fallback once Android stops showing its own dialog. Android needs no
/// keep-alive code of its own.
///
/// On iOS an active audio session is what lets the process keep running, so
/// [setEnabled] merely persists the switch, [restore] re-applies it after a
/// restart, and the silent audio track loops while the switch is on and the
/// server is actually running.
@lazySingleton
class McpKeepAlive {
  McpKeepAlive(this._server) {
    _server.state.addListener(_onServerStateChanged);
  }

  final McpService _server;

  /// Last value handed to the native silent audio player; `null` means unknown.
  bool? _audioRunning;

  bool get enabled => MoodiaryKVs.mcpBackgroundKeepAlive.get() ?? false;

  /// Host platforms offer no background mode; tests then never touch native.
  bool get supported => Platform.isAndroid || Platform.isIOS;

  /// Re-applies the persisted switch after a restart, called from the bootstrap.
  Future<void> restore() => _apply();

  /// The permissions the keep-alive needs on this platform, in display order.
  ///
  /// Empty off Android, where the system owns the decision instead. A failed
  /// native read falls back to "not granted" rows so the page can still ask
  /// for them.
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

  /// Persists the iOS switch and starts or stops the background mode right away.
  ///
  /// Android has no switch any more: its permissions, not this flag, decide
  /// whether the endpoint stays reachable, so [request] drives them instead.
  Future<void> setEnabled(bool on) async {
    MoodiaryKVs.mcpBackgroundKeepAlive.set(on);
    await _apply();
  }

  void _onServerStateChanged() => unawaited(_apply());

  Future<void> _apply() async {
    if (!Platform.isIOS) return;
    try {
      final shouldRun = enabled && _server.state.value.running;
      if (shouldRun == _audioRunning) return;
      _audioRunning = shouldRun;
      await BackgroundKeepAliveApi().setSilentAudio(shouldRun);
    } catch (e, s) {
      _audioRunning = null;
      logger.e('McpKeepAlive: silent audio failed', error: e, stackTrace: s);
    }
  }
}
