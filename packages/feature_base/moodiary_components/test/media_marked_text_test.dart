import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_content/moodiary_content.dart';

void main() {
  testWidgets('uses plain Text only when no media markup is present', (
    tester,
  ) async {
    const style = TextStyle(fontSize: 16);
    Future<Text> render(String text) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: MediaMarkedText(
            text,
            style: style,
            maxLines: 2,
            overflow: .ellipsis,
          ),
        ),
      );
      return tester.widget<Text>(find.byType(Text));
    }

    final plain = await render('Plain 😀');
    expect(plain.data, 'Plain 😀');
    expect(plain.textSpan, isNull);
    expect(plain.style, style);
    expect(plain.maxLines, 2);
    expect(plain.overflow, TextOverflow.ellipsis);

    final rich = await render(MediaMarkup.mark(.image, 'Photo'));
    expect(rich.data, isNull);
    expect(rich.textSpan, isA<TextSpan>());
    expect(find.byIcon(LucideIcons.image), findsOneWidget);
  });
}
