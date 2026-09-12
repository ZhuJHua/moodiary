import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';

import 'support/pump.dart';

void main() {
  final time = DateTime.utc(2026, 9, 8, 14);

  testWidgets('就绪态：日期 + 标题，点击可用', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      muiTestApp(
        DiaryCitationCard(
          state: .ready,
          time: time,
          title: '加班到十点',
          mood: .tired,
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('加班到十点'), findsOneWidget);
    expect(find.textContaining('8'), findsWidgets);
    await tester.tap(find.text('加班到十点'));
    expect(tapped, isTrue);
  });

  testWidgets('回收站态：标出已在回收站，点击无效', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      muiTestApp(
        DiaryCitationCard(
          state: .recycled,
          time: time,
          title: '旧日记',
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('已在回收站'), findsOneWidget);
    await tester.tap(find.text('旧日记'));
    expect(tapped, isFalse);
  });

  testWidgets('缺失态只说不存在；加载态没有文字', (tester) async {
    await tester.pumpWidget(
      muiTestApp(const DiaryCitationCard(state: .missing)),
    );
    expect(find.text('日记不存在或已删除'), findsOneWidget);

    await tester.pumpWidget(
      muiTestApp(const DiaryCitationCard(state: .loading)),
    );
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('放进无界高度的 Column 里也能布局，高度贴内容', (tester) async {
    await tester.pumpWidget(
      muiTestApp(
        Column(
          children: [
            DiaryCitationCard(state: .ready, time: time, title: '加班到十点'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DiaryCitationCard)).height, lessThan(80));
  });

  testWidgets('带 onRemove 时出现移除按钮', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      muiTestApp(
        DiaryCitationCard(
          state: .ready,
          time: time,
          title: '',
          onRemove: () => removed = true,
        ),
      ),
    );
    expect(find.text('无标题'), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.x));
    expect(removed, isTrue);
  });
}
