/// Generated file. Do not edit.
///
/// Source: lib/src/i18n
/// To regenerate, run: `dart run slang`

// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

import 'strings_en.g.dart' as l_en;
part 'strings_zh.g.dart';

/// Supported locales.
///
/// Usage:
/// - LocaleSettings.setLocale(MuiLocale.zh) // set locale
/// - Locale locale = MuiLocale.zh.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == MuiLocale.zh) // locale check
enum MuiLocale with BaseAppLocale<MuiLocale, MuiLocalizationsData> {
	zh(languageCode: 'zh'),
	en(languageCode: 'en');

	const MuiLocale({
		required this.languageCode,
		this.scriptCode, // ignore: unused_element, unused_element_parameter
		this.countryCode, // ignore: unused_element, unused_element_parameter
	});

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;

	@override
	Future<MuiLocalizationsData> build({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) async {
		return buildSync(
			overrides: overrides,
			cardinalResolver: cardinalResolver,
			ordinalResolver: ordinalResolver,
		);
	}

	@override
	MuiLocalizationsData buildSync({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) {
		switch (this) {
			case MuiLocale.zh:
				return MuiLocalizationsDataZh(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case MuiLocale.en:
				return l_en.MuiLocalizationsDataEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<MuiLocale, MuiLocalizationsData> {
	AppLocaleUtils._() : super(
		baseLocale: MuiLocale.zh,
		locales: MuiLocale.values,
	);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static MuiLocale parse(String rawLocale) => instance.parse(rawLocale);
	static MuiLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static MuiLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}
