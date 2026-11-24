import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_media/moodiary_media.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

final _date = DateTime(2026, 11, 20);

class _Items extends MediaItems {
  int renameCalls = 0;
  @override
  Future<List<MediaItem>> build({required MediaType type}) => init();

  @override
  Future<List<MediaItem>> load({
    required int limit,
    required int offset,
  }) async => [
    _item('Other diary', diaryId: 'other'),
    _item('Meeting'),
    if (type == .file) _item(null, diaryId: 'unnamed'),
  ];

  MediaItem _item(String? label, {String diaryId = 'diary'}) => MediaItem(
    diaryId: diaryId,
    fileName: type == .file ? 'stored.pdf' : 'stored.m4a',
    name: label,
    time: _date,
  );

  @override
  Future<void> rename(String fileName, String name) async {
    renameCalls++;
    state = .data([_item(name)]);
  }
}

Future<void> _show(
  WidgetTester tester,
  MediaType type, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool unnamed = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: MediaRoute.path,
    initialExtra: MediaRoute(type: type.value).params,
    routes: mediaRoutes(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaItemsProvider(type: type).overrideWith(_Items.new),
        attachmentSizeProvider('stored.pdf').overrideWith((_) async => 1536),
        attachmentSizeProvider(
          'stored.m4a',
          audio: true,
        ).overrideWith((_) async => 1536),
        audioDurationProvider('stored.m4a')
            .overrideWith((_) async => const Duration(seconds: 222)),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildMuiTheme(brightness: .light),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          // ignore: deprecated_member_use
          builder: (context, child) => MaterialUiCompatibilityBridge(
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final title = unnamed ? l10n.media.typeFile : 'Meeting';
  final row = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.text(title),
  );
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setupPluralResolvers);

  testWidgets(
    'unnamed references start with an empty prompt and unchanged input skips rename',
    (tester) async {
      await _show(tester, .file, unnamed: true);
      final title = find.text(l10n.media.typeFile);
      final items = ProviderScope.containerOf(
        tester.element(title),
      ).read(mediaItemsProvider(type: .file).notifier) as _Items;
      await tester.tap(title);
      await tester.pumpAndSettle();
      final field = find.byType(EditableText);
      expect(tester.widget<EditableText>(field).controller.text, isEmpty);
      await tester.enterText(field, '   ');
      await tester.tap(find.text(tester.element(field).muiL10n.ok));
      await tester.pumpAndSettle();
      expect(items.renameCalls, 0);
    },
  );

  testWidgets('an invalid detail route shows its stored name at the root', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: MediaDetailRoute.path,
      initialExtra: {'name': 'unavailable.pdf', 'type': 'other'},
      routes: mediaRoutes(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildMuiTheme(brightness: .light),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('unavailable.pdf'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scrub bar seeks on tap and commits a horizontal drag once', (
    tester,
  ) async {
    final seeks = <double>[];
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: .light),
          home: Center(
            child: SizedBox(
              width: 200,
              child: MAudioScrubBar(fraction: 0, onSeek: seeks.add),
            ),
          ),
        ),
      ),
    );
    final bar = tester.getRect(find.byType(MAudioScrubBar));
    await tester.tapAt(bar.centerLeft + const Offset(50, 0));
    expect(seeks, [.25]);
    final drag = await tester.startGesture(
      bar.centerLeft + const Offset(25, 0),
    );
    await drag.moveTo(bar.center);
    await drag.moveTo(bar.centerLeft + const Offset(150, 0));
    expect(seeks, [.25]);
    await drag.up();
    expect(seeks, [.25, .75]);
  });

  testWidgets('file row opens details and rename updates details and library', (
    tester,
  ) async {
    await _show(tester, .file);
    expect(
      find.text('PDF · 1.50 KB · ${TimeFormat.longDate(_date)}'),
      findsOneWidget,
    );
    expect(find.text(l10n.media.openWith), findsOneWidget);
    expect(find.byTooltip(l10n.share.share), findsOneWidget);
    await tester.tap(find.text('Meeting'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.media.rename), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Renamed');
    final context = tester.element(find.byType(EditableText));
    await tester.tap(find.text(context.muiL10n.ok));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('audio opens paused and controls scroll into view at 1.3 scale', (
    tester,
  ) async {
    final playerCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        playerCalls.add(call.method);
        return null;
      },
    );
    await _show(tester, .audio, size: const Size(844, 320), scale: 1.3);
    expect(
      find.text('3:42 · 1.50 KB · ${TimeFormat.longDate(_date)}'),
      findsOneWidget,
    );
    expect(find.text('0:00'), findsOneWidget);
    expect(find.byTooltip(l10n.ui.pause), findsNothing);
    expect(playerCalls, isEmpty);
    final play = find.byTooltip(l10n.ui.play);
    await tester.ensureVisible(play);
    expect(play.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
