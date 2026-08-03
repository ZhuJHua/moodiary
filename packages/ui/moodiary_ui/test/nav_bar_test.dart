import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

const _destinations = [
  MoodiaryNavDestination(
    icon: Icon(Icons.article_outlined),
    selectedIcon: Icon(Icons.article),
    label: '日记',
  ),
  MoodiaryNavDestination(
    icon: Icon(Icons.image_outlined),
    selectedIcon: Icon(Icons.image),
    label: '媒体',
  ),
  MoodiaryNavDestination(
    icon: Icon(Icons.smart_toy_outlined),
    selectedIcon: Icon(Icons.smart_toy),
    label: '助手',
  ),
];

/// 底栏整条带高 —— 取 Scaffold 折进 body 的 `padding.bottom`，这正是各页面读来
/// 补留白的那个数，也是「底栏有没有让开安全区」的可观测面。
Future<double> _bandHeight(
  WidgetTester tester, {
  required double bottomInset,
}) async {
  late double band;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: Scaffold(
          extendBody: true,
          body: Builder(
            builder: (context) {
              band = MediaQuery.paddingOf(context).bottom;
              return const SizedBox.expand();
            },
          ),
          bottomNavigationBar: MoodiaryNavBar(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            action: const MoodiaryNavAction(icon: Icon(Icons.add)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return band;
}

void main() {
  testWidgets('底栏让开底部安全区', (tester) async {
    // 底栏悬浮后不再有 M3 NavigationBar 自带的 SafeArea，安全区得自己让 ——
    // 不让的话安卓三键导航下药丸会压在系统栏底下。
    final without = await _bandHeight(tester, bottomInset: 0);
    final with48 = await _bandHeight(tester, bottomInset: 48);
    expect(with48 - without, 48, reason: '底栏没有让开安全区：$without vs $with48');
  });
}
