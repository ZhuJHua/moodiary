import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';
// Override 类型没从 flutter_riverpod 导出（3.4.2 的 show 名单没带），
// 由 riverpod_annotation 补上。
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

final _mui = buildMuiTheme(brightness: Brightness.light);

/// 统一的 widget 测试宿主：ProviderScope + TranslationProvider + MuiTheme +
/// MaterialApp + 两份本地化 delegates。此前每个测试文件手抄一遍这套包裹，
/// 漏抄 delegates 那份的坑（必须用 material_ui 自带的 GlobalMaterialLocalizations，
/// 用 flutter_localizations 的同名类中文下日期选择器直接抛）只能靠人记。
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
