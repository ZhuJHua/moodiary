import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary/app/boot_failure_page.dart';
import 'package:moodiary/app/di/bootstrap.dart';
import 'package:moodiary/app/di/di.dart';
import 'package:moodiary/app/lifecycle/app_lock_observer.dart';
import 'package:moodiary/app/locale.dart';
import 'package:moodiary/app/router/router.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show EditorMigrationService;
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_preferences/moodiary_preferences.dart';
import 'package:moodiary_rust/rust.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_sync/moodiary_sync.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

Future<void> _initSystem() async {
  // Rust 桥最先就绪：dlopen 的耗时串行计入启动，换来「后面任何一步都可以打 Rust」
  // 的零心智负担——迁移的字体重扫、维护任务的分词都不用再关心桥的时序。
  await RustLib.init();

  // ── 1. 路径与日志（一切存储的前置）→ 容器装配 ∥ Isar 打开。
  // configureDependencies 内部的 preResolve 在这一步落定：SecureKV → KV（含 2.8.0
  // 搬迁；这条次序不再靠调用顺序，它是 MmkvKVStorage.create 收 ISecureKVStorage
  // 的类型边）、SyncLogger 落盘就绪。KV 与 Isar 互不依赖，并行开。
  await bootstrapPlatform();
  await Future.wait([
    configureDependencies(),
    IsarDatabase.get().init(
      schemas: moodiarySchemas,
      directory: AppFiles.getRealPath('database', ''),
    ),
  ]);
  // 应用锁的开关是「有没有凭据」的派生态，读一次钥匙串装进内存；
  // 路由与生命周期回调都是同步的，够不着异步的 SecureKV。
  await AppLockPin.load();

  // ── 2. 版本迁移：基础存储就位后、任何人读业务数据之前，
  // 也必须在 AutoSyncWatcher 醒来之前——迁移写出的行不是用户的本地变更，
  // 被 watcher 当成变更推给云端就是一次凭空的全量上传。
  // 用 try/catch 包裹：迁移抛异常时只记日志、不阻断启动——否则 appVersion 不推进，
  // 每次启动都在同一步崩，陷入永久崩溃循环把用户锁在数据外。步骤幂等，下次启动重试。
  try {
    await VersionMigrator.run();
  } catch (e, s) {
    logger.e('version migration failed', error: e, stackTrace: s);
  }

  // ── 3. 四条互不依赖的初始化，并行发起（在阶段 4 收拢）。
  // 三条 future 各自兜底：它们在创建与 await 之间隔着阶段 4 的 await，不兜底的话
  // 失败会先被当成未处理异步错误报给 PlatformDispatcher.onError、再在收拢处抛第二次。
  unawaited(_platFormOption());
  // 主题：动态取色（平台通道）+ 自定义字体装载（FontLoader 读文件）。
  // 失败回落默认主题（未 buildTheme 时 lightTheme getter 自带 buildMuiTheme 兜底）。
  final themeFuture = () async {
    try {
      final font = await FontRepository.get().getActiveFont();
      await ThemeManager().buildTheme(customFont: font?.themeDescriptor);
    } catch (e, s) {
      logger.e(
        'theme init failed, fallback to default',
        error: e,
        stackTrace: s,
      );
      try {
        await ThemeManager().buildTheme();
      } catch (_) {}
    }
  }();
  // 复数解析器只要在 runApp（第一次取串）之前登记上即可，与 setLocale 的先后无关；
  // 串行是因为两者都在改 LocaleSettings 的同一份 translationMap。失败留 base 语种。
  final localeFuture = () async {
    try {
      await setupPluralResolvers();
      await applyStoredLanguage();
    } catch (e, s) {
      logger.e('locale init failed, staying on base', error: e, stackTrace: s);
    }
  }();
  // 强制迁移闸门探测：存在旧格式日记时路由 redirect 把一切目的地引到迁移页，故必须
  // 在 buildRouter 之前完成。探测失败按无迁移放行（读路径本就能即时转换渲染旧格式，
  // 只是不落库），别把启动卡死。排在版本迁移之后：探测读的是迁移可能刚改写过的日记。
  final migrationGateFuture = () async {
    try {
      await EditorMigrationService.refreshRequiresMigration();
    } catch (e, s) {
      logger.e('migration gate probe failed', error: e, stackTrace: s);
    }
  }();
  // 同步后端装载：按 KV `syncProvider` 换持，顺带把两个后端的配置（KV / SecureKV）
  // 读进进程内缓存。「什么时候按 KV 换持」是编排不是接线，故由组合根显式调；
  // 排在版本迁移之后，读到的是迁移后的配置。
  // fail-open：SecureKV（Keystore 故障 / 设备锁定）抛出时只记日志——后端留空是
  // 受支持状态（watcher 两处入口都有 hasBackend 守卫），同步暂不可用好过启动炸死，
  // 与 AppLockPin._read 的取舍同口径。
  final syncBackendFuture = () async {
    try {
      await RemoteSyncRegistry.get().reload();
    } catch (e, s) {
      logger.e('sync backend reload failed', error: e, stackTrace: s);
    }
  }();

  // ── 4. 唤醒长驻服务与启动期维护。
  await syncBackendFuture;
  // 显式 start，排在版本迁移与后端装载之后。刻意不用 @PostConstruct——那会让
  // watcher 在容器装配当场醒来，赶在迁移之前，迁移写出的行就被回声推给云端了。
  getIt<AutoSyncWatcher>().start();
  runStartupMaintenance();
  await Future.wait([themeFuture, localeFuture, migrationGateFuture]);

  // ── 5. 系统 UI：沉浸式 + 透明导航栏 + 方向锁。
  SystemChrome.setEnabledSystemUIMode(.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  applyDeviceOrientationLock();
}

Future<void> _platFormOption() async {
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
}

/// 全仓 provider 的重试策略。riverpod 3 的默认策略会对非 Error 异常指数退避重试
/// 10 次（约 38 秒），期间 UI 停在 loading——本仓 provider 的失败源几乎全是本地
/// 库 / 钥匙串，重试不会让它们变好，只是把报错拖成半分钟的空白。收紧为：最多
/// 2 次（300/600ms），Error 不重试（Isar 的 IsarError 是 Error 子类，天然豁免）。
Duration? _providerRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  if (error is Error) return null;
  return Duration(milliseconds: 300 * (retryCount + 1));
}

String _resolveInitialLocation() {
  // AppLockPin.load() 已在 _initSystem 里跑过，这里读的是进程内那份。
  if (AppLockPin.enabled.value) return '/lock';
  if (MoodiaryKVs.firstStart.get() == true) return '/start';
  return '/';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 错误处理器在 _initSystem 之前装：初始化阶段的异常也要被记录，装在后面
  // 等于启动期崩溃全体失聪（AppLogger.configure 之前只进控制台，配置后自动落盘）。
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

  // 启动失败的最后防线：任何一步抛出都不能停在启动图——那对用户等于变砖。
  // 兜底页零依赖（slang / 主题 / 容器此刻可能正是坏的那一环）。
  try {
    await _initSystem();
    buildRouter(initialLocation: _resolveInitialLocation());
  } catch (e, s) {
    logger.f('bootstrap failed', error: e, stackTrace: s);
    runApp(BootFailurePage(error: e, stackTrace: s));
    return;
  }

  // App 的字串走 slang 的 `TranslationProvider`（切语言自动重建整棵树）。mui 自己那
  // 十来个通用词不在这里——它是被 import 的包，走 `Localizations`，挂在下面的
  // `localizationsDelegates` 里。
  runApp(
    TranslationProvider(
      child: const ProviderScope(retry: _providerRetry, child: Moodiary()),
    ),
  );
}

class Moodiary extends ConsumerWidget {
  const Moodiary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.common.appName,
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
              // 「立即锁定」观察器：lock + lockNow 开启时退后台压锁屏页。
              // 透明包装、不渲染任何内容，挂在 builder 里保证覆盖所有路由。
              child: AppLockObserver(
                child: FlutterSmartDialog.init()(context, child!),
              ),
            ),
          ),
        );
      },
      theme: settings.lightTheme,
      darkTheme: settings.darkTheme,
      locale: TranslationProvider.of(context).flutterLocale,
      themeMode: settings.themeMode,
      // **必须用 material_ui 自带的 GlobalMaterialLocalizations**（`delegates`
      // 里已含 cupertino/widgets 两条）：flutter_localizations 的同名类给出的是
      // **legacy** MaterialLocalizations 类型，material_ui 的 widget 认不得它，
      // 中文下会退化成「locale zh is not supported」并让日期选择器一类直接抛。
      // legacy 子树的那份由根部的 MaterialUiCompatibilityBridge 自己注入。
      //
      // mui 的通用词也在这条链上——它是被 import 的包，不该要求宿主知道它内部用了
      // slang。漏了这一条不会崩，只会让那十来个词回落到 base 语种，debug 下
      // `MuiLocalizations.of` 会断言。App 自己的字串走 runApp 里的 TranslationProvider。
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        GlobalMuiLocalizations.delegate,
      ],
      supportedLocales: AppLocaleUtils.supportedLocales,
    );
  }
}
