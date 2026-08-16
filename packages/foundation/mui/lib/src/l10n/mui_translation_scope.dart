import 'package:material_ui/material_ui.dart';

import 'i18n/mui_strings.g.dart' as i18n;

/// mui 那十来个通用词的 provider，宿主 App 挂在根上即可（`runApp` 里、`MaterialApp` 之上）。
///
/// 为什么要包一层而不是直接导出生成的 `TranslationProvider`：slang 生成的
/// `TranslationProvider` / `LocaleSettings` / `AppLocaleUtils` 三个类名在生成器里是
/// 硬编码的，只有 `MuiTranslations` / `MuiAppLocale` / `muiL10n` 可配。裸导出会跟
/// App 自己那份（moodiary_l10n）撞名，宿主同时 import 两个包就是 ambiguous import。
///
/// 不需要在宿主侧初始化 mui 的语种：语种真源 `GlobalLocaleState` 是跨包共享的单例，
/// 而 slang_flutter 的 `_GlobalKeyHandler` 同样是进程级单例 —— App 调一次
/// `LocaleSettings.setLocale`，它会遍历所有已注册的 TranslationProvider（含这棵）
/// 逐个 `updateState`。
///
/// **前提是 `slang.yaml` 里的 `lazy: false`**：宿主在 `runApp` 之前就切语种，那时
/// 本 widget 还没构造、GlobalKey 还没注册，那一轮通知谁也收不到；若产物是默认的
/// deferred，这棵树就再没机会加载非 base 语种，英文一路回落成中文。
/// 闸门在 `test/l10n_test.dart`。
class MuiTranslationScope extends StatelessWidget {
  const MuiTranslationScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => i18n.TranslationProvider(child: child);
}
