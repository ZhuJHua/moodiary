# mobile: the composition root

The composition-root details (di / bootstrap / MaterialApp mounting) from the root CLAUDE.md's DI and mui sections.

### DI: get_it + injectable

**Binding annotations go on the implementation classes** (`@Singleton(as:)` / `@LazySingleton(as:)` / `@Injectable(as:)`). storage / http / ml / data / assistant / sync / editor / theme are each a **micro-package** (`@InjectableInit.microPackage()` in `lib/injectable.dart` → `injectable.module.dart`), all eight mounted in one place by `mobile/lib/app/di/di.dart` through `externalPackageModulesBefore`. **The repo has exactly one `configureDependencies`**: no initializerName (defaults to `init`), no generateForDir, so nothing can be registered twice. storage is listed first because its two preResolves are everyone else's foundation, and both storages' `init` sits in the `@FactoryMethod(preResolve: true)` create factory, making **SecureKV → KV a type edge** (`MmkvKVStorage.create(ISecureKVStorage)`) rather than a call order. `@module` holds only `AppModule.httpClient` (its `onError` needs the app's toast) and `AppModule.database` (`@preResolve @singleton`, SQLite path from the composition root because moodiary_data does not know the file layout), since class annotations cannot express them. data's repositories are lazy singletons, so registering them ahead of the root config is harmless.

**Startup is main's bootstrap orchestration, not the container's**: paths / logging / reset in `mobile/lib/app/di/bootstrap.dart`, sequence in `_initSystem` in `main.dart`. After the version migration the composition root calls `activateSyncProvider()` (backend chosen by KV, its config read asynchronously on first use) and `AutoSyncWatcher.start()`. **`@PostConstruct` is deliberately unused**, because it wakes the watcher at container assembly, ahead of the migration, and the migrated rows then get pushed as local-change echoes.

Changed annotations **require `dart tool/task.dart build-runner`** (output is committed, and the task formats the unformatted `*.module.dart`). Never hand-write `getIt.register*`: `IRemoteSyncBackend` switches through the hand-written session scope `activateSyncProvider`, because the container only owns wiring that is fixed for the lifetime.

**Dual composition root, for the record (follow this when desktop starts)**: desktop gets its own `desktop/lib/app/di/di.dart` (same eight externalPackageModulesBefore plus its own `@InjectableInit`) plus the non-micro-package bindings of `_assertRequiredBindings`, currently four: `IHttpClient` (copy AppModule.httpClient, onError to the desktop notification), `MoodiaryDatabase` (copy AppModule.database, desktop path), `IFilePicker` (system dialog), `IHeifDecoder` (may return null and fall through to the existing degradation). **Do not split platforms with `@Environment`**, because it filters one scanned source set by tag and therefore needs both implementations in one package, which would push moodiary_picker and the wechat dependencies onto desktop. `@Environment('test')` is rejected too, because doubles live in each package's test/ while generateForDir scans only lib. Missing bindings are reported by `_assertRequiredBindings` in the first second of startup, and that list is the composition root's required-bindings table.

> **injectable is not exported from the `moodiary_di` barrel**, because the generator hard-codes `import 'package:injectable/...'` into its output so every pubspec must declare it anyway. moodiary_di owns only the runtime get_it instance; annotations are a build-time contract, same as freezed / riverpod.

### mui coexistence period: the part mounted on MaterialApp

**Two hard points during coexistence**:

1. `MaterialUiCompatibilityBridge` sits on `MaterialApp.builder` and **wraps `FlutterSmartDialog.init()`**, whose own Overlay makes toast/loading siblings of child. It maps only platform / visualDensity / colorScheme / textTheme, so **the 25 component sub-themes do not cross**: third-party widgets keep our colors and typography but fall back to Material defaults for component styling. It ships `@Deprecated` and goes once every dependency has migrated.
2. The material entry in `localizationsDelegates` **must be material_ui's own `GlobalMaterialLocalizations.delegates`** (cupertino/widgets included), because the same-named class from `flutter_localizations` hands out the **legacy** type that material_ui's widgets do not recognize, degrading Chinese and making the date picker throw. App strings go through slang's `TranslationProvider`, off this chain; mui's generic words are on it (`GlobalMuiLocalizations.delegate`).
> **A bare `GoRoute` and a bare `Hero` are correct, do not wrap them.** go_router finds its host with `findAncestorWidgetOfExactType<MaterialApp>()`, and since 18.0.0 that is material_ui's `MaterialApp`, so transitions, hero arcs and the error page all work; 17.x knew only the legacy `MaterialApp` and degraded to the WidgetsApp branch. `route_error_page.dart` exists and goes through `errorBuilder` because the built-in page hard-codes English.

> The official `dart fix --code=migrate_design_widgets` **does nothing today**: the rules are in the SDK
(`fix_data/fix_material/fix_material.yaml`), but `material.dart` is not `@Deprecated` yet, so the data-driven fix has no diagnostic to attach to. Adding material_ui still gives `Nothing to fix!`.

