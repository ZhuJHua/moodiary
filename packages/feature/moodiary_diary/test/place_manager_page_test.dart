import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/place/place_manager_page.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

class _StubPlaceController extends PlaceController {
  _StubPlaceController(this._places);

  final List<Place> _places;

  ({String keptId, String finalName, List<String> removedIds})? merged;
  int undoCalls = 0;

  @override
  Future<List<Place>> build() async => _places;

  /// 合并会改写的日记：确认文案里的篇数与撤销窗口的进度都读它。
  List<Diary> affected = const [];

  @override
  Future<List<Diary>> affectedDiaries(List<String> placeIds) async => affected;

  @override
  Future<PlaceMergeRecord?> mergePlaces({
    required String keptId,
    required String finalName,
    required List<String> removedIds,
  }) async {
    merged = (keptId: keptId, finalName: finalName, removedIds: removedIds);
    return PlaceMergeRecord(
      kept: _places.first,
      removed: _places.sublist(1),
      diaryRemap: const {},
      placeOrder: const [],
    );
  }

  @override
  Future<bool> undoMerge(PlaceMergeRecord record) async {
    undoCalls++;
    return true;
  }
}

Diary _diary(String id, String title, DateTime time) => Diary(
  id: id,
  title: title,
  content: '',
  contentText: '',
  time: time,
  lastModified: time,
  show: true,
  mood: DiaryMood.okay,
  imageName: const [],
  audioName: const [],
  videoName: const [],
  tags: const [],
  type: 'tiptap',
);

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

  late _StubPlaceController stub;

  setUp(() {
    getIt.pushNewScope();
    getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    stub = _StubPlaceController(places);
  });

  tearDown(() => getIt.popScope());

  Future<void> pumpPage(WidgetTester tester) async {
    final footprints = <String, PlaceFootprint>{
      'a': (count: 2, first: t, last: t),
      'b': (count: 1, first: t, last: t),
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeControllerProvider.overrideWith(() => stub),
          placeFootprintsProvider.overrideWithValue(AsyncData(footprints)),
        ],
        child: TranslationProvider(
          child: MuiTheme(
            data: buildMuiTheme(brightness: Brightness.light),
            child: MaterialApp(
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
                GlobalMuiLocalizations.delegate,
              ],
              supportedLocales: AppLocaleUtils.supportedLocales,
              locale: const Locale('zh'),
              builder: FlutterSmartDialog.init(),
              home: const PlaceManagerPage(),
            ),
          ),
        ),
      ),
    );
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

    // 再点一次取消选中，合并恢复禁用
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

  testWidgets('完整合并流程：多选 → 选最终地址 → 二次确认 → 撤销退出', (tester) async {
    stub.affected = [
      _diary('d1', '杭州之行', DateTime.utc(2026, 9, 5)),
      _diary('d2', '看展', DateTime.utc(2026, 9, 3)),
      _diary('d3', '', DateTime.utc(2026, 9, 1)),
    ];
    await pumpPage(tester);

    await tester.longPress(find.text('家'));
    await tester.pump();
    await tester.tap(find.text('家门口'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '合并'));
    await tester.pumpAndSettle();

    // 合并弹层：选「家门口」作为最终地址
    expect(find.text('选择最终地址'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-merge-candidate-b')));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    // 二次确认：展示名称 / 地点数 / 日记数
    expect(find.text('确认合并地点？'), findsOneWidget);
    expect(find.text('「家门口」将合并 2 个地点，3 篇日记随之指向它，原地点会被删除。'), findsOneWidget);
    // 弹层里的动作按钮是 FilledButton，与标题栏 TextButton 区分
    await tester.tap(find.widgetWithText(FilledButton, '合并'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(stub.merged, isNotNull);
    expect(stub.merged!.keptId, 'b');
    expect(stub.merged!.finalName, '家门口');
    expect(stub.merged!.removedIds, ['a']);

    // 回到底部窗：进度条 + 撤销按钮
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('place-merge-undo')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-merge-undo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 整个流程退出：弹层关闭、撤销被调用、页面退出多选
    expect(stub.undoCalls, 1);
    expect(find.text('选择最终地址'), findsNothing);
    expect(find.text('常用地点'), findsOneWidget);
    expect(find.text('已撤销合并'), findsOneWidget);

    // 烧掉撤销成功 toast 的 displayTime 定时器，避免 teardown 的 pending timer 断言
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('弹层取消：保留多选状态', (tester) async {
    await pumpPage(tester);

    await tester.longPress(find.text('家'));
    await tester.pump();
    await tester.tap(find.text('家门口'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '合并'));
    await tester.pumpAndSettle();

    expect(find.text('选择最终地址'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '取消'));
    await tester.pumpAndSettle();

    expect(find.text('选择最终地址'), findsNothing);
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
    // 搜索框收起，列表也不该再被它过滤：候选不应只剩最初的搜索结果
    expect(find.byType(TextField), findsNothing);
    expect(find.text('公司'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pump();
    expect(find.text('常用地点'), findsOneWidget);
    expect(find.text('公司'), findsOneWidget);
    // 重建的搜索框是空的，列表与之一致
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
      isEmpty,
    );
  });

  testWidgets('多选态把选中交给 ListTile，读屏能听出选中行', (tester) async {
    await pumpPage(tester);
    await tester.longPress(find.text('家'));
    await tester.pump();

    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '家')).selected,
      isTrue,
    );
    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, '公司')).selected,
      isFalse,
    );
  });
}
