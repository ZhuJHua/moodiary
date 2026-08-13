/// 组件取通用词的内部入口：`context.muiL10n.ok`。
///
/// 只放出 extension 与翻译类，**不放出**生成文件里那三个硬编码名字
/// （TranslationProvider / LocaleSettings / AppLocaleUtils）—— 它们与 App 自己那份
/// slang 产物同名。对外的挂载入口是 `MuiTranslationScope`。
library;

export 'i18n/mui_strings.g.dart'
    show BuildContextTranslationsExtension, MuiTranslations;
