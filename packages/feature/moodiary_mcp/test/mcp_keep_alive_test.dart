import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_native/moodiary_native.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
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

class _NotificationPermission implements NotificationPermission {
  bool enabled = false;
  bool fail = false;
  int settingsCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<bool> request() async {
    if (fail) throw PlatformException(code: 'denied');
    return enabled;
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  for (final permission in KeepAlivePermission.values) {
    test('${permission.name} request failures reach the caller', () async {
      final service = _McpService();
      addTearDown(service.state.dispose);
      final notifications = _NotificationPermission()..fail = true;
      final keepAlive = McpKeepAlive(service, notifications);
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveApi.requestExemption',
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
    final keepAlive = McpKeepAlive(service, _NotificationPermission());
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
    final keepAlive = McpKeepAlive(service, _NotificationPermission());
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

  test(
    'notification request opens settings only when still disabled',
    () async {
      final service = _McpService();
      final notifications = _NotificationPermission();
      final keepAlive = McpKeepAlive(service, notifications);
      addTearDown(service.state.dispose);
      addTearDown(() => BackgroundKeepAliveEvents.setUp(null));
      await keepAlive.request(.notifications);
      expect(notifications.settingsCalls, 1);
      notifications.enabled = true;
      await keepAlive.request(.notifications);
      expect(notifications.settingsCalls, 1);
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.moodiary_native.BackgroundKeepAliveApi.isExempt',
        BackgroundKeepAliveApi.pigeonChannelCodec,
      );
      binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        channel,
        (_) async => [true],
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
          channel,
          null,
        ),
      );
      final statuses = await keepAlive.statuses();
      expect(statuses.every((status) => status.granted), isTrue);
      notifications.enabled = false;
      expect((await keepAlive.statuses()).last.granted, isFalse);
    },
  );
}
