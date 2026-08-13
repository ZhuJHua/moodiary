import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/find_locale.dart';
import 'package:intl/intl.dart';
import 'package:moodiary/app/di/service_di.dart';
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

Future<Locale> _initSystem() async {
  final rustInit = RustLib.init();
  await injectBasicService();
  // 版本迁移钩子：在基础存储就位后、主题/服务初始化前运行（旧版内联在 KV.init）。
  // 用 try/catch 包裹：迁移抛异常时只记日志、不阻断启动——否则 appVersion 不推进，
  // 每次启动都在同一步崩，陷入永久崩溃循环把用户锁在数据外。步骤幂等，下次启动重试。
  try {
    await VersionMigrator.run();
  } catch (e, s) {
    logger.e('version migration failed', error: e, stackTrace: s);
  }
  unawaited(_platFormOption());
  final localeFuture = _findLanguage();
  // registerService 会立刻打到 Rust，必须先等桥就绪。
  await rustInit;
  await Future.wait([
    FontRepository.get().getActiveFont().then(
      (font) => ThemeManager().buildTheme(customFont: font),
    ),
    registerService(),
    localeFuture,
  ]);

  SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
  return localeFuture;
}

Future<Locale> _findLanguage() async {
  Language language = Language.values.firstWhere(
    (e) => e.languageCode == MoodiaryKVs.language.get()!,
    orElse: () => Language.system,
  );
  if (language == .system) {
    final systemLocale = await findSystemLocale();
    final systemLanguageCode = systemLocale.contains('_')
        ? systemLocale.split('_').first
        : systemLocale;
    language = Language.values.firstWhere(
      (e) => e.languageCode == systemLanguageCode,
      orElse: () => Language.english,
    );
  }
  final locale = Locale(language.languageCode);
  Intl.defaultLocale = locale.languageCode;
  return locale;
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
}

String _resolveInitialLocation() {
  if (MoodiaryKVs.lock.get() == true) return '/lock';
  if (MoodiaryKVs.firstStart.get() == true) return '/start';
  return '/';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = await _initSystem();
  buildRouter(initialLocation: _resolveInitialLocation());

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.e(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.f('Error', error: error, stackTrace: stack);
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [appInitialLocaleProvider.overrideWithValue(locale)],
      child: const Moodiary(),
    ),
  );
}

class Moodiary extends ConsumerWidget {
  const Moodiary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      routerConfig: router,
      builder: (context, child) {
        // 主题不再由这里注入：`MaterialApp` 内部已经用 AnimatedTheme 把 `theme` /
        // `darkTheme` 补间好挂在 builder **上方**，`context.theme` 直接派生自
        // `Theme.of`，深浅切换的过渡因此是免费的。
        final brightness = switch (settings.themeMode) {
          .light => Brightness.light,
          .dark => Brightness.dark,
          .system => MediaQuery.platformBrightnessOf(context),
        };
        // 状态栏/导航栏图标的兜底。AppBar 自带的那层注解覆盖在它上面、只管有
        // AppBar 的页面；没有 AppBar 的页面（详情、图片浏览、相机、视频全屏）
        // 全靠这一层，否则会沿用上一个页面留下的明暗。
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyleOf(brightness),
          // 自有代码已全量切到 material_ui，但依赖图里还有 40+ 个包在读
          // legacy 的 `Theme.of`（chat_ui、wechat picker、smart_dialog…）。
          // 桥接把 modern ThemeData 映射成 legacy 挂在同一棵树上，那些 widget
          // 因此还能拿到我们的配色与排版。
          //
          // 注意它**只映射 platform / visualDensity / colorScheme / textTheme**
          // 四项，25 个组件子主题（水波纹关闭、lucide 返回键、输入框装饰…）不过桥，
          // 所以第三方 widget 的组件级样式会回落到 Material 默认。
          //
          // 位置有唯一正确答案：套在 SmartDialog 外面。init() 会自建 Overlay，
          // toast / loading 是与 child 平级的兄弟 entry，包在里面就吃不到主题。
          //
          // 出厂即 @Deprecated 是官方在表态「这是临时物」，依赖迁完就摘。
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(
            // 后台隐私遮罩包在**最外层**：它自建 Overlay，把遮罩作为独立 entry
            // 叠在整个 App 之上。套在 SmartDialog 外面，切后台时连 toast / loading
            // 一起糊掉——那些浮层是 SmartDialog 自建 Overlay 的兄弟 entry，
            // 包在里面就盖不住。
            child: FrostedGlassOverlayComponent(
              child: FlutterSmartDialog.init()(context, child!),
            ),
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: settings.locale,
      themeMode: settings.themeMode,
      // **不能用 `AppLocalizations.localizationsDelegates`**：gen-l10n 生成的那份里
      // 带的是 flutter_localizations 的 GlobalMaterialLocalizations，给出的是
      // **legacy** MaterialLocalizations 类型，material_ui 的 widget 认不得它，
      // 中文下会退化成「locale zh is not supported」并让日期选择器一类直接抛。
      // material_ui 自带一份同名的，`delegates` 里已含 cupertino/widgets 两条。
      //
      // 生成文件会被覆盖，所以这个列表只能手写在这里。
      // legacy 子树的那份由根部的 MaterialUiCompatibilityBridge 自己注入。
      localizationsDelegates: const [
        AppLocalizations.delegate,
        MuiLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
