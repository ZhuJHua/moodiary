# mobile —— 组合根

根 CLAUDE.md 的 DI 与 mui 两节里属于组合根（di / bootstrap / MaterialApp 挂载）的细节收在这里。

### DI —— get_it + injectable

**绑定的注解落在实现类上**（`@Singleton(as:)` / `@LazySingleton(as:)` / `@Injectable(as:)`）：
storage / http / assistant / sync 四个包各自是一份 **micro-package**（`lib/injectable.dart` 里的
`@InjectableInit.microPackage()` → 生成 `injectable.module.dart`），由 app 侧
`mobile/lib/app/di/di.dart` 一处经 `externalPackageModulesBefore` 挂载。**全仓只有一份
`configureDependencies`**：不指定 initializerName（默认 `init`），也没有 generateForDir
（默认扫全包 —— 单份 config 不存在「两份互扫同一片源码、同一注解各注册一次」的问题）。
storage 列最前，它的两个 preResolve 是别人的地基；两个存储的 `init` 已折进
`@FactoryMethod(preResolve: true)` 的 create 工厂，**SecureKV → KV 的次序因此是类型边**
（`MmkvKVStorage.create(ISecureKVStorage)`），不再靠调用顺序守。
`@module` 只剩 `AppModule.httpClient` 一个方法：`IHttpClient` 的 `onError` 要接 app 的 toast，
这种构造用类注解表达不出来。

**启动阶段属于 main 的引导编排，不属于容器**：路径/日志与重置在
`mobile/lib/app/di/bootstrap.dart`，序列在 `main.dart` 的 `_initSystem`。版本迁移跑完后由组合根
显式调 `RemoteSyncRegistry.reload()`（装载同步后端）与 `AutoSyncWatcher.start()`。
**`@PostConstruct` 是刻意不用的**：那会让 watcher 在容器装配当场醒来、赶在迁移之前，
迁移写出的行就被当成本地变更回声推给云端。

改了注解**必须跑 `dart tool/task.dart build-runner`**（生成物是提交的；micro-package 的
`*.module.dart` 出炉不带格式，该任务末尾会统一 format 一遍）。业务代码不手写
`getIt.register*`；`IRemoteSyncBackend` 的运行时切换不进容器、走 `RemoteSyncRegistry`——
容器只管生命周期内不变的接线。

**双组合根记档（desktop 立项时照此办）**：desktop 建自己的 `desktop/lib/app/di/di.dart`
（同样四个 externalPackageModulesBefore + 自己的 `@InjectableInit`），只需重新提供两条
app 侧绑定 —— `IHttpClient`（照抄 AppModule.httpClient，onError 接桌面的通知方式）与
`IFilePicker`（走系统对话框）。**不用 `@Environment` 分平台**：environment 的语义是
「同一份被扫源码按标签筛」，要求两端实现类同包，会把 moodiary_picker/wechat 系依赖
塞给桌面；两个 app 本就是两个包、两份 config，天然互不干扰（injectable 的根 config 只
收本包 generateForDir 下的 .injectable.json）。`@Environment('test')` 也已评估否决：
替身住在各包 test/ 下，generateForDir 默认只扫 lib，注解够不着。缺绑定由
`configureDependencies` 里的 `_assertRequiredBindings` 在启动第一秒报出——那份清单就是
组合根的必填表。

> **injectable 不从 `moodiary_di` barrel 导出**（问过一次）：生成物头部是生成器写死的
> `import 'package:injectable/...'`，各包的 pubspec 声明躲不掉，barrel 只能藏一行手写
> import；generator 是 dev dep 本就每包一份。moodiary_di 只 own 运行时的 get_it 实例，
> 注解是构建期契约——与 freezed/riverpod 注解各包自留同一处理。

### mui 共存期 —— 挂在 MaterialApp 上的部分

**共存期的两个硬点**：

1. `MaterialUiCompatibilityBridge` 挂在 `MaterialApp.builder`、**套在 `FlutterSmartDialog.init()`
   外面**（init 自建 Overlay，toast/loading 是与 child 平级的兄弟 entry）。它只映射
   platform / visualDensity / colorScheme / textTheme 四项，**25 个组件子主题不过桥** ——
   第三方 widget 保留我们的配色与排版，但组件级样式回落 Material 默认。它出厂即
   `@Deprecated`，依赖全部迁移后摘掉。
2. `localizationsDelegates` 里的 material 那份**必须是 material_ui 自带的
   `GlobalMaterialLocalizations.delegates`**（已含 cupertino/widgets）。不能用
   `flutter_localizations` 的同名类：那份给出 **legacy** 类型，material_ui 的 widget
   认不得，中文下会退化并让日期选择器一类直接抛。App 自己的文案走 slang 的
   `TranslationProvider`，不在这条链上；mui 的通用词在（`GlobalMuiLocalizations.delegate`）。
> **路由不再需要任何 workaround（go_router 18.0.0 起）。** go_router 靠
> `findAncestorWidgetOfExactType<MaterialApp>()` 猜宿主类型，17.5.0 及以前认的是 legacy
> `MaterialApp`，而我们挂的是 material_ui 的同名新类——类型不同，探测恒空、落到 WidgetsApp
> 分支，于是页面被包成 `NoTransitionPage`（切页没动画）、hero 拿到不带 `createRectTween`
> 的裸 `HeroController`（弧线退成直线）、错误页落到无样式的 widgets 版 `ErrorScreen`。
> 18.0.0 把内部 import 换成了 `material_ui` / `cupertino_ui`，三样一起恢复正常，
> 当年自接的 `MoodiaryGoRoute` / `MHero` / `errorPageBuilder` 已全部删除：**裸 `GoRoute`
> 与裸 `Hero` 就是对的**。`route_error_page.dart` 留着只是因为自带那页英文写死，
> 现在走 `errorBuilder`。

> 官方的 `dart fix --code=migrate_design_widgets` **当前不生效**：转换规则在 SDK 里
> （`fix_data/fix_material/fix_material.yaml`），但 `material.dart` 还没标 `@Deprecated`，
> 数据驱动 fix 挂不上诊断。实测加了 material_ui 依赖也一样 `Nothing to fix!`。

