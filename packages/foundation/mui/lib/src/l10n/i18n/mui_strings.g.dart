/// Generated file. Do not edit.
///
/// Source: lib/src/l10n/i18n
/// To regenerate, run: `dart run slang`

// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

import 'mui_strings_en.g.dart' deferred as l_en;
part 'mui_strings_zh.g.dart';

/// Supported locales.
///
/// Usage:
/// - LocaleSettings.setLocale(MuiAppLocale.zh) // set locale
/// - Locale locale = MuiAppLocale.zh.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == MuiAppLocale.zh) // locale check
enum MuiAppLocale with BaseAppLocale<MuiAppLocale, MuiTranslations> {
	zh(languageCode: 'zh'),
	en(languageCode: 'en');

	const MuiAppLocale({
		required this.languageCode,
		this.scriptCode, // ignore: unused_element, unused_element_parameter
		this.countryCode, // ignore: unused_element, unused_element_parameter
	});

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;

	@override
	Future<MuiTranslations> build({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) async {
		switch (this) {
			case MuiAppLocale.zh:
				return MuiTranslationsZh(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case MuiAppLocale.en:
				await l_en.loadLibrary();
				return l_en.MuiTranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	@override
	MuiTranslations buildSync({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) {
		switch (this) {
			case MuiAppLocale.zh:
				return MuiTranslationsZh(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case MuiAppLocale.en:
				return l_en.MuiTranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	/// Gets current instance managed by [LocaleSettings].
	MuiTranslations get translations => LocaleSettings.instance.getTranslations(this);
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of muiL10n).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = muiL10n.someKey.anotherKey;
MuiTranslations get muiL10n => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final muiL10n = MuiTranslations.of(context); // Get muiL10n variable.
/// String a = muiL10n.someKey.anotherKey; // Use muiL10n variable.
class TranslationProvider extends BaseTranslationProvider<MuiAppLocale, MuiTranslations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<MuiAppLocale, MuiTranslations> of(BuildContext context) => InheritedLocaleData.of<MuiAppLocale, MuiTranslations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.muiL10n.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	MuiTranslations get muiL10n => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<MuiAppLocale, MuiTranslations> {
	LocaleSettings._() : super(
		utils: AppLocaleUtils.instance,
		lazy: true,
	);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static MuiAppLocale get currentLocale => instance.currentLocale;
	static Stream<MuiAppLocale> getLocaleStream() => instance.getLocaleStream();
	static Future<MuiAppLocale> setLocale(MuiAppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<MuiAppLocale> setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<MuiAppLocale> useDeviceLocale() => instance.useDeviceLocale();
	static Future<void> setPluralResolver({String? language, MuiAppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);

	// synchronous versions
	static MuiAppLocale setLocaleSync(MuiAppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocaleSync(locale, listenToDeviceLocale: listenToDeviceLocale);
	static MuiAppLocale setLocaleRawSync(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRawSync(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static MuiAppLocale useDeviceLocaleSync() => instance.useDeviceLocaleSync();
	static void setPluralResolverSync({String? language, MuiAppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolverSync(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<MuiAppLocale, MuiTranslations> {
	AppLocaleUtils._() : super(
		baseLocale: MuiAppLocale.zh,
		locales: MuiAppLocale.values,
	);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static MuiAppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static MuiAppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static MuiAppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}
