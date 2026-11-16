import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/place/place_merge_sheet.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

import 'support/place_controller_stub.dart';
import 'support/pump.dart';

void main() {
  final candidates = [
    Place(
      id: 'a',
      name: '家',
      latitude: 30.0,
      longitude: 120.0,
      lastModified: DateTime.utc(2026),
    ),
    Place(
      id: 'b',
      name: '家门口',
      latitude: 30.0005,
      longitude: 120.0005,
      lastModified: DateTime.utc(2026),
    ),
  ];
  late StubPlaceController stub;
  late Map<String, PlaceFootprint> footprints;
  ({String keptId, String name})? outcome;
  bool closed = false;

  setUp(() {
    getIt.pushNewScope();
    getIt
      ..registerSingleton<IKVStorage>(MemoryKVStorage())
      ..registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
    stub = StubPlaceController(candidates);
    final time = DateTime.utc(2026);
    footprints = {
      'a': (count: 2, first: time, last: time),
      'b': (count: 1, first: time, last: time),
    };
    outcome = null;
    closed = false;
  });

  tearDown(() => getIt.popScope());

  Finder nameField() => find.descendant(
    of: find.byType(MField),
    matching: find.byType(TextField),
  );
  Finder candidate(String id) => find.byWidgetPredicate(
    (widget) => widget is MSheetOptionTile<String> && widget.option.value == id,
  );

  String nameText(WidgetTester tester) =>
      tester.widget<TextField>(nameField()).controller!.text;

  Future<void> pumpSheet(WidgetTester tester, {List<Place>? places}) async {
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              outcome = await showPlaceMergeSheet(
                context,
                candidates: places ?? candidates,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
        overrides: [
          placeControllerProvider.overrideWith(() => stub),
          placeFootprintsProvider.overrideWithValue(AsyncData(footprints)),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmToDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await pumpTransition(tester);
  }

  testWidgets('初始：默认选中第一个候选并预填其名称', (tester) async {
    await pumpSheet(tester);
    expect(find.text('合并地点'), findsOneWidget);
    expect(candidate('a'), findsOneWidget);
    expect(candidate('b'), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(nameText(tester), '家');
    expect(find.text('保留一个，其余 1 个并入它'), findsOneWidget);
    expect(find.widgetWithText(MFormSection, '保留哪一个'), findsOneWidget);
    final field = tester.widget<MField>(find.byType(MField));
    expect(field.label, '合并后的名称');
    expect(field.textInputAction, TextInputAction.done);
    expect(find.widgetWithText(FilledButton, '合并'), findsOneWidget);
  });

  testWidgets('点选候选：选中态切换且未手动编辑时名称跟随', (tester) async {
    await pumpSheet(tester);
    await tester.tap(candidate('b'));
    await tester.pump();
    expect(nameText(tester), '家门口');
    expect(
      tester.widget<MSheetOptionTile<String>>(candidate('a')).selected,
      isFalse,
    );
    expect(
      tester.widget<MSheetOptionTile<String>>(candidate('b')).selected,
      isTrue,
    );
  });

  testWidgets('手动编辑过名称后，切换候选不再覆盖输入', (tester) async {
    await pumpSheet(tester);
    await tester.enterText(nameField(), '自定义名');
    await tester.pump();
    await tester.tap(candidate('b'));
    await tester.pump();
    expect(nameText(tester), '自定义名');
  });

  testWidgets('名称为空时确认：报错且不关闭弹层', (tester) async {
    await pumpSheet(tester);
    await tester.enterText(nameField(), '');
    await tester.pump();
    await tester.tap(find.text('合并'));
    await tester.pump();
    expect(find.text('名称不能为空'), findsOneWidget);
    expect(find.text('合并地点'), findsOneWidget);
    await tester.enterText(nameField(), '新家');
    await tester.pump();
    expect(find.text('名称不能为空'), findsNothing);
  });

  testWidgets('确认：二次确认对话框展示名称 / 地点数 / 日记数', (tester) async {
    stub.affectedCount = 3;
    await pumpSheet(tester);
    await confirmToDialog(tester);
    expect(find.text('确认合并地点？'), findsOneWidget);
    expect(find.text('「家」将合并 2 个地点，3 篇日记随之指向它，原地点会被删除。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '取消').last);
    await tester.pumpAndSettle();
    expect(find.text('合并地点'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '合并').last, findsOneWidget);
    expect(outcome, isNull);
  });

  testWidgets('确认后返回保留地点与名称', (tester) async {
    await pumpSheet(tester);
    await tester.tap(candidate('b'));
    await tester.enterText(nameField(), '  最终名称  ');
    await confirmToDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(outcome, (keptId: 'b', name: '最终名称'));
    expect(find.text('合并地点'), findsNothing);
  });

  testWidgets('取消返回 null', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.widgetWithText(FilledButton, '取消'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(outcome, isNull);
  });

  testWidgets('候选显示日记数或空计数，距离相对保留地点', (tester) async {
    footprints.remove('b');
    await pumpSheet(tester);
    final tiles = tester.widgetList<MSheetOptionTile<String>>(
      find.byType(MSheetOptionTile<String>),
    );
    expect(tiles.map((tile) => tile.option.value), ['a', 'b']);
    expect(tiles.map((tile) => tile.option.label), ['家', '家门口']);
    expect(find.text('2 篇日记'), findsOneWidget);
    expect(find.text('暂无日记 · 距此 74 m'), findsOneWidget);
    await tester.tap(candidate('b'));
    await tester.pump();
    expect(find.text('暂无日记'), findsOneWidget);
    expect(find.text('2 篇日记 · 距此 74 m'), findsOneWidget);
  });

  testWidgets('天地图未配置密钥时隐藏地图，名称自动聚焦', (tester) async {
    MoodiaryKVs.mapTileSource.set('tianditu');
    await pumpSheet(tester);
    expect(find.byType(FlutterMap), findsNothing);
    expect(tester.widget<MField>(find.byType(MField)).autofocus, isTrue);
  });
}
