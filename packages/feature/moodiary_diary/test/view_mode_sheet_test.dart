import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_diary/src/presentation/widget/view_mode_sheet.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

/// 内存 KV，只为把 [MoodiaryKVs] 的读写接上。
final class _MemoryKVStorage extends IKVStorage {
  final Map<String, Object?> data = {};

  @override
  Future<void> init() async {}

  @override
  T? get<T extends Object>(String key) => data[key] as T?;

  @override
  void set<T extends Object>(String key, T value) {
    data[key] = value;
    super.set(key, value);
  }

  @override
  void remove(String key) {
    data.remove(key);
    super.remove(key);
  }

  @override
  void clear() => data.clear();
}

void main() {
  late _MemoryKVStorage kv;

  setUp(() {
    kv = _MemoryKVStorage();
    if (getIt.isRegistered<IKVStorage>()) getIt.unregister<IKVStorage>();
    getIt.registerSingleton<IKVStorage>(kv);
  });

  tearDown(() => getIt.unregister<IKVStorage>());

  Widget host() {
    return TranslationProvider(
      child: MuiTheme(
        data: _mui,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            // material_ui 的 widget 要它自己那份 MaterialLocalizations。
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => ViewModeSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 排序项排在模式网格之后，测试视口里可能在折叠线以下。
  Future<void> pick(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  int? storedSort() => kv.data[MoodiaryKVs.homeSortMode.name] as int?;

  testWidgets('选中不落盘，按下确定才写', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await pick(tester, '最早在前');
    expect(storedSort(), isNull, reason: '只是暂存，还没写 KV');

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(storedSort(), DiarySort.timeAsc.number);
  });

  testWidgets('取消是真的取消', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await pick(tester, '最早在前');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(storedSort(), isNull);
    expect(find.text('最早在前'), findsNothing, reason: '弹窗已关');
  });

  testWidgets('视图模式同样是暂存，确定才落盘', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await pick(tester, '信息流');
    expect(kv.data[MoodiaryKVs.homeViewMode.name], isNull);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(kv.data[MoodiaryKVs.homeViewMode.name], ViewModeType.feed.number);
  });

  testWidgets('打开时归一旧组合：时间线 + 最近修改在前 → 最新在前', (tester) async {
    kv.data[MoodiaryKVs.homeViewMode.name] = ViewModeType.timeline.number;
    kv.data[MoodiaryKVs.homeSortMode.name] = DiarySort.lastModifiedDesc.number;

    await tester.pumpWidget(host());
    await open(tester);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(storedSort(), DiarySort.timeDesc.number);
  });

  testWidgets('「最近修改在前」只在信息流下出现', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    expect(find.text('最近修改在前'), findsNothing, reason: '默认是时间线');

    await pick(tester, '信息流');
    expect(find.text('最近修改在前'), findsOneWidget);

    await pick(tester, '时间线');
    expect(find.text('最近修改在前'), findsNothing);
  });

  testWidgets('切回时间线时把只属于信息流的排序退回默认', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await pick(tester, '信息流');
    await pick(tester, '最近修改在前');
    await pick(tester, '时间线');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    // 否则会存下一个这张面板再也选不到的组合。
    expect(storedSort(), DiarySort.timeDesc.number);
  });
}
