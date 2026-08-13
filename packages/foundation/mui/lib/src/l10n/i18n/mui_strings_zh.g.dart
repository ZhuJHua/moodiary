///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'mui_strings.g.dart';

// Path: <root>
typedef MuiTranslationsZh = MuiTranslations; // ignore: unused_element
class MuiTranslations with BaseTranslations<MuiAppLocale, MuiTranslations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final muiL10n = MuiTranslations.of(context);
	static MuiTranslations of(BuildContext context) => InheritedLocaleData.of<MuiAppLocale, MuiTranslations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [MuiAppLocale.build] is preferred.
	MuiTranslations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<MuiAppLocale, MuiTranslations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: MuiAppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  );

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<MuiAppLocale, MuiTranslations> $meta;

	late final MuiTranslations _root = this; // ignore: unused_field

	MuiTranslations $copyWith({TranslationMetadata<MuiAppLocale, MuiTranslations>? meta}) => MuiTranslations(meta: meta ?? this.$meta);

	// Translations

	/// zh: '确认'
	String get ok => '确认';

	/// zh: '取消'
	String get cancel => '取消';

	/// zh: '返回'
	String get back => '返回';

	/// zh: '选择颜色'
	String get colorPickerTitle => '选择颜色';

	/// zh: '加载中'
	String get toastLoading => '加载中';

	/// zh: '成功'
	String get toastSuccess => '成功';

	/// zh: '出错了'
	String get toastError => '出错了';
}
