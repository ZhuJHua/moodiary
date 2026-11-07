import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

import '../server/mcp_server.dart';
import '../tools/register_moodiary_tools.dart';
import '../transport/io_mcp_transport.dart';
import '../transport/transport.dart';

/// Default port offered in the settings page.
const int mcpDefaultPort = 8765;

enum McpServerStatus { stopped, starting, running, failed }

@immutable
class McpServerState {
  const McpServerState({
    this.status = .stopped,
    this.port,
    this.endpoints = const [],
    this.allowLan = false,
    this.error,
  });

  final McpServerStatus status;
  final int? port;
  final List<Uri> endpoints;
  final bool allowLan;
  final String? error;

  bool get running => status == .running;

  @override
  bool operator ==(Object other) =>
      other is McpServerState &&
      other.status == status &&
      other.port == port &&
      other.allowLan == allowLan &&
      other.error == error &&
      listEquals(other.endpoints, endpoints);

  @override
  int get hashCode =>
      Object.hash(status, port, allowLan, error, Object.hashAll(endpoints));
}

/// Owns the local MCP endpoint: builds the tool catalog, starts and stops the
/// transport, keeps the bearer token and mirrors database changes to clients.
///
/// The service is a process level singleton and never touches the UI; the
/// settings page observes [state] and calls [enable] / [disable].
@lazySingleton
class McpService {
  McpService(this._diaries, this._categories, this._insights);

  /// Replaceable for tests.
  static McpTransport Function() transportFactory = IoMcpTransport.new;

  final DiaryRepository _diaries;
  final CategoryRepository _categories;
  final MoodInsightsRepository _insights;

  final ValueNotifier<McpServerState> state = ValueNotifier(
    const McpServerState(),
  );

  McpServer? _server;
  McpTransport? _transport;
  String? _token;
  StreamSubscription<DiaryEvent>? _diaryEvents;
  StreamSubscription<CategoryEvent>? _categoryEvents;
  bool _busy = false;

  String? get token => _token;

  bool get enabled => MoodiaryKVs.mcpEnabled.get() ?? false;

  static int get configuredPort => MoodiaryKVs.mcpPort.get() ?? mcpDefaultPort;

  static bool get allowLan => MoodiaryKVs.mcpAllowLan.get() ?? false;

  /// Starts the server when the user turned the switch on; called once from the
  /// app bootstrap so a previously enabled server comes back after a restart.
  Future<void> restore() async {
    if (!enabled) return;
    await start();
  }

  /// The settings switch: persist the flag and start right away.
  Future<void> enable({int? port, bool? lan}) async {
    MoodiaryKVs.mcpEnabled.set(true);
    if (port != null) MoodiaryKVs.mcpPort.set(port);
    if (lan != null) MoodiaryKVs.mcpAllowLan.set(lan);
    await start();
  }

  Future<void> disable() async {
    MoodiaryKVs.mcpEnabled.set(false);
    await stop();
  }

  /// Stops the endpoint without touching the persisted switch, e.g. while the
  /// app lock is up.
  Future<void> pause() => stop();

  Future<void> resume() async {
    if (!enabled) return;
    await start();
  }

  /// Applies a new port or LAN policy; restarts when the server is running.
  Future<void> updateConfig({int? port, bool? lan}) async {
    final wasRunning = state.value.running;
    if (port != null) MoodiaryKVs.mcpPort.set(port);
    if (lan != null) MoodiaryKVs.mcpAllowLan.set(lan);
    if (!wasRunning) return;
    await stop();
    await start();
  }

  Future<void> start() async {
    if (_busy || state.value.status == .running) return;
    _busy = true;
    _set(const McpServerState(status: .starting));
    try {
      final token = await ensureToken();
      final version = await _appVersion();
      final server = McpServer(
        registry: buildMoodiaryRegistry(
          diaries: _diaries,
          categories: _categories,
          insights: _insights,
          appVersion: version,
        ),
        serverVersion: version,
      );
      final transport = transportFactory();
      await transport.start(
        McpTransportConfig(
          port: configuredPort,
          allowLan: allowLan,
          token: token,
        ),
        server,
      );
      _server = server;
      _transport = transport;
      _listenForChanges(server);
      _set(
        McpServerState(
          status: .running,
          port: transport.port,
          endpoints: transport.endpoints,
          allowLan: allowLan,
        ),
      );
      logger.i('MCP server listening on ${transport.endpoints.join(', ')}');
    } catch (e, s) {
      logger.e('MCP server failed to start', error: e, stackTrace: s);
      await _teardown();
      _set(McpServerState(status: .failed, error: '$e'));
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    if (state.value.status == .stopped) return;
    await _teardown();
    _set(const McpServerState());
  }

  /// Rotates the bearer token; a running server is restarted to use it.
  Future<String> regenerateToken() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    await MoodiarySecureKVs.mcpToken.set(token);
    _token = token;
    if (state.value.running) {
      await stop();
      await start();
    }
    return token;
  }

  Future<String> ensureToken() async {
    final cached = _token;
    if (cached != null && cached.isNotEmpty) return cached;
    final stored = await MoodiarySecureKVs.mcpToken.get();
    if (stored != null && stored.isNotEmpty) return _token = stored;
    return regenerateToken();
  }

  Future<void> _teardown() async {
    await _diaryEvents?.cancel();
    await _categoryEvents?.cancel();
    _diaryEvents = null;
    _categoryEvents = null;
    final transport = _transport;
    final server = _server;
    _transport = null;
    _server = null;
    try {
      await transport?.stop();
    } catch (e, s) {
      logger.e('MCP transport stop failed', error: e, stackTrace: s);
    }
    server?.dispose();
  }

  void _listenForChanges(McpServer server) {
    _diaryEvents = _diaries.diaryEvents.listen((event) {
      server.resourceUpdated('moodiary://stats/overview');
      switch (event) {
        case DiaryCreated(:final diary) || DiaryUpdated(:final diary):
          server.resourceUpdated('moodiary://diary/${diary.id}');
          server.resourceUpdated('moodiary://diaries/recent');
        case DiaryDeleted(:final id):
          server.resourceUpdated('moodiary://diary/$id');
          server.resourceUpdated('moodiary://diaries/recent');
      }
    });
    _categoryEvents = _categories.categoryEvents.listen((_) {
      server.resourceUpdated('moodiary://categories');
      server.resourceUpdated('moodiary://stats/overview');
    });
  }

  void _set(McpServerState next) {
    state.value = next;
  }

  Future<String> _appVersion() async {
    try {
      return (await AppInfo.getPackageInfo()).version;
    } catch (e) {
      logger.d('MCP: package info unavailable ($e)');
      return '0.0.0';
    }
  }
}
