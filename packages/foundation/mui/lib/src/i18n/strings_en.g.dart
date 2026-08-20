///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class MuiLocalizationsDataEn extends MuiLocalizationsData with BaseTranslations<MuiLocale, MuiLocalizationsData> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [MuiLocale.build] is preferred.
	MuiLocalizationsDataEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<MuiLocale, MuiLocalizationsData>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: MuiLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<MuiLocale, MuiLocalizationsData> $meta;

	late final MuiLocalizationsDataEn _root = this; // ignore: unused_field

	@override 
	MuiLocalizationsDataEn $copyWith({TranslationMetadata<MuiLocale, MuiLocalizationsData>? meta}) => MuiLocalizationsDataEn(meta: meta ?? this.$meta);

	// Translations
	@override String get colorPickerTitle => 'Pick a color';
	@override String get toastLoading => 'Loading';
	@override String get toastSuccess => 'Success';
	@override String get toastError => 'Error';
	@override String get configured => 'Configured';
	@override String get notConfigured => 'Not configured';
	@override String get input => 'Enter';
}
