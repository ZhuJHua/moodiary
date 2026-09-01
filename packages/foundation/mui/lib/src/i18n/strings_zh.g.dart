///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef MuiLocalizationsDataZh = MuiLocalizationsData; // ignore: unused_element
class MuiLocalizationsData with BaseTranslations<MuiLocale, MuiLocalizationsData> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [MuiLocale.build] is preferred.
	MuiLocalizationsData({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<MuiLocale, MuiLocalizationsData>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: MuiLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  );

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<MuiLocale, MuiLocalizationsData> $meta;

	late final MuiLocalizationsData _root = this; // ignore: unused_field

	MuiLocalizationsData $copyWith({TranslationMetadata<MuiLocale, MuiLocalizationsData>? meta}) => MuiLocalizationsData(meta: meta ?? this.$meta);

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

	/// zh: '已配置'
	String get configured => '已配置';

	/// zh: '未配置'
	String get notConfigured => '未配置';

	/// zh: '输入'
	String get input => '输入';

	/// zh: '保存'
	String get save => '保存';
}
