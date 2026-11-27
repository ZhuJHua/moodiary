import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/home/diary_home_page.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:mui/mui.dart';

class _Diaries extends Fake implements DiaryRepository {
  final events = StreamController<DiaryEvent>.broadcast(sync: true);

  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;

  @override
  Future<List<Diary>> getDiaryByCategory({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    int? offset,
    int? limit,
    DiarySort sort = .timeDesc,
  }) async => [];

  @override
  Future<Map<DateTime, int>> diaryCountByMonth({
    String? categoryId,
    bool uncategorized = false,
    String? tagName,
    DiarySort sort = .timeDesc,
  }) async => {};
}

class _Backend extends Fake implements IRemoteSyncBackend {
  @override
  Future<bool> isReady() async => true;

  @override
  Future<Uint8List?> readObject(String key) async => null;

  @override
  String? get persistentBackendId => null;
}

class _Sync extends SyncController {
  final pending = Completer<SyncOutcome>();
  Completer<void>? beforePrepare;
  int runs = 0;

  @override
  Future<SyncOutcome?> sync({
    Future<bool> Function(SyncOperation, IRemoteSyncBackend)? prepare,
  }) async {
    if (beforePrepare case final gate?) {
      await gate.future;
      return ref
          .read(syncOperationGuardProvider)
          .tryWithOperation<SyncOutcome?>((operation) async {
            final backend = ref.read(activeSyncBackendProvider);
            if (prepare != null && !await prepare(operation, backend)) {
              return null;
            }
            return run(operation, backend, .sync, .manual);
          });
    }
    return super.sync(prepare: prepare);
  }

  @override
  Future<SyncOutcome> run(
    SyncOperation operation,
    IRemoteSyncBackend backend,
    SyncDirection direction,
    SyncTrigger trigger,
  ) {
    runs++;
    return pending.future;
  }
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required _Diaries diaries,
  required _Sync sync,
  required _Backend backend,
  required Future<bool> Function() ready,
  bool online = true,
  WidgetBuilder? home,
}) => tester.pumpWidget(
  ProviderScope(
    retry: (_, _) => null,
    overrides: [
      diaryRepositoryProvider.overrideWithValue(diaries),
      orderedCategoriesProvider.overrideWithValue(const AsyncData([])),
      orderedPlacesProvider.overrideWithValue(const AsyncData([])),
      categoryDiaryCountsProvider.overrideWith(
        (_) async => (byCategory: <String, int>{}, total: 0),
      ),
      secretKvProvider(MoodiarySecureKVs.qweatherKey)
          .overrideWith((_) async => null),
      tagCatalogProvider.overrideWithValue(
        const AsyncData((byId: {}, usage: [])),
      ),
      syncBackendReadyProvider.overrideWith((_) => ready()),
      activeSyncBackendProvider.overrideWithValue(backend),
      configuredCloudBackendIdsProvider.overrideWith((_) async => {}),
      syncControllerProvider.overrideWith(() => sync),
      syncOnlineCheckProvider.overrideWithValue(() async => online),
      syncLoggerProvider.overrideWith((ref) {
        final logger = SyncLogger.memory();
        ref.onDispose(() => unawaited(logger.dispose()));
        return logger;
      }),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildMuiTheme(brightness: .light),
        localizationsDelegates: const [
          ...GlobalMaterialLocalizations.delegates,
          GlobalMuiLocalizations.delegate,
        ],
        supportedLocales: AppLocaleUtils.supportedLocales,
        home: home == null ? const DiaryHomePage() : Builder(builder: home),
      ),
    ),
  ),
);

void main() {
  test('selected tag follows surviving ids and prefers its current name', () {
    final first = Tag.create('Trip');
    final second = Tag.create('Trip');
    final previous = {first.id: first, second.id: second};
    final renamed = second.copyWith(name: 'Travel');
    final deleted = first.copyWith(deleted: true);
    final unrelated = Tag.create('Other');
    String? resolve(List<Tag> current) => resolveSelectedTagName(
      'Trip',
      previous,
      {for (final tag in current) tag.id: tag},
    );

    expect(resolve([first, renamed]), 'Trip');
    expect(resolve([deleted, renamed]), 'Travel');
    expect(resolve([deleted, unrelated]), isNull);
  });

  for (final mode in ViewModeType.values) {
    testWidgets('${mode.name} can sync its first diary and pull again', (
      tester,
    ) async {
      KVStore.installForTesting(MemoryKVStorage());
      addTearDown(KVStore.resetForTesting);
      MoodiaryKVs.homeViewMode.set(mode.number);
      setupPluralResolvers();
      final diaries = _Diaries();
      addTearDown(diaries.events.close);
      final sync = _Sync();
      var ready = Completer<bool>();
      await _pumpHome(
        tester,
        diaries: diaries,
        sync: sync,
        backend: _Backend(),
        ready: () => ready.future,
      );
      await tester.pumpAndSettle();
      final refresh = find.byType(MRefresh);
      final state = tester.state(refresh);
      final context = tester.element(refresh);
      final container = ProviderScope.containerOf(context, listen: false);
      expect(tester.widget<MRefresh>(refresh).onRefresh, isNull);
      ready.complete(false);
      await tester.pumpAndSettle();
      expect(tester.widget<MRefresh>(refresh).onRefresh, isNull);
      ready = Completer<bool>()..complete(true);
      container.invalidate(syncBackendReadyProvider);
      await tester.pumpAndSettle();
      expect(find.text(l10n.diary.tabViewEmpty), findsOneWidget);
      Future<void> pull() async {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
      }

      await pull();
      expect(sync.runs, 1);
      expect(tester.widget<MRefresh>(refresh).refreshEnabled, isFalse);
      final diary = Diary.empty(type: .markdown).copyWith(title: 'First diary');
      diaries.events.add(DiaryEvent.created(diary, fromSync: true));
      await tester.pump();
      expect(tester.state(refresh), same(state));
      expect(find.byKey(ValueKey(diary.id)), findsOneWidget);
      expect(find.text(l10n.sync.statusRunning), findsOneWidget);
      sync.pending.complete(
        SyncOutcome(
          at: DateTime(2026),
          trigger: .manual,
          direction: .sync,
          kind: .changed,
          elapsed: Duration.zero,
          report: const SyncReport(
            elapsed: Duration.zero,
            pulled: SyncCounts(diaries: 1),
            pushed: SyncCounts(tags: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.sync.pullSyncedCount(count: 2)), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 851));
      await tester.pumpAndSettle();
      await pull();
      expect(sync.runs, 2);
      await tester.pump(const Duration(milliseconds: 851));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('offline pull shows unable to connect without starting sync', (
    tester,
  ) async {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    final diaries = _Diaries();
    addTearDown(diaries.events.close);
    final sync = _Sync();
    await _pumpHome(
      tester,
      diaries: diaries,
      sync: sync,
      backend: _Backend(),
      ready: () async => true,
      online: false,
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text(l10n.sync.pullUnreachable), findsOneWidget);
    expect(sync.runs, 0);
    await tester.pump(const Duration(milliseconds: 851));
    await tester.pumpAndSettle();
  });

  testWidgets('tab switch before rebuild cancels pending pull-to-sync prompt', (
    tester,
  ) async {
    KVStore.installForTesting(MemoryKVStorage());
    addTearDown(KVStore.resetForTesting);
    final diaries = _Diaries();
    addTearDown(diaries.events.close);
    final gate = Completer<void>();
    final sync = _Sync()..beforePrepare = gate;
    var active = true;
    var tabBuilds = 0;
    await _pumpHome(
      tester,
      diaries: diaries,
      sync: sync,
      backend: _Backend(),
      ready: () async => true,
      home: (_) => StatefulBuilder(
        builder: (context, setState) {
          tabBuilds++;
          return Stack(
            children: [
              DiaryHomePage(isActiveTab: () => active),
              Positioned(
                right: 0,
                bottom: 0,
                child: TextButton(
                  onPressed: () => setState(() => active = false),
                  child: const Text('Switch tab'),
                ),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final outcome = tester.widget<MRefresh>(find.byType(MRefresh)).onRefresh!();
    var completed = false;
    unawaited(outcome.then((_) => completed = true));
    await tester.pump();
    final buildsBeforeTap = tabBuilds;
    await tester.tap(find.text('Switch tab'));
    gate.complete();
    await tester.idle();
    expect(tabBuilds, buildsBeforeTap);
    expect(completed, isTrue);
    await tester.pumpAndSettle();
    expect(await outcome, isNull);
    expect(sync.runs, 0);
    expect(tabBuilds, greaterThan(buildsBeforeTap));
  });
}
