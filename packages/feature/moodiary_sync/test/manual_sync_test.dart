import 'dart:async';
import 'dart:typed_data';

import 'package:fast_crypto/src/rust/frb_generated.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_sync/src/data/codec.dart';
import 'package:moodiary_sync/src/data/model/manifest.dart';
import 'package:moodiary_sync/src/data/remote_lease.dart';
import 'package:moodiary_sync/src/data/sync_key_manager.dart';
import 'package:moodiary_sync/src/presentation/widget/user_key_change_flow.dart';
import 'package:mui/mui.dart';

class _Backend extends Fake implements IRemoteSyncBackend {
  final keyfile = Completer<Uint8List?>();
  var queriedKeyfile = false;
  Object? readinessError;

  @override
  Future<bool> isReady() async {
    if (readinessError case final error?) throw error;
    return true;
  }

  @override
  Future<Uint8List?> readObject(String key) async {
    if (key == SyncKeys.manifestPath) {
      return Uint8List.fromList([...SyncCipher.magic.codeUnits, 0]);
    }
    queriedKeyfile = key == SyncKeys.keysPath;
    return keyfile.future;
  }
}

class _ManualBackend extends Fake implements IRemoteSyncBackend {
  Completer<Uint8List?>? manifestGate;
  final calls = <String>[];
  SyncException? manifestError;
  SyncException? keyfileError;
  Uint8List? manifestBytes;

  @override
  Future<bool> isReady() async {
    calls.add('ready');
    return true;
  }

  @override
  Future<Uint8List?> readObject(String key) async {
    calls.add('read $key');
    if (key == SyncKeys.manifestPath) {
      if (manifestGate case final gate?) return gate.future;
      if (manifestError case final error?) throw error;
      return manifestBytes;
    }
    if (key == SyncKeys.keysPath) {
      if (keyfileError case final error?) throw error;
      return null;
    }
    return null;
  }

  @override
  String? get persistentBackendId => null;
}

class _ManualController extends SyncController {
  int runs = 0;
  SyncHealth? healthAtRun;

  @override
  Future<SyncOutcome> run(
    SyncOperation operation,
    IRemoteSyncBackend backend,
    SyncDirection direction,
    SyncTrigger trigger,
  ) async {
    operation.checkActive();
    runs++;
    healthAtRun = state.health;
    return SyncOutcome(
      at: DateTime.now(),
      trigger: trigger,
      direction: direction,
      kind: .upToDate,
      elapsed: Duration.zero,
    );
  }
}

class _ClaimBackend extends Fake implements IRemoteSyncBackend {
  final objects = <String, Uint8List>{};
  final claim = Completer<void>();
  final conversion = Completer<void>();
  bool claiming = false;
  bool converting = false;

  @override
  String get persistentBackendId => 'webdav';

  @override
  String get displayName => persistentBackendId;

  @override
  Future<Uint8List?> readObject(String key) async {
    if (key == SyncKeys.manifestPath && !converting) {
      converting = true;
      await conversion.future;
    }
    return objects[key];
  }

  @override
  Future<void> writeObject(String key, Uint8List bytes) async {
    objects[key] = bytes;
  }

  @override
  Future<void> deleteObject(String key) async {
    objects.remove(key);
  }

  @override
  Future<ExclusiveCreate> tryCreateExclusive(
    String key,
    Uint8List bytes,
  ) async {
    if (key == SyncKeys.keysPath) {
      claiming = true;
      await claim.future;
    }
    if (objects.containsKey(key)) return .exists;
    objects[key] = bytes;
    return .created;
  }
}

class _Crypto extends Fake implements FastCryptoLibApi {
  @override
  Future<Uint8List> crateApiCryptoAesEncrypt({
    required List<int> key,
    required List<int> data,
  }) async => Uint8List.fromList(data.reversed.toList());

  @override
  Future<Uint8List> crateApiCryptoAesDecrypt({
    required List<int> key,
    required List<int> encryptedData,
  }) async => Uint8List.fromList(encryptedData.reversed.toList());
}

void main() {
  testWidgets(
    'a claimed key finishes cloud conversion after route navigation',
    (tester) async {
      KVStore.installForTesting(MemoryKVStorage());
      SecureKVStore.installForTesting(MemorySecureKVStorage());
      SyncKeyManager.resetForTest();
      RemoteLease.resetCasProbeCache();
      RemoteLease.readbackSettleDelay = Duration.zero;
      FastCryptoLib.initMock(api: _Crypto());
      addTearDown(() {
        FastCryptoLib.dispose();
        RemoteLease.readbackSettleDelay = null;
        RemoteLease.resetCasProbeCache();
        SyncKeyManager.resetForTest();
        SecureKVStore.resetForTesting();
        KVStore.resetForTesting();
      });
      SyncKeyManager.deriveKey = ({
        required salt,
        required passphrase,
        required mCostKib,
        required tCost,
        required pCost,
      }) async => List.filled(32, 1);
      final backend = _ClaimBackend();
      final manifest = SyncManifest.empty();
      backend.objects[SyncKeys.manifestPath] = await SyncCipher.plaintext
          .encode(manifest.toJson());
      final dek = List.filled(32, 2);
      final keyfile = await SyncKeyManager.wrapDek(
        dek: dek,
        passphrase: 'secret',
      );
      await SyncKeyManager.installKey(
        dek: dek,
        keyfile: keyfile,
        backendId: null,
        configured: {backend.persistentBackendId},
      );
      final logger = SyncLogger.memory();
      addTearDown(logger.dispose);
      final guard = SyncOperationGuard();
      addTearDown(guard.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncLoggerProvider.overrideWithValue(logger)],
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            builder: FlutterSmartDialog.init(),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            home: Consumer(
              builder: (ctx, widgetRef, _) {
                context = ctx;
                ref = widgetRef;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final repair = guard.tryWithOperation(
        (operation) => resolveDecryptedRemote(
          context: context,
          ref: ref,
          operation: operation,
          backend: backend,
          canPrompt: () => ModalRoute.of(context)?.isCurrent ?? false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.sync.keyRemoteDecryptedEncrypt));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'secret');
      await tester.tap(find.text(l10n.sync.keyContinue));
      await tester.pumpAndSettle();
      expect(backend.claiming, isTrue);
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const Text('Other route')),
      );
      await tester.pumpAndSettle();
      backend.claim.complete();
      await tester.pumpAndSettle();
      expect(backend.converting, isTrue);
      expect(find.text(l10n.sync.keyProcessing), findsNothing);
      expect(find.text('Other route'), findsOneWidget);
      expect(SyncKeyManager.pendingUploadBackends(), [
        backend.persistentBackendId,
      ]);
      expect(
        SyncKeyManager.hasKeyConflict(backend.persistentBackendId),
        isTrue,
      );
      backend.conversion.complete();
      await tester.pumpAndSettle();
      expect(await repair, isTrue);
      final converted = backend.objects[SyncKeys.manifestPath]!;
      expect(SyncCipher.isCipherText(converted), isTrue);
      expect(
        (await SyncCipher.withKey(dek).decode(converted))['version'],
        manifest.version,
      );
      expect(SyncKeyManager.pendingUploadBackends(), isEmpty);
      expect(
        SyncKeyManager.hasKeyConflict(backend.persistentBackendId),
        isFalse,
      );
    },
  );

  testWidgets(
    'interrupted re-encryption hides turn-off and resumes conversion without re-claiming',
    (tester) async {
      KVStore.installForTesting(MemoryKVStorage());
      SecureKVStore.installForTesting(MemorySecureKVStorage());
      SyncKeyManager.resetForTest();
      RemoteLease.resetCasProbeCache();
      RemoteLease.readbackSettleDelay = Duration.zero;
      FastCryptoLib.initMock(api: _Crypto());
      addTearDown(() {
        FastCryptoLib.dispose();
        RemoteLease.readbackSettleDelay = null;
        RemoteLease.resetCasProbeCache();
        SyncKeyManager.resetForTest();
        SecureKVStore.resetForTesting();
        KVStore.resetForTesting();
      });
      SyncKeyManager.deriveKey = ({
        required salt,
        required passphrase,
        required mCostKib,
        required tCost,
        required pCost,
      }) async => List.filled(32, 1);
      final backend = _ClaimBackend();
      final dek = List.filled(32, 2);
      final keyfile = await SyncKeyManager.wrapDek(
        dek: dek,
        passphrase: 'secret',
      );
      await SyncKeyManager.installKey(
        dek: dek,
        keyfile: keyfile,
        backendId: null,
        configured: {backend.persistentBackendId},
      );
      SyncKeyManager.markKeyConflict(backend.persistentBackendId);
      backend.objects[SyncKeys.keysPath] = keyfile.toBytes();
      final manifest = SyncManifest.empty();
      backend.objects[SyncKeys.manifestPath] = await SyncCipher.plaintext
          .encode(manifest.toJson());
      backend.conversion.complete();
      final logger = SyncLogger.memory();
      addTearDown(logger.dispose);
      final guard = SyncOperationGuard();
      addTearDown(guard.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncLoggerProvider.overrideWithValue(logger)],
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            builder: FlutterSmartDialog.init(),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            home: Consumer(
              builder: (ctx, widgetRef, _) {
                context = ctx;
                ref = widgetRef;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final repair = guard.tryWithOperation(
        (operation) => resolveDecryptedRemote(
          context: context,
          ref: ref,
          operation: operation,
          backend: backend,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sync.keyRemoteDecryptedTurnOff), findsNothing);
      await tester.tap(find.text(l10n.sync.keyRemoteDecryptedEncrypt));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'secret');
      await tester.tap(find.text(l10n.sync.keyContinue));
      await tester.pumpAndSettle();
      expect(backend.claiming, isFalse);
      expect(await repair, isTrue);
      expect(
        SyncCipher.isCipherText(backend.objects[SyncKeys.manifestPath]!),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'interrupted re-encryption aborts if the remote keyfile disappears before conversion',
    (tester) async {
      KVStore.installForTesting(MemoryKVStorage());
      SecureKVStore.installForTesting(MemorySecureKVStorage());
      SyncKeyManager.resetForTest();
      RemoteLease.resetCasProbeCache();
      RemoteLease.readbackSettleDelay = Duration.zero;
      FastCryptoLib.initMock(api: _Crypto());
      addTearDown(() {
        FastCryptoLib.dispose();
        RemoteLease.readbackSettleDelay = null;
        RemoteLease.resetCasProbeCache();
        SyncKeyManager.resetForTest();
        SecureKVStore.resetForTesting();
        KVStore.resetForTesting();
      });
      SyncKeyManager.deriveKey = ({
        required salt,
        required passphrase,
        required mCostKib,
        required tCost,
        required pCost,
      }) async => List.filled(32, 1);
      final backend = _ClaimBackend();
      final dek = List.filled(32, 2);
      final keyfile = await SyncKeyManager.wrapDek(
        dek: dek,
        passphrase: 'secret',
      );
      await SyncKeyManager.installKey(
        dek: dek,
        keyfile: keyfile,
        backendId: null,
        configured: {backend.persistentBackendId},
      );
      SyncKeyManager.markKeyConflict(backend.persistentBackendId);
      backend.objects[SyncKeys.keysPath] = keyfile.toBytes();
      final manifest = SyncManifest.empty();
      backend.objects[SyncKeys.manifestPath] = await SyncCipher.plaintext
          .encode(manifest.toJson());
      backend.conversion.complete();
      final logger = SyncLogger.memory();
      addTearDown(logger.dispose);
      final guard = SyncOperationGuard();
      addTearDown(guard.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncLoggerProvider.overrideWithValue(logger)],
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            builder: FlutterSmartDialog.init(),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            home: Consumer(
              builder: (ctx, widgetRef, _) {
                context = ctx;
                ref = widgetRef;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      final repair = guard.tryWithOperation(
        (operation) => resolveDecryptedRemote(
          context: context,
          ref: ref,
          operation: operation,
          backend: backend,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.sync.keyRemoteDecryptedEncrypt));
      await tester.pumpAndSettle();
      backend.objects.remove(SyncKeys.keysPath);
      await tester.enterText(find.byType(EditableText), 'secret');
      await tester.tap(find.text(l10n.sync.keyContinue));
      await tester.pumpAndSettle();
      expect(await repair, isFalse);
      expect(
        SyncCipher.isCipherText(backend.objects[SyncKeys.manifestPath]!),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'distinguishes contention, hidden or dismissed prompts, and preparation errors',
    (tester) async {
      SecureKVStore.installForTesting(MemorySecureKVStorage());
      SyncKeyManager.resetForTest();
      addTearDown(SecureKVStore.resetForTesting);
      addTearDown(SyncKeyManager.resetForTest);
      late WidgetRef ref;
      late BuildContext context;
      final backend = _Backend();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            activeSyncBackendProvider.overrideWithValue(backend),
            configuredCloudBackendIdsProvider.overrideWith((_) async => {}),
          ],
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            builder: FlutterSmartDialog.init(),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            home: Consumer(
              builder: (ctx, widgetRef, _) {
                context = ctx;
                ref = widgetRef;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      var visible = true;
      Future<ManualSyncResult> trigger() => triggerManualSync(
        context: context,
        ref: ref,
        canPrompt: () => visible,
        isOnline: () async => true,
      );
      final guard = ref.read(syncOperationGuardProvider);
      final lock = guard.tryAcquire()!;
      expect(await trigger(), isA<ManualSyncBusy>());
      lock.release();
      visible = false;
      expect(await trigger(), isA<ManualSyncCancelled>());
      visible = true;
      final hidden = trigger();
      await tester.pump();
      expect(backend.queriedKeyfile, isTrue);
      visible = false;
      backend.keyfile.complete(null);
      await tester.pumpAndSettle();
      expect(find.text(l10n.sync.keyMissingTitle), findsNothing);
      expect(await hidden, isA<ManualSyncCancelled>());

      visible = true;
      final dismissed = trigger();
      await tester.pumpAndSettle();
      expect(find.text(l10n.sync.keyMissingTitle), findsOneWidget);
      Navigator.of(context).pop(false);
      await tester.pumpAndSettle();
      expect(await dismissed, isA<ManualSyncCancelled>());
      final error = StateError('offline');
      backend.readinessError = error;
      expect(
        await trigger(),
        isA<ManualSyncFailed>().having(
          (result) => result.error,
          'error',
          same(error),
        ),
      );
      expect(guard.isBusy, isFalse);
    },
  );

  group('manual sync reachability', () {
    late WidgetRef ref;
    late BuildContext context;
    late _ManualBackend backend;
    late _ManualController controller;
    late SyncOperationGuard guard;

    Future<void> mount(WidgetTester tester) async {
      backend = _ManualBackend();
      controller = _ManualController();
      final logger = SyncLogger.memory();
      addTearDown(logger.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSyncBackendProvider.overrideWithValue(backend),
            configuredCloudBackendIdsProvider.overrideWith((_) async => {}),
            syncControllerProvider.overrideWith(() => controller),
            syncLoggerProvider.overrideWithValue(logger),
            syncOnlineCheckProvider.overrideWithValue(() async => true),
          ],
          child: Consumer(
            builder: (ctx, widgetRef, _) {
              context = ctx;
              ref = widgetRef;
              return const SizedBox();
            },
          ),
        ),
      );
      guard = ref.read(syncOperationGuardProvider);
      ref.read(syncControllerProvider.notifier);
    }

    Future<ManualSyncResult> trigger({
      Future<bool> Function()? isOnline,
      Duration timeout = const Duration(seconds: 3),
    }) => triggerManualSync(
      context: context,
      ref: ref,
      isOnline: isOnline,
      unreachableProbeTimeout: timeout,
    );

    testWidgets('offline completes without a lock or backend calls', (
      tester,
    ) async {
      await mount(tester);
      final busyEvents = <bool>[];
      final subscription = guard.changes.listen(busyEvents.add);
      addTearDown(subscription.cancel);
      final start = tester.binding.clock.now();
      expect(
        await trigger(isOnline: () async => false),
        isA<ManualSyncUnreachable>(),
      );
      expect(tester.binding.clock.now(), start);
      expect(busyEvents, isEmpty);
      expect(backend.calls, isEmpty);
      expect(controller.runs, 0);
      expect(ref.read(syncControllerProvider).health, SyncHealth.unreachable);
    });

    testWidgets('unreachable retry times out on manifest GET without HEAD', (
      tester,
    ) async {
      await mount(tester);
      controller.markUnreachable();
      final gate = backend.manifestGate = Completer<Uint8List?>();
      const timeout = Duration(milliseconds: 30);
      ManualSyncResult? result;
      final pending = trigger(timeout: timeout).then((value) => result = value);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 29));
      expect(result, isNull);
      expect(guard.isBusy, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await pending, isA<ManualSyncUnreachable>());
      expect(guard.isBusy, isFalse);
      gate.complete(null);
      await tester.pump();
      expect(backend.calls, ['ready', 'read ${SyncKeys.manifestPath}']);
      expect(controller.runs, 0);
      expect(ref.read(syncControllerProvider).health, SyncHealth.unreachable);
    });

    testWidgets(
      'unreachable retry recovers through manifest GET without HEAD',
      (tester) async {
        await mount(tester);
        controller.markUnreachable();
        expect(await trigger(), isA<ManualSyncCompleted>());
        expect(backend.calls, ['ready', 'read ${SyncKeys.manifestPath}']);
        expect(controller.runs, 1);
      },
    );

    testWidgets('a manifest network error stops after one read', (
      tester,
    ) async {
      await mount(tester);
      backend.manifestError = const SyncException('offline', kind: .network);
      expect(await trigger(), isA<ManualSyncUnreachable>());
      expect(backend.calls, ['ready', 'read ${SyncKeys.manifestPath}']);
      expect(controller.runs, 0);
      expect(guard.isBusy, isFalse);
      expect(ref.read(syncControllerProvider).health, SyncHealth.unreachable);
    });

    testWidgets(
      'a keyfile network error reports unreachable and updates health',
      (tester) async {
        SecureKVStore.installForTesting(MemorySecureKVStorage());
        SyncKeyManager.resetForTest();
        addTearDown(SecureKVStore.resetForTesting);
        addTearDown(SyncKeyManager.resetForTest);
        await mount(tester);
        backend.manifestBytes = Uint8List.fromList([
          ...SyncCipher.magic.codeUnits,
          0,
        ]);
        backend.keyfileError = const SyncException('offline', kind: .network);
        expect(await trigger(), isA<ManualSyncUnreachable>());
        expect(controller.runs, 0);
        expect(ref.read(syncControllerProvider).health, SyncHealth.unreachable);
      },
    );
  });
}
