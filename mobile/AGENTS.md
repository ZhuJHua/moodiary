# Mobile: the composition root

Composition-root details for dependency injection, bootstrap, and app mounting.

## Dependency injection

- `lib/main.dart` wraps `AppStartupWidget` in a standard Riverpod 3 `ProviderScope(retry: (_, _) => null, overrides: buildMobilePortOverrides())`, above the navigator and all routes.
- `lib/app/di/overrides.dart` binds `filePickerProvider`, `heifDecoderProvider`, `notificationPermissionProvider`, `diaryShareHandlerProvider`, `videoPlayerPortFactoryProvider`, `videoSurfaceBuilderProvider` and `videoAmbientPortFactoryProvider`. It also wires the HTTP error toast via `httpClientProvider`, backup via `backupArchiveProvider` and legacy export via `legacyDataExporterProvider`. Verify all ten in `test/app/di/port_overrides_test.dart`, not with runtime startup assertions.
- `lib/app/di/app_startup.dart` owns single-shot offline `appStartupProvider`. Initialize platform directories, secure storage and MMKV, load the app lock, then await the database and sync logger before probing legacy state. Initialize locale, then theme alongside migration-gated data startup, and prepare `appRouterProvider` (`lib/app/router/router.dart`). On success `_EagerInitialization` keeps the watchers subscribed and the app watches the router.
- On failure `BootFailurePage` offers copyable error/stack details, the log path when available, and `resetAllData`, not an in-process retry. In `lib/app/di/bootstrap.dart`, reset checks `ref.exists(moodiaryDatabaseAsyncProvider)` before reading: never create a database just to erase it. If opening failed or never started, delete its files. If clearing an open database fails, dispose existing watchers, close it and delete its files. If the database still cannot be erased, throw before clearing KV or SecureKV (including the app-lock PIN).

## App theme and localization

- Keep `MaterialUiCompatibilityBridge` in `MaterialApp.builder`, outside `FlutterSmartDialog.init()`, so dialog overlays receive the compatibility theme.
- Use `material_ui`'s `GlobalMaterialLocalizations.delegates` from the mui barrel, together with `GlobalMuiLocalizations.delegate`; do not substitute the same-named delegates from `flutter_localizations`.
- Preserve both slang's `TranslationProvider` for app strings and Flutter's delegate chain for mui strings.
