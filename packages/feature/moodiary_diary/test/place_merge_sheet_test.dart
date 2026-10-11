import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/place/place_merge_sheet.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:mui/mui.dart';

import 'support/pump.dart';

class _StubPlaceController extends PlaceController {
  _StubPlaceController(this._places);

  final List<Place> _places;

  ({String keptId, String finalName, List<String> removedIds})? merged;
  int undoCalls = 0;
  bool mergeOk = true;
  bool undoOk = true;

  /// 这次合并会改写哪些日记：affectedDiaries 交出去的展示名单。
  List<Diary> affected = const [];

  @override
  Future<List<Place>> build() async => _places;

  @override
  Future<List<Diary>> affectedDiaries(List<String> placeIds) async => affected;

  @override
  Future<PlaceMergeRecord?> mergePlaces({
    required String keptId,
    required String finalName,
    required List<String> removedIds,
  }) async {
    merged = (keptId: keptId, finalName: finalName, removedIds: removedIds);
    if (!mergeOk) return null;
    return PlaceMergeRecord(
      kept: _places.firstWhere((p) => p.id == keptId),
      removed: [for (final p in _places) if (p.id != keptId) p],
      diaryRemap: {for (final d in affected) d.id: 'b'},
      placeOrder: const [],
    );
  }

  @override
  Future<bool> undoMerge(PlaceMergeRecord record) async {
    undoCalls++;
    return undoOk;
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
  final footprints = <String, PlaceFootprint>{
    'a': (count: 2, first: DateTime.utc(2026), last: DateTime.utc(2026)),
    'b': (count: 1, first: DateTime.utc(2026), last: DateTime.utc(2026)),
  };

  late _StubPlaceController stub;
  PlaceMergeOutcome? outcome;

  setUp(() {
    // 多个用例都会断言气泡文案，先关掉跨用例残留的防抖窗口。
    disableToastDebounce();
    getIt.pushNewScope();
    getIt
      ..registerSingleton<IKVStorage>(MemoryKVStorage())
      ..registerSingleton<ISecureKVStorage>(MemorySecureKVStorage());
    stub = _StubPlaceController(candidates)..mergeOk = true;
    outcome = null;
  });

  tearDown(() => getIt.popScope());

  // 与 lib 同一套 mui 组件类型，find.byType 才能对上
  Finder nameField() => find.byType(TextField);
  Finder candidate(String id) =>
      find.byKey(ValueKey('place-merge-candidate-$id'));
  Finder undoButton() => find.byKey(const ValueKey('place-merge-undo'));

  String nameText(WidgetTester tester) =>
      tester.widget<TextField>(nameField()).controller!.text;

  Future<void> pumpSheet(WidgetTester tester) async {
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
              home: Consumer(
                builder: (context, ref, _) {
                  // 常驻监听 placeControllerProvider，避免 autoDispose 元素在
                  // 合并与撤销两次 read 之间被销毁重建（stub 实例不可复用）。
                  ref.watch(placeControllerProvider);
                  return FilledButton(
                    onPressed: () async {
                      outcome =
                          await showPlaceMergeSheet(
                            context,
                            candidates: candidates,
                          );
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 编辑态点「确认」，推进到二次确认对话框。
  Future<void> confirmToDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();
  }

  /// 二次确认对话框里点「合并」。此后处于 merging/running 阶段，
  /// 不能用 pumpAndSettle（不定进度条会无限动画）。
  Future<void> acceptDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, '合并'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 烧掉结果气泡的 displayTime 定时器，避免 teardown 的 pending timer 断言。
  Future<void> burnToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('初始：默认选中第一个候选并预填其名称', (tester) async {
    await pumpSheet(tester);
    expect(find.text('选择最终地址'), findsOneWidget);
    expect(candidate('a'), findsOneWidget);
    expect(candidate('b'), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(nameText(tester), '家');
  });

  testWidgets('点选候选：选中态切换且未手动编辑时名称跟随', (tester) async {
    await pumpSheet(tester);
    await tester.tap(candidate('b'));
    await tester.pump();
    expect(nameText(tester), '家门口');
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
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(find.text('名称不能为空'), findsOneWidget);
    expect(find.text('选择最终地址'), findsOneWidget);
  });

  testWidgets('确认：二次确认对话框展示名称 / 地点数 / 日记数', (tester) async {
    await pumpSheet(tester);
    await confirmToDialog(tester);
    expect(find.text('确认合并地点？'), findsOneWidget);
    expect(
      find.text('「家」将合并 2 个地点，3 篇日记随之指向它，原地点会被删除。'),
      findsOneWidget,
    );

    // 对话框取消：回到编辑态，弹层不关（底部窗同有「取消」按钮，取最上层）
    await tester.tap(find.widgetWithText(FilledButton, '取消').last);
    await tester.pumpAndSettle();
    expect(find.text('选择最终地址'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
    expect(stub.merged, isNull);
    expect(outcome, isNull);
  });

  testWidgets('确认后合并失败：toast 报错并回到编辑态', (tester) async {
    stub.mergeOk = false;
    await pumpSheet(tester);
    await confirmToDialog(tester);
    await acceptDialog(tester);
    await tester.pump();

    expect(find.text('保存失败'), findsOneWidget);
    expect(find.text('选择最终地址'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
    expect(stub.merged, isNotNull);
    expect(outcome, isNull);
    await burnToast(tester);
  });

  testWidgets('确认后进入撤销窗口：进度条与撤销按钮，点撤销退出流程',
      (tester) async {
    await pumpSheet(tester);
    await confirmToDialog(tester);
    await acceptDialog(tester);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(undoButton(), findsOneWidget);

    await tester.tap(undoButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(stub.undoCalls, 1);
    expect(outcome, PlaceMergeOutcome.undone);
    expect(find.text('已撤销合并'), findsOneWidget);
    await burnToast(tester);
  });

  testWidgets('倒计时耗尽：合并落定、关闭弹层并气泡提示', (tester) async {
    await pumpSheet(tester);
    await confirmToDialog(tester);
    await acceptDialog(tester);
    expect(undoButton(), findsOneWidget);
    // 没动到日记：窗口取下限，进度的"篇数"一侧没有可演的
    expect(find.text('没有日记需要改写'), findsOneWidget);

    // 窗口耗尽；toast 在动画回调中弹出，overlay 条目需额外帧完成构建
    await tester.pump(undoWindowFor(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(outcome, PlaceMergeOutcome.completed);
    expect(find.text('已合并为「家」'), findsOneWidget);
    expect(stub.undoCalls, 0);
    await burnToast(tester);
  });

  testWidgets('撤销失败：错误提示，数据以合并状态落地退出', (tester) async {
    stub.undoOk = false;
    await pumpSheet(tester);
    await confirmToDialog(tester);
    await acceptDialog(tester);
    expect(undoButton(), findsOneWidget);

    await tester.tap(undoButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 撤销已调用但失败：toast 报错，结果按 completed 退出流程
    expect(stub.undoCalls, 1);
    expect(outcome, PlaceMergeOutcome.completed);
    expect(find.text('撤销失败'), findsOneWidget);
    await burnToast(tester);
  });

  test('撤销窗口：3 秒起步，每篇日记 0.4 秒，封顶 8 秒', () {
    expect(undoWindowFor(0), const Duration(seconds: 3));
    expect(undoWindowFor(1), const Duration(milliseconds: 3400));
    expect(undoWindowFor(5), const Duration(milliseconds: 5000));
    expect(undoWindowFor(13), const Duration(seconds: 8));
    expect(undoWindowFor(50), const Duration(seconds: 8));
  });

  testWidgets('进度按篇数走：窗口期内逐篇报到，走完才落定', (tester) async {
    stub.affected = [
      _diary('d1', '杭州之行', DateTime.utc(2026, 9, 5)),
      _diary('d2', '看展', DateTime.utc(2026, 9, 3)),
      _diary('d3', '', DateTime.utc(2026, 9, 1)),
    ];
    final window = undoWindowFor(3);
    final slice = window ~/ 3;

    await pumpSheet(tester);
    await confirmToDialog(tester);
    await acceptDialog(tester);

    expect(find.text('正在更新 1/3 篇日记'), findsOneWidget);
    expect(find.text('杭州之行'), findsOneWidget);

    // 走过一篇的时间：报到第二篇，旧标题让位
    await tester.pump(slice);
    expect(find.text('正在更新 2/3 篇日记'), findsOneWidget);
    expect(find.text('看展'), findsOneWidget);

    // 窗口还没走完：撤销入口仍在，流程不落定；无标题的日记回落到通用文案
    await tester.pump(slice);
    expect(find.text('正在更新 3/3 篇日记'), findsOneWidget);
    expect(find.text('无标题'), findsOneWidget);
    expect(undoButton(), findsOneWidget);
    expect(outcome, isNull);

    await tester.pump(window);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(outcome, PlaceMergeOutcome.completed);
    await burnToast(tester);
  });
}
