import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_picker/moodiary_picker.dart';
import 'package:mui/mui.dart';
import 'package:photo_manager/photo_manager.dart';

class _PhotoLibrary extends PhotoManagerPlugin {
  final permissionTypes = <RequestType>[];
  final queryTypes = <RequestType>[];
  final managedTypes = <RequestType>[];

  @override
  Future<PermissionState> requestPermissionExtend(
    PermissionRequestOption requestOption,
  ) async {
    permissionTypes.add(requestOption.androidPermission.type);
    return PermissionState.limited;
  }

  @override
  Future<List<AssetPathEntity>> getAssetPathList({
    bool hasAll = true,
    bool onlyAll = false,
    RequestType type = RequestType.common,
    PMFilter? filterOption,
    required PMPathFilter pathFilterOption,
  }) async {
    queryTypes.add(type);
    return [];
  }

  @override
  Future<void> presentLimited(RequestType type) async {
    managedTypes.add(type);
  }

  @override
  Future<bool> notifyChange({required bool start}) async => true;
}

void main() {
  late _PhotoLibrary library;

  setUp(() async {
    library = _PhotoLibrary();
    PhotoManager.withPlugin(library);
    await LocaleSettings.setLocale(AppLocale.en);
  });

  tearDown(() {
    PhotoManager.withPlugin(PhotoManagerPlugin());
  });

  for (final type in [RequestType.image, RequestType.video]) {
    testWidgets('$type requests visual media access and filters by type', (
      tester,
    ) async {
      final data = buildMuiTheme(brightness: Brightness.light);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: data,
            locale: const Locale('en'),
            localizationsDelegates: const [
              ...GlobalMaterialLocalizations.delegates,
              GlobalMuiLocalizations.delegate,
            ],
            supportedLocales: AppLocaleUtils.supportedLocales,
            builder: (context, child) =>
                // ignore: deprecated_member_use
                MaterialUiCompatibilityBridge(child: child!),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    if (type == RequestType.video) {
                      await MAssetPicker.pickVideo(context);
                    } else {
                      await MAssetPicker.pickImages(context);
                    }
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(library.permissionTypes, [RequestType.common]);
      expect(library.queryTypes, isNotEmpty);
      expect(library.queryTypes, everyElement(type));
      expect(
        find.text(
          type == RequestType.video
              ? l10n.picker.limitedEmptyVideos
              : l10n.picker.limitedEmptyImages,
        ),
        findsOneWidget,
      );
      final manage = find.widgetWithText(
        FilledButton,
        l10n.picker.limitedManage,
      );
      expect(manage.hitTestable(), findsOneWidget);
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(library.managedTypes, [type]);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
    });
  }
}
