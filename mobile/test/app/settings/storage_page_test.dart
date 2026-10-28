// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_controller.dart';
import 'package:moodiary_mobile/app/settings/storage/storage_page.dart';
import 'package:mui/mui.dart';

class _Controller extends StorageController {
  final StorageState initial;
  int cleanCalls = 0;
  _Controller(this.initial);
  @override
  StorageState build() => initial;
  @override
  Future<int> clean() {
    cleanCalls++;
    return Completer<int>().future;
  }
}

void main() {
  setUpAll(setupPluralResolvers);
  test('busy cache is excluded from both selection and cleaning totals', () {
    const state = StorageState(
      items: [
        Reclaimable(
          id: 'cache',
          area: .cache,
          kind: .cache,
          ready: true,
          bytes: 1024,
          busy: true,
        ),
      ],
      checked: {'cache'},
    );
    expect(state.selected, isEmpty);
    expect(state.selectedBytes, 0);
  });

  final progress = StorageScanProgress(
    bytes: {for (final area in StorageArea.values) area: 1024},
    done: StorageArea.values.toSet(),
    area: .other,
    files: 11,
    reclaimableCacheBytes: 1024,
  );

  Future<_Controller> show(
    WidgetTester tester, {
    bool careful = false,
    StorageState? initial,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _Controller(
      initial ??
          StorageState(
            progress: progress,
            items: [
              Reclaimable(
                id: 'test',
                area: .cache,
                kind: careful ? .legacy : .cache,
                safety: careful ? .careful : .safe,
                ready: true,
                bytes: 1024,
              ),
            ],
            checked: const {'test'},
          ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageControllerProvider.overrideWith(() => controller)],
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
    return controller;
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

  for (final (item, cleaned, subtitle) in <(Reclaimable, bool, String)>[
    (
      const Reclaimable(
        id: 'test',
        area: .image,
        kind: .orphan,
        ready: true,
        bytes: 1024,
        counts: {.image: 1},
      ),
      false,
      '1.00 KB · 1 张照片 · 删除后无法恢复',
    ),
    (
      const Reclaimable(
        id: 'test',
        area: .model,
        kind: .retiredMood,
        ready: true,
        bytes: 1024,
      ),
      false,
      '1.00 KB · 已不再使用',
    ),
    (const Reclaimable(id: 'test', area: .cache, kind: .cache), false, '统计中'),
    (
      const Reclaimable(
        id: 'test',
        area: .cache,
        kind: .cache,
        ready: true,
        bytes: 1024,
      ),
      true,
      '已清理',
    ),
    (
      const Reclaimable(
        id: 'test',
        area: .cache,
        kind: .cache,
        ready: true,
        bytes: 1024,
        busy: true,
      ),
      false,
      '同步中',
    ),
  ]) {
    testWidgets('reclaim subtitle: $subtitle', (tester) async {
      await show(
        tester,
        initial: StorageState(
          progress: progress,
          items: [item],
          cleaned: cleaned ? {'test'} : {},
        ),
      );
      final tile = tester.widget<SettingCheckboxListTile>(
        find.byType(SettingCheckboxListTile),
      );
      expect(tile.subtitle, subtitle);
      expect(tile.onChanged == null, !item.available || cleaned);
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
      final controller = await show(tester, careful: false);
      await tester.tap(find.widgetWithText(FilledButton, '清理 1.00 KB'));
      await tester.pump();
      expect(controller.cleanCalls, 1);
      expect(find.byType(MSheetScaffold<bool>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('careful selection opens a sheet, cancel keeps files', (
    tester,
  ) async {
    final controller = await show(tester, careful: true);
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
    expect(controller.cleanCalls, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.cleanCalls, 0);
    expect(find.text('清理 1 项？'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
