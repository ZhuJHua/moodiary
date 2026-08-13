///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'mui_strings.g.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';

// Path: <root>
class MuiTranslationsEn extends MuiTranslations with BaseTranslations<MuiAppLocale, MuiTranslations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [MuiAppLocale.build] is preferred.
	MuiTranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<MuiAppLocale, MuiTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: MuiAppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<MuiAppLocale, MuiTranslations> $meta;

	late final MuiTranslationsEn _root = this; // ignore: unused_field

	@override 
	MuiTranslationsEn $copyWith({TranslationMetadata<MuiAppLocale, MuiTranslations>? meta}) => MuiTranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override String get ok => 'OK';
	@override String get cancel => 'Cancel';
	@override String get back => 'Back';
	@override String get colorPickerTitle => 'Pick a color';
	@override String get toastLoading => 'Loading';
	@override String get toastSuccess => 'Success';
	@override String get toastError => 'Error';
	@override String get configured => 'Configured';
	@override String get notConfigured => 'Not configured';
	@override String get input => 'Enter';
	@override String get save => 'Save';
}
