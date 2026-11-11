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

import '../export/diary_image_renderer.dart';
import '../server/mcp_server.dart';
import '../tools/register_moodiary_tools.dart';
import '../transport/io_mcp_transport.dart';
import '../transport/transport.dart';

enum McpServerStatus { stopped, starting, running, failed }

@immutable
class McpServerState {
  const McpServerState({
    this.status = .stopped,
    this.port,
    this.endpoints = const [],
    this.error,
  });

  final McpServerStatus status;
  final int? port;
  final List<Uri> endpoints;
  final String? error;

  bool get running => status == .running;

  @override
  bool operator ==(Object other) =>
      other is McpServerState &&
      other.status == status &&
      other.port == port &&
      other.error == error &&
      listEquals(other.endpoints, endpoints);

  @override
  int get hashCode =>
      Object.hash(status, port, error, Object.hashAll(endpoints));
}

/// Owns the local MCP endpoint: builds the tool catalog, starts and stops the
/// transport, keeps the bearer token and mirrors database changes to clients.
///
/// The bearer token is optional on a loopback only server and mandatory as soon
/// as LAN access is on; see [requireToken].
///
/// The service is a process level singleton and never touches the UI; the
/// settings page observes [state] and calls [enable] / [disable] /
/// [updateConfig].
@lazySingleton
class McpService {
  McpService(this._diaries, this._categories, this._insights);

  /// The native long-image renderer, installed by the app composition root.
  ///
  /// Rendering needs `moodiary_export`, which this feature package may not
  /// import, so the adapter comes in through this replaceable holder instead of
  /// the constructor (which would force injectable codegen for a value the
  /// container cannot provide). Tests replace it too; `null` makes
  /// `render_diary_image` answer with a "not available in this build" error.
  ///
  /// The value is read when a server instance is built, so install it before
  /// [start] to take effect for that instance.
  static DiaryImageRenderer? imageRenderer;

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

  /// Bumped by every [stop]; a [start] compares it after each of its awaits.
  ///
  /// A start that is still building a transport when the user locks the app or
  /// switches the server off cannot be seen by [stop] yet (its transport is
  /// still local), so it has to notice the bump itself: it closes what it built
  /// and leaves [state] alone instead of publishing `running` after the stop.
  int _generation = 0;

  /// A [start] that arrived while another one was still coming up.
  ///
  /// It is replayed after the running one settles, never dropped: the lock
  /// observer has no second chance to ask for the endpoint, and the replay is
  /// free when the running start reaches `running` (that makes [start] return
  /// immediately).
  bool _startPending = false;

  String? get token => _token;

  bool get enabled => MoodiaryKVs.mcpEnabled.get() ?? false;

  /// The port to listen on; `MoodiaryKVs.mcpPort` supplies the default.
  static int get configuredPort => MoodiaryKVs.mcpPort.get()!;

  static bool get allowLan => MoodiaryKVs.mcpAllowLan.get() ?? false;

  /// Whether a client has to present the bearer token.
  ///
  /// LAN access always requires it: the switch only applies to a loopback only
  /// server, so a configuration that publishes the diary on the network without
  /// a shared secret cannot be expressed.
  static bool get requireToken =>
      allowLan || (MoodiaryKVs.mcpRequireToken.get() ?? true);

  /// Starts the server when the user turned the switch on; the app lock
  /// observer calls this after the first frame and whenever the lock screen goes
  /// away, so a previously enabled server comes back after a restart.
  Future<void> restore() async {
    if (!enabled) return;
    await start();
  }

  /// The settings switch: persist the flag and start right away.
  Future<void> enable() async {
    MoodiaryKVs.mcpEnabled.set(true);
    await start();
  }

  Future<void> disable() async {
    MoodiaryKVs.mcpEnabled.set(false);
    await stop();
  }

  /// Applies a new port, LAN policy or token policy; restarts when the server is
  /// running, because none of the three can change under a live socket.
  ///
  /// `requireToken: false` is persisted even while [allowLan] is on, but it has
  /// no effect there: [requireToken] keeps answering `true` until the LAN switch
  /// goes off again.
  Future<void> updateConfig({int? port, bool? lan, bool? requireToken}) async {
    final wasRunning = state.value.running;
    if (port != null) MoodiaryKVs.mcpPort.set(port);
    if (lan != null) MoodiaryKVs.mcpAllowLan.set(lan);
    if (requireToken != null) MoodiaryKVs.mcpRequireToken.set(requireToken);
    if (!wasRunning) return;
    await stop();
    await start();
  }

  Future<void> start() async {
    if (_busy) {
      // Another start is still coming up; replay this request when it settles
      // instead of dropping it (see [_startPending]).
      _startPending = true;
      return;
    }
    if (state.value.status == .running) return;
    _busy = true;
    final generation = _generation;
    final needsToken = requireToken;
    state.value = const McpServerState(status: .starting);
    McpServer? server;
    IoMcpTransport? transport;
    try {
      // A loopback only server may run without a token; nothing is generated or
      // read in that case, so the stored token keeps existing for the moment the
      // user switches authentication back on.
      final token = needsToken ? await ensureToken() : '';
      if (generation != _generation) return;
      final version = await _appVersion();
      if (generation != _generation) return;
      final startingServer = McpServer(
        registry: buildMoodiaryRegistry(
          diaries: _diaries,
          categories: _categories,
          insights: _insights,
          appVersion: version,
          imageRenderer: imageRenderer,
        ),
        serverVersion: version,
      );
      server = startingServer;
      final startingTransport = IoMcpTransport();
      transport = startingTransport;
      await startingTransport.start(
        McpTransportConfig(
          port: configuredPort,
          allowLan: allowLan,
          token: token,
          requireToken: needsToken,
        ),
        startingServer,
      );
      // A stop cannot see this transport yet: it is still local to this call, so
      // a stop that landed while the socket was binding is honoured here.
      if (generation != _generation) return;
      _server = startingServer;
      _transport = startingTransport;
      // The fields own both objects from here, so a failure below tears down the
      // published instance instead of this local pair.
      server = null;
      transport = null;
      _listenForChanges(startingServer);
      state.value = McpServerState(
        status: .running,
        port: startingTransport.port,
        endpoints: startingTransport.endpoints,
      );
      logger.i(
        'MCP server listening on ${startingTransport.endpoints.join(', ')}',
      );
    } catch (e, s) {
      logger.e('MCP server failed to start', error: e, stackTrace: s);
      // A stop during the failed start owns the state; publishing `failed` would
      // overwrite its `stopped`.
      if (generation == _generation) {
        await _teardown();
        state.value = McpServerState(status: .failed, error: '$e');
      }
    } finally {
      // Anything still local was never published, because a stop invalidated
      // this start (or it failed): close it without touching [state].
      await _discard(transport, server);
      _busy = false;
      if (_startPending) {
        _startPending = false;
        unawaited(start());
      }
    }
  }

  /// Stops the server and invalidates any [start] that is still coming up.
  ///
  /// The generation bump comes first, so a start that is already awaiting its
  /// transport can no longer publish `running`: it notices the new generation,
  /// closes the transport it built itself and leaves the state at `stopped`.
  Future<void> stop() async {
    _generation++;
    _startPending = false;
    if (state.value.status == .stopped) return;
    await _teardown();
    state.value = const McpServerState();
  }

  /// Rotates the bearer token; a running server is restarted to use it.
  ///
  /// Rotating is allowed while authentication is off: the new secret is stored
  /// and takes effect as soon as [requireToken] turns back on.
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

  /// The token the running server demands, or the stored one, generating it on
  /// first use.
  ///
  /// The settings page calls this to display the token, which is why it keeps
  /// returning a secret even while a token-less server is running: the user must
  /// be able to copy it before turning authentication back on. [start] only
  /// calls it when [requireToken] is `true`.
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
    await _discard(transport, server);
  }

  /// Stops a transport and disposes its server without touching [state].
  ///
  /// [stop] uses it for the published instance; a [start] that a [stop]
  /// invalidated uses it for the one it built but never published.
  Future<void> _discard(McpTransport? transport, McpServer? server) async {
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

  Future<String> _appVersion() async {
    try {
      return (await AppInfo.getPackageInfo()).version;
    } catch (e) {
      logger.d('MCP: package info unavailable ($e)');
      return '0.0.0';
    }
  }
}
