import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import 'mcp_service.dart';

/// Keeps the local MCP endpoint reachable while the app sits in the background.
///
/// Android only asks the system for the battery optimisation exemption when the
/// switch is turned on; it owns no actual keep-alive logic. iOS loops a silent
/// audio track, because an active audio session is what lets the process keep
/// running in the background. Either way the keep-alive only runs while the
/// switch is on and the server is actually running.
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

  Future<bool> isExempt() async {
    if (!Platform.isAndroid) return true;
    try {
      return await BackgroundKeepAliveApi().isExempt();
    } catch (e, s) {
      logger.e(
        'McpKeepAlive: reading exemption failed',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  Future<bool> requestExemption() async {
    if (!Platform.isAndroid) return true;
    try {
      return await BackgroundKeepAliveApi().requestExemption();
    } catch (e, s) {
      logger.e(
        'McpKeepAlive: requesting exemption failed',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  /// Persists the switch and starts or stops the background mode right away.
  Future<void> setEnabled(bool on) async {
    MoodiaryKVs.mcpBackgroundKeepAlive.set(on);
    if (on && Platform.isAndroid) await requestExemption();
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
