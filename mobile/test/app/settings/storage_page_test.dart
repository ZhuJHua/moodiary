// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
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

  StorageReport report({
    StorageCleanupKind kind = .cache,
    bool loading = false,
    bool empty = false,
  }) => StorageReport(
    bytes: {for (final area in StorageArea.values) area: 1024},
    done: loading ? {} : StorageArea.values.toSet(),
    area: .other,
    files: 11,
    candidates: {
      if (!empty && !loading)
        kind: StorageCandidates([
          StorageCandidate(
            path: kind == .cache ? '${root.path}/cache.bin' : '/candidate',
            bytes: 1024,
            area: kind.areas.first,
            mediaName: kind == .unusedMedia ? 'orphan.jpg' : null,
          ),
        ]),
    },
  );

  Future<ProviderContainer> show(
    WidgetTester tester, {
    StorageCleanupKind kind = .cache,
    bool loading = false,
    bool busy = false,
    Stream<StorageReport> Function()? reports,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          storageReportProvider.overrideWith(
            (ref) =>
                reports?.call() ??
                Stream.value(report(kind: kind, loading: loading)),
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

  testWidgets('an unfinished kind has no row instead of a placeholder', (
    tester,
  ) async {
    await show(tester, kind: .cache, loading: true);
    expect(find.byType(SettingCheckboxListTile), findsNothing);
    expect(find.text('建议清理'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (kind, loading, busy, subtitle)
      in <(StorageCleanupKind, bool, bool, String)>[
        (.unusedMedia, false, false, '1.00 KB · 1 张照片 · 删除后无法恢复'),
        (.retiredModel, false, false, '1.00 KB · 已不再使用'),
        (.cache, false, true, '同步中'),
      ]) {
    testWidgets('reclaim subtitle: $subtitle', (tester) async {
      await show(tester, kind: kind, loading: loading, busy: busy);
      final tile = tester
          .widgetList<SettingCheckboxListTile>(
            find.byType(SettingCheckboxListTile),
          )
          .singleWhere(
            (tile) =>
                tile.title ==
                (kind == .cache
                    ? '缓存'
                    : kind == .retiredModel
                    ? '旧版心情建议模型'
                    : '未使用的媒体'),
          );
      expect(tile.subtitle, subtitle);
      expect(tile.onChanged == null, loading || busy);
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
      expect(tiles.where((tile) => tile.onTap != null).map((t) => t.title), [
        'AI 模型',
        '媒体',
        '字体',
      ]);
      // 可清理量在右侧尺寸下方，不占副标题，行高不跳
      expect(tiles[2].title, '缓存');
      expect(
        find.descendant(
          of: find.byWidget(tiles[2]),
          matching: find.text('可清理 1.00 KB'),
        ),
        findsOneWidget,
      );
      expect(tiles.every((tile) => tile.subtitle == null), isTrue);
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
      var scans = 0;
      final container = await show(
        tester,
        reports: () => Stream.value(report(empty: scans++ > 0)),
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '清理 1.00 KB'),
      );
      await tester.runAsync(() async {
        final finished = Completer<void>();
        final subscription = container.listen(storageSelectionProvider, (
          _,
          next,
        ) {
          if (!next.cleaning) {
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
      expect(container.read(storageSelectionProvider).cleaning, isFalse);
      expect(find.byType(SettingCheckboxListTile), findsNothing);
      expect(find.text('已清理'), findsNothing);
      expect(scans, 2);
      expect(find.byType(MSheetScaffold<bool>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('careful selection opens a sheet, cancel keeps files', (
    tester,
  ) async {
    final container = await show(tester, kind: .legacyBackup);
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
    expect(container.read(storageSelectionProvider).cleaning, isFalse);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(container.read(storageSelectionProvider).cleaning, isFalse);
    expect(find.text('清理 1 项？'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source error shows retry and disables its rows until retry succeeds',
    (tester) async {
      var fail = true;
      await show(
        tester,
        kind: .partialDownload,
        reports: () => fail
            ? Stream.error(StateError('failed'))
            : Stream.value(report(kind: .partialDownload)),
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
