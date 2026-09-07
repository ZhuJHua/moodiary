import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';
// Override 未从 flutter_riverpod 导出（3.4.2 show 名单未带），需从 riverpod_annotation 导入
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

final _mui = buildMuiTheme(brightness: Brightness.light);

// 必须用 material_ui 自带的 GlobalMaterialLocalizations，用 flutter_localizations 同名类中文下日期选择器会直接抛
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
