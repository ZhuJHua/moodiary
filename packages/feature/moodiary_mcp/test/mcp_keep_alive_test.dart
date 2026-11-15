import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

class _McpService extends Fake implements McpService {
  @override
  final state = ValueNotifier(const McpServerState(status: .running));

  int disableCalls = 0;

  @override
  Future<void> disable() async {
    disableCalls++;
    state.value = const McpServerState();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  for (final permission in KeepAlivePermission.values) {
    test('${permission.name} request failures reach the caller', () async {
      final service = _McpService();
      addTearDown(service.state.dispose);
      final keepAlive = McpKeepAlive(service);
      final method = switch (permission) {
        .batteryOptimization => 'requestExemption',
        .notifications => 'requestNotifications',
      };
      final channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveApi.$method',
        BackgroundKeepAliveApi.pigeonChannelCodec,
      );
      binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        channel,
        (_) async => <Object?>['denied', 'Settings unavailable', null],
      );
      addTearDown(() {
        BackgroundKeepAliveEvents.setUp(null);
        binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
          channel,
          null,
        );
      });

      await expectLater(
        keepAlive.request(permission),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'denied',
          ),
        ),
      );
    });
  }

  test('app settings failures reach the caller', () async {
    final service = _McpService();
    addTearDown(service.state.dispose);
    final keepAlive = McpKeepAlive(service);
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveApi.openAppSettings',
      BackgroundKeepAliveApi.pigeonChannelCodec,
    );
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      channel,
      (_) async => <Object?>['unavailable', 'Settings unavailable', null],
    );
    addTearDown(() {
      BackgroundKeepAliveEvents.setUp(null);
      binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        channel,
        null,
      );
    });

    await expectLater(
      keepAlive.openAppSettings(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'unavailable',
        ),
      ),
    );
  });

  test('notification Stop disables MCP and stops native keep-alive', () async {
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    addTearDown(getIt.reset);
    final service = _McpService();
    addTearDown(service.state.dispose);
    final nativeCalls = <List<Object?>>[];
    final nativeStopped = Completer<void>();
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveApi.setKeepAlive',
      BackgroundKeepAliveApi.pigeonChannelCodec,
    );
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler(channel, (
      message,
    ) async {
      final arguments = message! as List<Object?>;
      nativeCalls.add(arguments);
      if (arguments.first == false) nativeStopped.complete();
      return <Object?>[null];
    });
    addTearDown(() {
      BackgroundKeepAliveEvents.setUp(null);
      binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        channel,
        null,
      );
    });
    final keepAlive = McpKeepAlive(service);
    await keepAlive.restore();

    final reply = Completer<Object?>();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveEvents.onStopRequested',
      null,
      (data) => reply.complete(
        BackgroundKeepAliveEvents.pigeonChannelCodec.decodeMessage(data),
      ),
    );

    expect(await reply.future, isEmpty);
    await nativeStopped.future;
    expect(service.disableCalls, 1);
    expect(service.state.value.status, McpServerStatus.stopped);
    expect(nativeCalls.map((arguments) => arguments.first), [true, false]);
    expect(nativeCalls.first, [
      true,
      l10n.app.mcpKeepAliveNotificationText,
      l10n.app.mcpKeepAliveStop,
    ]);
  });
}
