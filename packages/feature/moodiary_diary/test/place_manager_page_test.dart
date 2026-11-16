import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/place/place_manager_page.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

import 'support/place_controller_stub.dart';
import 'support/pump.dart';

void main() {
  final t = DateTime.utc(2026, 9, 5);
  final places = [
    Place(
      id: 'a',
      name: '家',
      latitude: 30.0,
      longitude: 120.0,
      lastModified: t,
    ),
    Place(
      id: 'b',
      name: '家门口',
      latitude: 30.0005,
      longitude: 120.0005,
      lastModified: t,
    ),
    Place(
      id: 'c',
      name: '公司',
      latitude: 30.6,
      longitude: 120.6,
      lastModified: t,
    ),
  ];

  late StubPlaceController stub;
  late SmartConfigCustom previousCustom;

  setUp(() {
    previousCustom = SmartDialog.config.custom;
    // 防抖依赖真实时钟，会吞掉相邻用例的提示。
    SmartDialog.config.custom = SmartConfigCustom(debounceTime: Duration.zero);
    getIt.pushNewScope();
    getIt
      ..registerSingleton<IKVStorage>(MemoryKVStorage())
      ..registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
    stub = StubPlaceController(places);
  });

  tearDown(() async {
    SmartDialog.config.custom = previousCustom;
    await getIt.popScope();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final footprints = <String, PlaceFootprint>{
      'a': (count: 2, first: t, last: t),
      'b': (count: 1, first: t, last: t),
    };
    await tester.pumpWidget(
      muiTestApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const PlaceManagerPage()),
            ),
            child: const Text('open manager'),
          ),
        ),
        overrides: [
          placeControllerProvider.overrideWith(() => stub),
          placeFootprintsProvider.overrideWithValue(AsyncData(footprints)),
        ],
        builder: FlutterSmartDialog.init(),
      ),
    );
    await tester.tap(find.text('open manager'));
    await tester.pumpAndSettle();
  }

  Future<void> openMerge(WidgetTester tester) async {
    await tester.longPress(find.text('家'));
    await tester.pump();
    await tester.tap(find.text('家门口'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '合并'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmMerge(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await pumpTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await pumpTransition(tester);
  }

  Future<void> burnToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('长按进入多选：标题计数、合并按钮按选中数启停', (tester) async {
    await pumpPage(tester);
    expect(find.text('常用地点'), findsOneWidget);

    await tester.longPress(find.text('家'));
    await tester.pump();
    expect(find.text('已选 1 个地点'), findsOneWidget);
    TextButton mergeButton() =>
        tester.widget(find.widgetWithText(TextButton, '合并'));
    expect(mergeButton().onPressed, isNull);

    await tester.tap(find.text('家门口'));
    await tester.pump();
    expect(find.text('已选 2 个地点'), findsOneWidget);
    expect(mergeButton().onPressed, isNotNull);

    await tester.tap(find.text('家门口'));
    await tester.pump();
    expect(find.text('已选 1 个地点'), findsOneWidget);
    expect(mergeButton().onPressed, isNull);
  });

  testWidgets('返回键先退出多选，不退出页面', (tester) async {
    await pumpPage(tester);
    await tester.longPress(find.text('家'));
    await tester.pump();
    expect(find.text('已选 1 个地点'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('常用地点'), findsOneWidget);
    expect(find.text('已选 1 个地点'), findsNothing);
  });

  testWidgets('合并后退出多选，snackbar 撤销恢复地点并提示', (tester) async {
    stub.affectedCount = 3;
    await pumpPage(tester);
    await openMerge(tester);
    await tester.tap(find.widgetWithText(MSheetOptionTile<String>, '家门口'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await pumpTransition(tester);

    expect(find.text('「家门口」将合并 2 个地点，3 篇日记随之指向它，原地点会被删除。'), findsOneWidget);
    expect(stub.merged, isNull);
    await tester.tap(find.widgetWithText(FilledButton, '合并').last);
    await pumpTransition(tester);

    expect(stub.merged!.keptId, 'b');
    expect(stub.merged!.finalName, '家门口');
    expect(stub.merged!.removedIds, ['a']);
    expect(find.text('合并地点'), findsNothing);
    expect(find.text('常用地点'), findsOneWidget);
    expect(find.text('家'), findsNothing);
    expect(find.text('已合并为「家门口」'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await pumpTransition(tester);
    expect(stub.undoCalls, 1);
    expect(stub.undoneRecord!.kept.id, 'b');
    expect(find.text('家'), findsOneWidget);
    expect(find.text('家门口'), findsOneWidget);
    expect(find.text('已撤销合并'), findsOneWidget);
    await burnToast(tester);
  });

  testWidgets('退出管理页、控制器销毁后仍可撤销', (tester) async {
    await pumpPage(tester);
    await openMerge(tester);
    await confirmMerge(tester);
    expect(find.text('已合并为「家」'), findsOneWidget);
    expect(find.text('常用地点'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(PlaceManagerPage), findsNothing);
    expect(stub.disposed, isTrue);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await pumpTransition(tester);
    expect(stub.undoCalls, 1);
    expect(find.text('已撤销合并'), findsOneWidget);
    await burnToast(tester);
  });

  testWidgets('合并失败：提示保存失败并保留多选', (tester) async {
    stub.mergeOk = false;
    await pumpPage(tester);
    await openMerge(tester);
    await confirmMerge(tester);

    expect(stub.merged, isNotNull);
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.text('已选 2 个地点'), findsOneWidget);
    expect(find.text('合并地点'), findsNothing);
    expect(find.text('撤销'), findsNothing);
    expect(find.text('家'), findsOneWidget);
    expect(find.text('家门口'), findsOneWidget);
    await burnToast(tester);
  });

  testWidgets('撤销失败：提示错误并保留合并结果', (tester) async {
    stub.undoOk = false;
    await pumpPage(tester);
    await openMerge(tester);
    await confirmMerge(tester);
    await tester.tap(find.text('撤销'));
    await pumpTransition(tester);

    expect(stub.undoCalls, 1);
    expect(find.text('撤销失败'), findsOneWidget);
    expect(find.text('家门口'), findsNothing);
    expect(find.text('常用地点'), findsOneWidget);
    await burnToast(tester);
  });

  testWidgets('弹层取消：保留多选状态', (tester) async {
    await pumpPage(tester);
    await openMerge(tester);

    expect(find.text('合并地点'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('合并地点'), findsNothing);
    expect(find.text('已选 2 个地点'), findsOneWidget);
    expect(stub.merged, isNull);
  });

  testWidgets('搜索后进多选：看不见的查询不留在背后，列表恢复全量', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), '家');
    await tester.pump();
    expect(find.text('公司'), findsNothing);

    await tester.longPress(find.text('家门口'));
    await tester.pump();
    expect(find.text('已选 1 个地点'), findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    expect(find.text('公司'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pump();
    expect(find.text('常用地点'), findsOneWidget);
    expect(find.text('公司'), findsOneWidget);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
      isEmpty,
    );
  });
}
