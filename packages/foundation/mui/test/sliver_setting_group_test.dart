import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Widget _host({
  required int itemCount,
  String? title,
  double viewportHeight = 600,
  ScrollController? controller,
}) => MaterialApp(
  theme: buildMuiTheme(brightness: Brightness.light),
  home: Scaffold(
    body: SizedBox(
      height: viewportHeight,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          MSliverSettingGroup(
            title: title,
            children: [
              for (var i = 0; i < itemCount; i++)
                SettingListTile(title: 'item$i', onTap: () {}),
            ],
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('n 项之间 n-1 条分隔线，首尾不画', (tester) async {
    await tester.pumpWidget(_host(itemCount: 3));
    expect(find.byType(SettingListTile), findsNWidgets(3));
    expect(find.byType(MSettingDivider), findsNWidgets(2));
  });

  testWidgets('只有一项时一条线都没有', (tester) async {
    await tester.pumpWidget(_host(itemCount: 1));
    expect(find.byType(MSettingDivider), findsNothing);
  });

  testWidgets('分隔线是一个设备像素：thickness 0 即 Skia hairline', (tester) async {
    await tester.pumpWidget(_host(itemCount: 2));
    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.thickness, 0, reason: '改成 1/devicePixelRatio 会跨两行各画一半');
    expect(divider.height, 0, reason: '线本身不该占额外高度');
  });

  testWidgets('给了标题才有标题行', (tester) async {
    await tester.pumpWidget(_host(itemCount: 2));
    expect(find.byType(SettingTitleTile), findsNothing);

    await tester.pumpWidget(_host(itemCount: 2, title: '显示'));
    expect(find.byType(SettingTitleTile), findsOneWidget);
    expect(find.text('显示'), findsOneWidget);
  });

  group('圆角落在首末项上', () {
    final lg = buildMuiTheme(brightness: Brightness.light)
        .extension<MuiTokens>()!
        .radii
        .lg;

    /// 首末项各包一层圆角 [Material]（水波由祖先 Material 画，外面套裁剪盖不住它，
    /// 只有这一层能收住）。中间项不包，省一层。
    List<BorderRadius> radiiOf(WidgetTester tester) => tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(MSliverSettingGroup),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.type == MaterialType.transparency)
        .map((m) => m.borderRadius! as BorderRadius)
        .toList();

    testWidgets('首项只圆上面、末项只圆下面，中间项不包', (tester) async {
      await tester.pumpWidget(_host(itemCount: 3));
      final radii = radiiOf(tester);
      expect(radii.length, 2, reason: '中间那项不该多包一层');
      expect(radii.first, BorderRadius.vertical(top: Radius.circular(lg)));
      expect(radii.last, BorderRadius.vertical(bottom: Radius.circular(lg)));
    });

    testWidgets('只有一项时四个角都圆', (tester) async {
      await tester.pumpWidget(_host(itemCount: 1));
      expect(radiiOf(tester).single, BorderRadius.all(Radius.circular(lg)));
    });

    testWidgets('包的是 Material 而不是 ClipRRect —— 后者裁不住水波', (tester) async {
      await tester.pumpWidget(_host(itemCount: 2));
      expect(
        find.descendant(
          of: find.byType(MSliverSettingGroup),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
      );
    });
  });
}
