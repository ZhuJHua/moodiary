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
  Widget? drawer,
  Key? scaffoldKey,
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
          home: wrapScaffold
              ? Scaffold(key: scaffoldKey, drawer: drawer, body: child)
              : child,
        ),
      ),
    ),
  );
}

/// 关掉气泡的防抖窗口；断言气泡文案的用例在 `setUp` 里调一次。
///
/// `Toast` 走 `SmartDialog.show`，防抖由 flutter_smart_dialog 的进程级 static 表
/// 按**真实时钟**判断（默认 300ms）：`tester.pump` 只推进 fake clock，同一个
/// isolate 里上一个用例刚弹过气泡时（真实相隔常常只有几十毫秒），本用例的气泡
/// 会被静默丢弃，`find.text` 随即随机失败。窗口压到零后，气泡出不出只由本用例
/// 的调用决定。
void disableToastDebounce() {
  SmartDialog.config.custom = SmartConfigCustom(debounceTime: Duration.zero);
}
