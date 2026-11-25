import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_semantic/moodiary_semantic.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synchronized/synchronized.dart';

import '../tools/register_moodiary_tools.dart';
import '../transport/mcp_http_endpoint.dart';

part 'mcp_service.g.dart';

@Riverpod(keepAlive: true, name: 'mcpServerStateProvider')
class McpServerController extends _$McpServerController {
  McpService? _owner;

  @override
  McpServerState build() {
    ref.onDispose(() => _owner = null);
    return const McpServerState();
  }

  McpServerState _snapshot(McpService owner) =>
      identical(owner, _owner) ? state : const McpServerState();

  void _publish(McpService owner, McpServerState value) {
    _owner = owner;
    state = value;
  }

  void _release(McpService owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    state = const McpServerState();
  }
}

@Riverpod(keepAlive: true)
McpService mcpService(Ref ref) {
  final service = McpService(
    ref.watch(diaryRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
    ref.watch(tagRepositoryProvider),
    ref.watch(moodInsightsRepositoryProvider),
    ref.watch(mcpServerStateProvider.notifier),
    ref.watch(embedIndexServiceProvider),
    ref.watch(heifDecoderProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
}

enum McpServerStatus { stopped, starting, running, failed }

enum McpServerFailure { portInUse, unknown }

@immutable
class McpServerState {
  const McpServerState({
    this.status = .stopped,
    this.port,
    this.endpoints = const [],
    this.failure,
  });

  final McpServerStatus status;
  final int? port;
  final List<Uri> endpoints;
  final McpServerFailure? failure;

  bool get running => status == .running;

  @override
  bool operator ==(Object other) =>
      other is McpServerState &&
      other.status == status &&
      other.port == port &&
      other.failure == failure &&
      listEquals(other.endpoints, endpoints);

  @override
  int get hashCode =>
      Object.hash(status, port, failure, Object.hashAll(endpoints));
}

/// Owns the local MCP endpoint, tool catalog and bearer token.
class McpService {
  McpService(
    this._diaries,
    this._categories,
    this._tags,
    this._insights,
    this._controller, [
    this._semantic,
    this._heifDecoder,
  ]) : _endpointFactory = null,
       _networkChanges = null;

  @visibleForTesting
  McpService.forTesting(
    this._diaries,
    this._categories,
    this._tags,
    this._insights,
    this._controller,
    this._endpointFactory,
    this._networkChanges,
  ) : _semantic = null,
      _heifDecoder = null;

  final DiaryRepository _diaries;
  final CategoryRepository _categories;
  final TagRepository _tags;
  final MoodInsightsRepository _insights;
  final EmbedIndexService? _semantic;
  final IHeifDecoder? _heifDecoder;
  final McpHttpEndpoint Function()? _endpointFactory;
  final Stream<Object?>? _networkChanges;
  final Lock _lock = Lock();

  final McpServerController _controller;
  bool _disposed = false;
  McpServerState get _state =>
      _disposed ? const McpServerState() : _controller._snapshot(this);
  set _state(McpServerState value) {
    if (!_disposed) _controller._publish(this, value);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _lock.synchronized(_teardown);
    _controller._release(this);
  }

  McpHttpEndpoint? _transport;
  StreamSubscription<Object?>? _networkSubscription;
  String? _token;

  bool get enabled => MoodiaryKVs.mcpEnabled.get() ?? false;

  /// The port to listen on; `MoodiaryKVs.mcpPort` supplies the default.
  static int get configuredPort => MoodiaryKVs.mcpPort.get()!;

  /// The LAN host clients would use, whether or not the server runs.
  Future<String?> lanHost() async {
    try {
      return await NetworkStatus.getDeviceIP();
    } catch (e, s) {
      logger.e('MCP could not read the LAN address', error: e, stackTrace: s);
      return null;
    }
  }

  static bool get allowLan => MoodiaryKVs.mcpAllowLan.get() ?? false;

  /// Restores the persisted switch after the first frame.
  Future<void> restore() => _lock.synchronized(_start);

  /// The settings switch: persist the flag and start right away.
  Future<void> enable() => _lock.synchronized(() async {
    MoodiaryKVs.mcpEnabled.set(true);
    await _start();
  });

  Future<void> disable() => _lock.synchronized(() async {
    MoodiaryKVs.mcpEnabled.set(false);
    await _stop();
  });

  /// Applies a port or LAN policy change, restarting a running server.
  Future<void> updateConfig({int? port, bool? lan}) =>
      _lock.synchronized(() async {
        final previous = _state;
        if (port != null) MoodiaryKVs.mcpPort.set(port);
        if (lan != null) MoodiaryKVs.mcpAllowLan.set(lan);
        if (previous.running) {
          await _stop();
          await _start();
        } else {
          _state = McpServerState(
            status: previous.status,
            port: configuredPort,
            failure: previous.failure,
          );
          if (enabled && previous.status == .failed) await _start();
        }
      });

  Future<void> _start() async {
    if (_disposed || !enabled || _state.running) return;
    _state = const McpServerState(status: .starting);
    try {
      final token = await _ensureToken();
      final version = await _appVersion();
      final transport =
          _endpointFactory?.call() ??
          McpHttpEndpoint(
            serverFactory: (iconUri) => buildMoodiaryServer(
              diaries: _diaries,
              categories: _categories,
              tags: _tags,
              insights: _insights,
              semantic: _semantic,
              heifDecoder: _heifDecoder,
              appVersion: version,
              iconUri: iconUri,
            ),
          );
      _transport = transport;
      transport.onEndpointsChanged = (endpoints) {
        if (_transport != transport || !_state.running) return;
        _state = McpServerState(
          status: .running,
          port: transport.port,
          endpoints: List.unmodifiable(endpoints),
        );
      };
      await transport.start(
        port: configuredPort,
        allowLan: allowLan,
        token: token,
      );
      _state = McpServerState(
        status: .running,
        port: transport.port,
        endpoints: List.unmodifiable(transport.endpoints),
      );
      if (allowLan) {
        _networkSubscription = (_networkChanges ?? NetworkStatus.changes)
            .listen((_) => unawaited(transport.refreshLanHosts()));
      }
      logger.i('MCP server listening on ${transport.endpoints.join(', ')}');
    } catch (e, s) {
      logger.e('MCP server failed to start', error: e, stackTrace: s);
      await _teardown();
      _state = McpServerState(
        status: .failed,
        port: configuredPort,
        failure: e is McpPortInUseException ? .portInUse : .unknown,
      );
    }
  }

  Future<void> stop() => _lock.synchronized(_stop);

  Future<void> _stop() async {
    if (_state.status == .stopped) return;
    await _teardown();
    _state = const McpServerState();
  }

  /// Rotates the bearer token; a running server is restarted to use it.
  Future<String> regenerateToken() => _lock.synchronized(() async {
    final wasRunning = _state.running;
    final token = await _generateToken();
    if (wasRunning) {
      await _stop();
      await _start();
    }
    return token;
  });

  Future<String> _generateToken() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    await MoodiarySecureKVs.mcpToken.set(token);
    _token = token;
    return token;
  }

  /// Returns the stored token, generating it on first use.
  Future<String> ensureToken() => _lock.synchronized(_ensureToken);

  Future<String> _ensureToken() async {
    final cached = _token;
    if (cached != null && cached.isNotEmpty) return cached;
    final stored = await MoodiarySecureKVs.mcpToken.get();
    if (stored != null && stored.isNotEmpty) return _token = stored;
    return _generateToken();
  }

  Future<void> _teardown() async {
    final transport = _transport;
    _transport = null;
    await _networkSubscription?.cancel();
    _networkSubscription = null;
    await _discard(transport);
  }

  Future<void> _discard(McpHttpEndpoint? transport) async {
    try {
      await transport?.stop();
    } catch (e, s) {
      logger.e('MCP transport stop failed', error: e, stackTrace: s);
    }
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
