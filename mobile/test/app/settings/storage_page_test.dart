// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_page.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:mui/mui.dart';

void main() {
  late Directory root;
  setUpAll(() {
    setupPluralResolvers();
    root = Directory.systemTemp.createTempSync('storage-page-');
    PlatformService.get().applicationCachePath = root.path;
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  final progress = StorageScanProgress(
    bytes: {for (final area in StorageArea.values) area: 1024},
    done: StorageArea.values.toSet(),
    area: .other,
    files: 11,
    reclaimableCacheBytes: 1024,
  );

  Future<ProviderContainer> show(
    WidgetTester tester, {
    ReclaimKind kind = .cache,
    bool loading = false,
    bool busy = false,
    bool cleaned = false,
    Future<List<StrayModelFile>> Function()? models,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          storageUsageProvider.overrideWith(
            (ref) => Stream.value(
              StorageScanProgress(
                bytes: progress.bytes,
                done: loading ? {} : progress.done,
                area: progress.area,
                files: progress.files,
                reclaimableCacheBytes: kind == .cache ? 1024 : 0,
              ),
            ),
          ),
          storageStrayModelsProvider.overrideWith(
            (ref) =>
                models?.call() ??
                Future.value([
                  if (kind == .retiredMood)
                    const StrayModelFile(
                      path: '/retired.onnx',
                      bytes: 1024,
                      kind: .retiredMood,
                    ),
                ]),
          ),
          storageOrphanMediaProvider.overrideWith(
            (ref) async => StorageOrphanMedia(
              report: MediaCleanupReport(
                paths: [],
                bytes: kind == .orphan ? 1024 : 0,
              ),
              counts: kind == .orphan ? {.image: 1} : {},
              areaBytes: kind == .orphan ? {.image: 1024} : {},
            ),
          ),
          storageLegacyBackupsProvider.overrideWith(
            (ref) async => StorageLegacyBackups(
              files: [],
              bytes: kind == .legacy ? 1024 : 0,
            ),
          ),
          storageSyncBusyProvider.overrideWith((ref) => busy),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildMuiTheme(brightness: .light),
            locale: const Locale('zh'),
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            builder: (context, child) => MaterialUiCompatibilityBridge(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            home: const StoragePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StoragePage)),
    );
    if (cleaned) {
      await tester.runAsync(
        () => container.read(storageSelectionProvider.notifier).clean(),
      );
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('reclaim selection uses a trailing checkbox and toggles totals', (
    tester,
  ) async {
    await show(tester);
    final tile = tester.widget<SettingCheckboxListTile>(
      find.byType(SettingCheckboxListTile),
    );
    expect(tile.title, '缓存');
    expect(tile.subtitle, '1.00 KB');
    expect(tile.value, isTrue);
    await tester.tap(
      find.descendant(
        of: find.byType(SettingCheckboxListTile),
        matching: find.text('缓存'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SettingCheckboxListTile>(find.byType(SettingCheckboxListTile))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '未选择'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (kind, loading, busy, cleaned, subtitle)
      in <(ReclaimKind, bool, bool, bool, String)>[
        (.orphan, false, false, false, '1.00 KB · 1 张照片 · 删除后无法恢复'),
        (.retiredMood, false, false, false, '1.00 KB · 已不再使用'),
        (.cache, true, false, false, '统计中'),
        (.cache, false, false, true, '已清理'),
        (.cache, false, true, false, '同步中'),
      ]) {
    testWidgets('reclaim subtitle: $subtitle', (tester) async {
      await show(
        tester,
        kind: kind,
        loading: loading,
        busy: busy,
        cleaned: cleaned,
      );
      final tile = tester.widget<SettingCheckboxListTile>(
        find.byType(SettingCheckboxListTile),
      );
      expect(tile.subtitle, subtitle);
      expect(tile.onChanged == null, loading || busy || cleaned);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'categories use an untitled mui group with chevrons only for links',
    (tester) async {
      await show(tester);
      final group = find.byWidgetPredicate(
        (widget) => widget is MSliverSettingGroup && widget.title == null,
      );
      expect(group, findsOneWidget);
      final tiles = tester
          .widgetList<SettingListTile>(
            find.descendant(of: group, matching: find.byType(SettingListTile)),
          )
          .toList();
      expect(tiles, hasLength(7));
      expect(
        tiles.where((tile) => tile.onTap != null).map((tile) => tile.title),
        ['AI 模型', '媒体', '字体'],
      );
      expect(tiles[2].subtitle, '可清理 1.00 KB');
      expect(
        find.descendant(
          of: group,
          matching: find.byIcon(LucideIcons.chevronRight),
        ),
        findsNWidgets(3),
      );
      // 总览是同组第一行：7 个分类 + 总览 = 8 行，7 条分隔线
      expect(
        find.descendant(of: group, matching: find.byType(MSettingDivider)),
        findsNWidgets(7),
      );
      for (final tile in tiles.where((tile) => tile.onTap == null)) {
        expect(tile.trailing, isNot(isA<Row>()));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'safe selection cleans immediately without a confirmation sheet',
    (tester) async {
      final cache = File('${root.path}/cache.bin')
        ..writeAsBytesSync(List.filled(1024, 0));
      final container = await show(tester);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '清理 1.00 KB'),
      );
      await tester.runAsync(() async {
        final finished = Completer<void>();
        final subscription = container.listen(storageSelectionProvider, (
          _,
          next,
        ) {
          if (next.cleaned.contains('cache') && !next.cleaning) {
            finished.complete();
          }
        });
        try {
          button.onPressed!();
          await finished.future.timeout(const Duration(seconds: 10));
        } finally {
          subscription.close();
        }
      });
      await tester.pumpAndSettle();
      expect(cache.existsSync(), isFalse);
      expect(container.read(storageSelectionProvider).cleaned, {'cache'});
      expect(find.byType(MSheetScaffold<bool>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('careful selection opens a sheet, cancel keeps files', (
    tester,
  ) async {
    final container = await show(tester, kind: .legacy);
    await tester.tap(find.byType(SettingCheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '清理 1.00 KB'));
    await tester.pumpAndSettle();
    expect(find.text('清理 1 项？'), findsOneWidget);
    expect(find.text('旧版数据库备份删除后无法恢复'), findsOneWidget);
    expect(find.byType(MNoticeItem), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MSheetScaffold<bool>),
        matching: find.byType(MSettingDivider),
      ),
      findsOneWidget,
    );
    expect(container.read(storageSelectionProvider).cleaned, isEmpty);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(container.read(storageSelectionProvider).cleaned, isEmpty);
    expect(find.text('清理 1 项？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source error shows retry and disables its rows until retry succeeds',
    (tester) async {
      var fail = true;
      await show(
        tester,
        kind: .partial,
        models: () async {
          if (fail) throw StateError('failed');
          return const [
            StrayModelFile(path: '/x.part', bytes: 1024, kind: .partial),
          ];
        },
      );
      expect(find.widgetWithText(TextButton, '重试'), findsOneWidget);
      expect(
        tester
            .widgetList<SettingCheckboxListTile>(
              find.byType(SettingCheckboxListTile),
            )
            .every((tile) => tile.onChanged == null),
        isTrue,
      );
      fail = false;
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, '重试'), findsNothing);
      expect(
        tester
            .widget<SettingCheckboxListTile>(
              find.byType(SettingCheckboxListTile),
            )
            .onChanged,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
