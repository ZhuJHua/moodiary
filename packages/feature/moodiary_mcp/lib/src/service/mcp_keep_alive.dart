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
/// Only Android can do that, and it needs an OS-level reason to stay alive:
///
/// * Android runs a `specialUse` foreground service with an ongoing
///   notification ([_apply] passes the notification copy through
///   [BackgroundKeepAliveApi.setKeepAlive]). The service keeps the process out
///   of the background bucket; [statuses] reports the two permissions it needs
///   (battery optimisation exemption for Doze and vendor ROMs, notification
///   permission for the visible ongoing notification) and [request] asks for
///   them. [openAppSettings] is the fallback once Android stops showing its own
///   dialog.
/// * iOS has no background keep-alive: the endpoint is reachable only while the
///   app is in the foreground there, because holding an audio session open would
///   take the audio session away from the app and from other apps. [supported]
///   is therefore Android only, and the settings page hides the switch on iOS.
///
/// The switch itself is persisted: [restore] re-applies it when the lock
/// observer brings the endpoint back after a restart, [setEnabled] persists a
/// change, and the [McpService.state] listener applies it whenever the endpoint
/// starts or stops. A cold start writes nothing to the platform until the
/// endpoint actually runs, and [_apply] only calls into native when the desired
/// state differs from the last one it handed over.
@lazySingleton
class McpKeepAlive {
  McpKeepAlive(this._server) {
    _server.state.addListener(_onServerStateChanged);
  }

  final McpService _server;

  /// Last value handed to the native keep-alive; `null` means unknown.
  bool? _keepAliveRunning;

  bool get enabled => MoodiaryKVs.mcpBackgroundKeepAlive.get() ?? false;

  /// Whether this platform can keep the endpoint alive at all.
  ///
  /// Only Android: host platforms and iOS offer no background mode, so the
  /// settings page hides the section there and [statuses] has nothing to report.
  bool get supported => Platform.isAndroid;

  /// Re-applies the persisted switch; the app lock observer calls this before it
  /// brings the endpoint back, so the switch also survives a restart.
  ///
  /// This is safe on a cold start: asserting "off" before anything runs in this
  /// process only sets the in-memory marker ([_apply]) and never reaches native.
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
      if (!shouldRun && _keepAliveRunning == null) {
        // Nothing ran in this process yet, so there is nothing to stop: record
        // "off" without a native call. A cold start that never enabled the
        // endpoint must not touch the platform side at all.
        _keepAliveRunning = false;
        return;
      }
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
