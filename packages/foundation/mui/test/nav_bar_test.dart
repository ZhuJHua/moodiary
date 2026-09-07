import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

const _destinations = [
  MNavDestination(icon: Icon(LucideIcons.bookText), label: '日记'),
  MNavDestination(icon: Icon(LucideIcons.image), label: '媒体'),
  MNavDestination(icon: Icon(LucideIcons.astroid), label: '助手'),
];

Future<double> _bandHeight(
  WidgetTester tester, {
  required double bottomInset,
}) async {
  late double band;
  await tester.pumpWidget(
    MuiTheme(
      data: _mui,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: .only(bottom: bottomInset)),
          child: Scaffold(
            extendBody: true,
            body: Builder(
              builder: (context) {
                band = MediaQuery.paddingOf(context).bottom;
                return const SizedBox.expand();
              },
            ),
            bottomNavigationBar: MNavBar(
              destinations: _destinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              action: const MNavAction(icon: Icon(LucideIcons.pencilLine)),
            ),
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
    final without = await _bandHeight(tester, bottomInset: 0);
    final with48 = await _bandHeight(tester, bottomInset: 48);
    expect(with48 - without, 48, reason: '底栏没有让开安全区：$without vs $with48');
  });
}
