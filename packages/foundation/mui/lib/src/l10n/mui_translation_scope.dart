import 'package:material_ui/material_ui.dart';

import 'i18n/mui_strings.g.dart' as i18n;

/// mui 那十来个通用词的 provider，宿主 App 挂在根上即可（`runApp` 里、`MaterialApp` 之上）。
///
/// 为什么要包一层而不是直接导出生成的 `TranslationProvider`：slang 生成的
/// `TranslationProvider` / `LocaleSettings` / `AppLocaleUtils` 三个类名在生成器里是
/// 硬编码的，只有 `MuiTranslations` / `MuiAppLocale` / `muiL10n` 可配。裸导出会跟
/// App 自己那份（moodiary_l10n）撞名，宿主同时 import 两个包就是 ambiguous import。
///
/// 不需要在宿主侧初始化 mui 的语种：slang 的 `GlobalLocaleState` 是跨包共享的单例，
/// App 调一次 `LocaleSettings.setLocale`，这棵树跟着刷新。
class MuiTranslationScope extends StatelessWidget {
  const MuiTranslationScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => i18n.TranslationProvider(child: child);
}
