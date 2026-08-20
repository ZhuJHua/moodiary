/// Moodiary 国际化包（foundation）：slang 生成的 [Translations]。
///
/// 包与目录叫 i18n（能力），取串的入口叫 l10n（当前语种的具体文案）。
///
/// 取串两种写法，按有没有 `BuildContext` 分：
/// - widget 里用 `context.l10n.xxx` —— 依赖 `TranslationProvider`，切语言自动重建；
/// - service / 导出 / 回调这类拿不到 context 的地方用顶层的 `l10n.xxx`（不会重建）。
///
/// 语言的当前值由 slang 的 `GlobalLocaleState` 单例持有，KV 里只存用户偏好枚举。
library;

import 'i18n/strings.g.dart';

export 'i18n/strings.g.dart';

/// 告诉 slang「中文只有一种形式」。
///
/// 中文本来没有复数，是**英文**要分单复数（`1 entry` / `2 entries`），而 slang 要求同一个
/// 键在所有语种里节点形状一致，中文那侧因此也被拖进复数机制、只写一个 `other`。渲染时
/// slang 会去查 zh 的复数规则——它的内置表里只有 ar cs de en es fr he it ja pl ru sv uk vi，
/// 查不到就**每渲染一次打一条 error 日志**再走兜底（兜底结果是对的，只是吵）。
///
/// 在**访问任何翻译之前**调用即可（作者原话，slang#223），与 `setLocale` 的先后无关 ——
/// 它按 locale 重建翻译实例，但不会通知已挂载的 `TranslationProvider`，所以放在 `runApp`
/// 之前。只登记 zh：其余语种用 slang 内置的 CLDR 规则。
///
/// 分支形状照抄 slang 自己的兜底（`plural_resolver_map.dart` 的 `_defaultResolver`）：
/// 行为与不注册时**完全一致**，只是不再刷屏。不写成 `other!` 是因为漏写 `other` 的文案
/// 会变成线上的空断言崩溃，退化成数字至少还看得见。
Future<void> setupPluralResolvers() => LocaleSettings.setPluralResolver(
  language: 'zh',
  // CLDR 里中文只有 other；zero / one 只有在文案自己写了的时候才轮得到。
  cardinalResolver: (n, {zero, one, two, few, many, other}) => switch (n) {
    0 => zero ?? other ?? '$n',
    1 => one ?? other ?? '$n',
    _ => other ?? '$n',
  },
  ordinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '$n',
);
