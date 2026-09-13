import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_assistant/src/presentation/diary_citations.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  late MoodiaryDatabase db;

  setUp(() {
    db = MoodiaryDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<DiaryRepository>(DiaryRepository(db));
  });

  tearDown(() async {
    await getIt.reset();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    final data = buildMuiTheme(brightness: Brightness.light);
    await tester.pumpWidget(
      TranslationProvider(
        child: MuiTheme(
          data: data,
          child: MaterialApp(
            theme: data,
            locale: const Locale('zh'),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            supportedLocales: AppLocaleUtils.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: .topLeft,
                child: SizedBox(width: 360, child: child),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('版式由篇数决定', () {
    testWidgets('多篇：走横向轨，不再拿 single 取值', (tester) async {
      await pump(tester, const DiaryCitations(ids: ['a', 'b']));
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('单篇：整卡，不套滚动', (tester) async {
      await pump(tester, const DiaryCitations(ids: ['a']));
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

  });
}
