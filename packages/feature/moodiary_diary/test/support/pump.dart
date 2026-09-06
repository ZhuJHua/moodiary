import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

final _mui = buildMuiTheme(brightness: Brightness.light);

Widget muiTestApp(
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('zh'),
  bool wrapScaffold = true,
}) {
  return ProviderScope(
    overrides: overrides,
    child: TranslationProvider(
      child: MuiTheme(
        data: _mui,
        child: MaterialApp(
          localizationsDelegates: const [
            // 必须用 material_ui 的 GlobalMaterialLocalizations，flutter_localizations 同名类中文下日期选择器会抛错
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: locale,
          home: wrapScaffold ? Scaffold(body: child) : child,
        ),
      ),
    ),
  );
}
