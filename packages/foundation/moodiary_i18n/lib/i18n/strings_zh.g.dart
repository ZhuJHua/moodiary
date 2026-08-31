///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsZh = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final l10n = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  );

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$zh app = Translations$app$zh.internal(_root);
	late final Translations$assistant$zh assistant = Translations$assistant$zh.internal(_root);
	late final Translations$common$zh common = Translations$common$zh.internal(_root);
	late final Translations$diary$zh diary = Translations$diary$zh.internal(_root);
	late final Translations$editor$zh editor = Translations$editor$zh.internal(_root);
	late final Translations$export$zh export = Translations$export$zh.internal(_root);
	late final Translations$lock$zh lock = Translations$lock$zh.internal(_root);
	late final Translations$media$zh media = Translations$media$zh.internal(_root);
	late final Translations$onboarding$zh onboarding = Translations$onboarding$zh.internal(_root);
	late final Translations$picker$zh picker = Translations$picker$zh.internal(_root);
	late final Translations$share$zh share = Translations$share$zh.internal(_root);
	late final Translations$sync$zh sync = Translations$sync$zh.internal(_root);
	late final Translations$ui$zh ui = Translations$ui$zh.internal(_root);
}

// Path: app
class Translations$app$zh {
	Translations$app$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '主题色'
	String get accentTitle => '主题色';

	/// zh: '默认'
	String get accentNeutral => '默认';

	/// zh: '壁纸取色'
	String get accentSystem => '壁纸取色';

	/// zh: '自定义配色'
	String get accentCustomTitle => '自定义配色';

	/// zh: '强调'
	String get accentGroupAccent => '强调';

	/// zh: '表面'
	String get accentGroupSurface => '表面';

	/// zh: '语义'
	String get accentGroupSemantic => '语义';

	/// zh: '选取的颜色'
	String get accentSeed => '选取的颜色';

	/// zh: '语言'
	String get language => '语言';

	/// zh: '日记'
	String get homeNavigatorDiary => '日记';

	/// zh: '助手'
	String get homeNavigatorAssistant => '助手';

	/// zh: '新建日记'
	String get homePageAddDiaryButton => '新建日记';

	/// zh: '分类已被删除，已切回全部'
	String get categoryDeletedReset => '分类已被删除，已切回全部';

	/// zh: '设置'
	String get homeNavigatorSetting => '设置';

	/// zh: '跟随系统'
	String get languageSystem => '跟随系统';

	/// zh: '简体中文'
	String get languageSimplifiedChinese => '简体中文';

	/// zh: 'English'
	String get languageEnglish => 'English';

	/// zh: '设置'
	String get settingsTitle => '设置';

	/// zh: '数据'
	String get sectionData => '数据';

	/// zh: '回收站'
	String get recycle => '回收站';

	/// zh: '数据同步与备份'
	String get syncBackup => '数据同步与备份';

	/// zh: '分类管理'
	String get categoryManager => '分类管理';

	/// zh: '足迹地图'
	String get mapTitle => '足迹地图';

	/// zh: '显示'
	String get sectionDisplay => '显示';

	/// zh: '日记设置'
	String get diarySettings => '日记设置';

	/// zh: '主题模式'
	String get themeMode => '主题模式';

	/// zh: '字体样式'
	String get fontStyle => '字体样式';

	/// zh: '隐私'
	String get sectionPrivacy => '隐私';

	/// zh: '后台隐私保护'
	String get backgroundPrivacy => '后台隐私保护';

	/// zh: '退到后台时遮罩内容'
	String get backgroundPrivacySubtitle => '退到后台时遮罩内容';

	/// zh: '更多'
	String get sectionMore => '更多';

	/// zh: '关于'
	String get about => '关于';

	/// zh: '第三方服务'
	String get services => '第三方服务';

	/// zh: '跟随系统'
	String get themeModeSystem => '跟随系统';

	/// zh: '浅色'
	String get themeModeLight => '浅色';

	/// zh: '深色'
	String get themeModeDark => '深色';

	/// zh: '已选 {count}'
	String homeSelected({required Object count}) => '已选 ${count}';

	/// zh: '删除所选日记？'
	String get homeDeleteTitle => '删除所选日记？';

	/// zh: '已选 {count} 篇，将移入回收站，可在回收站恢复。'
	String homeDeleteMessage({required Object count}) => '已选 ${count} 篇，将移入回收站，可在回收站恢复。';

	/// zh: '没有可删除的日记'
	String get homeNothingToDelete => '没有可删除的日记';

	/// zh: '已移入回收站（{count} 篇）'
	String homeMovedToRecycle({required Object count}) => '已移入回收站（${count} 篇）';

	/// zh: '检查更新'
	String get aboutCheckUpdate => '检查更新';

	/// zh: '当前已是最新版本'
	String get aboutUpToDate => '当前已是最新版本';

	/// zh: '源码仓库'
	String get aboutSource => '源码仓库';

	/// zh: '反馈 / 答疑'
	String get aboutFeedback => '反馈 / 答疑';

	/// zh: '赞助'
	String get aboutSponsor => '赞助';

	/// zh: '感谢您的考虑！'
	String get sponsorThanks => '感谢您的考虑！';

	/// zh: 'Moodiary 是开源软件，由开发者业余维护。如果您喜欢这款应用，可通过下面的链接支持作者继续维护。'
	String get sponsorBody => 'Moodiary 是开源软件，由开发者业余维护。如果您喜欢这款应用，可通过下面的链接支持作者继续维护。';

	/// zh: '爱发电'
	String get sponsorAfdian => '爱发电';

	/// zh: '字体'
	String get fontTitle => '字体';

	/// zh: '导入 ttf / otf 字体，长按可删除'
	String get fontImportSubtitle => '导入 ttf / otf 字体，长按可删除';

	/// zh: '预览'
	String get fontPreview => '预览';

	/// zh: '字号跟随系统设置，App 内不再单独提供'
	String get fontPreviewSubtitle => '字号跟随系统设置，App 内不再单独提供';

	/// zh: '系统'
	String get fontSystem => '系统';

	/// zh: '删除字体'
	String get fontDeleteTitle => '删除字体';

	/// zh: '确认删除字体「{name}」吗？'
	String fontDeleteMessage({required Object name}) => '确认删除字体「${name}」吗？';

	/// zh: '可变'
	String get fontVariable => '可变';

	/// zh: '添加'
	String get fontAdd => '添加';

	/// zh: '八月的忧愁'
	String get fontPreviewTitle => '八月的忧愁';

	/// zh: '黄水塘里游着白鸭， 高粱梗油青的刚高过头， 这跳动的心怎样安插， 田里一窄条路，八月里这忧愁？ 天是昨夜雨洗过的，山岗 照着太阳又留一片影； 羊跟着放羊的转进村庄， 一大棵树荫下罩着井，又像是心！ 从没有人说过八月什么话， 夏天过去了，也不到秋天。 但我望着田垄，土墙上的瓜， 仍不明白生活同梦怎样的连牵。'
	String get fontPreviewText => '黄水塘里游着白鸭，\n高粱梗油青的刚高过头，\n这跳动的心怎样安插，\n田里一窄条路，八月里这忧愁？\n天是昨夜雨洗过的，山岗\n照着太阳又留一片影；\n羊跟着放羊的转进村庄，\n一大棵树荫下罩着井，又像是心！\n从没有人说过八月什么话，\n夏天过去了，也不到秋天。\n但我望着田垄，土墙上的瓜，\n仍不明白生活同梦怎样的连牵。';

	/// zh: '日记偏好'
	String get diaryPrefsTitle => '日记偏好';

	/// zh: '编辑器'
	String get diaryPrefsEditor => '编辑器';

	/// zh: '首行缩进'
	String get firstLineIndent => '首行缩进';

	/// zh: '保存时自动归类'
	String get autoCategory => '保存时自动归类';

	/// zh: '根据上次写作位置 / 标签推测分类'
	String get autoCategorySubtitle => '根据上次写作位置 / 标签推测分类';

	/// zh: '展示写作时长'
	String get showWritingTime => '展示写作时长';

	/// zh: '展示字数统计'
	String get showWordCount => '展示字数统计';

	/// zh: '日记展示'
	String get diaryPrefsDisplay => '日记展示';

	/// zh: '列表卡片显示头图'
	String get cardHeaderImage => '列表卡片显示头图';

	/// zh: '基于封面动态配色'
	String get dynamicColor => '基于封面动态配色';

	/// zh: '媒体'
	String get diaryPrefsMedia => '媒体';

	/// zh: '图片优化'
	String get imageOptimize => '图片优化';

	/// zh: '压缩尺寸并统一转为 WebP；关闭则保存原图'
	String get imageOptimizeSubtitle => '压缩尺寸并统一转为 WebP；关闭则保存原图';

	/// zh: '天气'
	String get diaryPrefsWeather => '天气';

	/// zh: '保存日记时自动获取天气'
	String get autoWeather => '保存日记时自动获取天气';

	/// zh: '在此填入您自有的第三方服务凭证，启用 AI 助手、天气与地图等能力。所有凭证仅保存在本机。'
	String get servicesIntro => '在此填入您自有的第三方服务凭证，启用 AI 助手、天气与地图等能力。所有凭证仅保存在本机。';

	/// zh: 'AI 助手'
	String get servicesAssistant => 'AI 助手';

	/// zh: '和风天气'
	String get servicesQweather => '和风天气';

	/// zh: 'devapi.qweather.com 或自定义'
	String get servicesQweatherHostHint => 'devapi.qweather.com 或自定义';

	/// zh: '天地图'
	String get servicesTianditu => '天地图';

	/// zh: '已保存'
	String get servicesSaved => '已保存';

	/// zh: '保存失败，请重试'
	String get servicesSaveFailed => '保存失败，请重试';

	/// zh: '语义检索'
	String get semanticTitle => '语义检索';

	/// zh: '嵌入模型'
	String get semanticModelTitle => '嵌入模型';

	/// zh: '未启用'
	String get semanticStateOff => '未启用';

	/// zh: '下载中 {percent}%'
	String semanticDownloading({required Object percent}) => '下载中 ${percent}%';

	/// zh: '校验模型中…'
	String get semanticVerifying => '校验模型中…';

	/// zh: '启用语义检索'
	String get semanticEnableTitle => '启用语义检索';

	/// zh: '下载并启用'
	String get semanticEnableConfirm => '下载并启用';

	/// zh: '已启用，索引在后台构建'
	String get semanticEnabled => '已启用，索引在后台构建';

	/// zh: '启用失败'
	String get semanticEnableFailed => '启用失败';

	/// zh: '停用语义检索'
	String get semanticDisableTitle => '停用语义检索';

	/// zh: '停用后语义索引数据将被清除，已下载的模型文件保留，可随时重新启用。'
	String get semanticDisableMessage => '停用后语义索引数据将被清除，已下载的模型文件保留，可随时重新启用。';

	/// zh: '停用'
	String get semanticDisableConfirm => '停用';

	/// zh: '重建语义索引'
	String get semanticRebuildTitle => '重建语义索引';

	/// zh: '索引异常或长期未更新时使用'
	String get semanticRebuildSubtitle => '索引异常或长期未更新时使用';

	/// zh: '已重嵌 {count} 篇日记'
	String semanticRebuildDone({required Object count}) => '已重嵌 ${count} 篇日记';

	/// zh: '选择嵌入模型'
	String get semanticPickTitle => '选择嵌入模型';

	/// zh: '将下载 {size} 的模型文件并重建语义索引，全部推理与索引都在本机完成，日记内容不会上传。'
	String semanticActivateDownloadMessage({required Object size}) => '将下载 ${size} 的模型文件并重建语义索引，全部推理与索引都在本机完成，日记内容不会上传。';

	/// zh: '启用后将重建语义索引。'
	String get semanticActivateLocalMessage => '启用后将重建语义索引。';

	/// zh: '删除模型文件'
	String get semanticDeleteTitle => '删除模型文件';

	/// zh: '删除已下载的模型文件，之后可重新下载。'
	String get semanticDeleteMessage => '删除已下载的模型文件，之后可重新下载。';

	/// zh: '删除'
	String get semanticDeleteConfirm => '删除';

	/// zh: '多语言，含蓄表达也能召回'
	String get semanticDescQwen3 => '多语言，含蓄表达也能召回';

	/// zh: '心情建议'
	String get moodSuggestTitle => '心情建议';

	/// zh: '本地模型'
	String get moodSuggestModelTitle => '本地模型';

	/// zh: '选择模型'
	String get moodSuggestPickTitle => '选择模型';

	/// zh: '小型本地 LLM，理解 16 类心情与状态'
	String get moodSuggestDescQwen3 => '小型本地 LLM，理解 16 类心情与状态';

	/// zh: '启用心情建议'
	String get moodSuggestEnableTitle => '启用心情建议';

	/// zh: '将下载 {size} 的模型文件，写日记时在本机为你建议心情，日记内容不会上传。'
	String moodSuggestActivateDownloadMessage({required Object size}) => '将下载 ${size} 的模型文件，写日记时在本机为你建议心情，日记内容不会上传。';

	/// zh: '启用后写日记时将在本机为你建议心情。'
	String get moodSuggestActivateLocalMessage => '启用后写日记时将在本机为你建议心情。';

	/// zh: '已启用心情建议'
	String get moodSuggestEnabled => '已启用心情建议';

	/// zh: '停用心情建议'
	String get moodSuggestDisableTitle => '停用心情建议';

	/// zh: '停用后写日记不再自动建议心情，已下载的模型文件保留。'
	String get moodSuggestDisableMessage => '停用后写日记不再自动建议心情，已下载的模型文件保留。';

	/// zh: '使用天数'
	String get dashUseDays => '使用天数';

	/// zh: '总字数'
	String get dashWordCount => '总字数';

	/// zh: '分类数'
	String get dashCategoryCount => '分类数';

	/// zh: '标签数'
	String get dashTagCount => '标签数';

	/// zh: '我的'
	String get homeNavigatorMe => '我的';

	/// zh: '我的'
	String get meTitle => '我的';

	/// zh: '过去一年'
	String get meYearLabel => '过去一年';

	/// zh: '本月 {count} 篇'
	String meThisMonth({required Object count}) => '本月 ${count} 篇';

	/// zh: '连续 {count} 天'
	String meStreak({required Object count}) => '连续 ${count} 天';

	/// zh: '点一个格子看那天'
	String get meHeatmapHint => '点一个格子看那天';

	/// zh: '写下第一篇，点亮第一格'
	String get meHeatmapEmpty => '写下第一篇，点亮第一格';

	/// zh: '写作热力图'
	String get meHeatmapSemantics => '写作热力图';

	/// zh: '没有记录'
	String get meDayNothing => '没有记录';

	/// zh: '少'
	String get meLegendLess => '少';

	/// zh: '多'
	String get meLegendMore => '多';

	/// zh: '回顾'
	String get meSectionRecall => '回顾';

	/// zh: '管理'
	String get meSectionManage => '管理';

	/// zh: '日历'
	String get meCalendar => '日历';

	/// zh: '功能'
	String get sectionFeature => '功能';

	/// zh: '智能助手'
	String get assistantEntry => '智能助手';

	/// zh: '压测数据（调试）'
	String get stressTitle => '压测数据（调试）';

	/// zh: '批量生成或清除随机双链日记，用于图谱性能测试'
	String get stressSubtitle => '批量生成或清除随机双链日记，用于图谱性能测试';

	/// zh: '压测数据'
	String get stressDialogTitle => '压测数据';

	/// zh: '用于知识图谱等极限性能测试。每篇随机链接 {min}–{max} 篇其它日记，标题以「{prefix}」开头，可一键清除。'
	String stressDialogMessage({required Object min, required Object max, required Object prefix}) => '用于知识图谱等极限性能测试。每篇随机链接 ${min}–${max} 篇其它日记，标题以「${prefix}」开头，可一键清除。';

	/// zh: '清除压测'
	String get stressClear => '清除压测';

	/// zh: '生成'
	String get stressGenerate => '生成';

	/// zh: '生成数量'
	String get stressCountTitle => '生成数量';

	/// zh: '数量需在 {min}–{max} 之间'
	String stressCountRange({required Object min, required Object max}) => '数量需在 ${min}–${max} 之间';

	/// zh: '正在生成'
	String get stressGenerating => '正在生成';

	/// zh: '生成失败'
	String get stressGenerateFailed => '生成失败';

	/// zh: '已生成 {count} 篇双链日记'
	String stressGenerated({required Object count}) => '已生成 ${count} 篇双链日记';

	/// zh: '没有压测日记'
	String get stressEmpty => '没有压测日记';

	/// zh: '正在清除'
	String get stressClearing => '正在清除';

	/// zh: '清除失败'
	String get stressClearFailed => '清除失败';

	/// zh: '已清除 {count} 篇压测日记'
	String stressCleared({required Object count}) => '已清除 ${count} 篇压测日记';

	/// zh: '数据修复'
	String get repairTitle => '数据修复';

	/// zh: '检查并修正卡片预览、媒体引用与失效分类'
	String get repairSubtitle => '检查并修正卡片预览、媒体引用与失效分类';

	/// zh: '将扫描全部日记，按正文重新生成卡片预览、媒体引用，并清理失效的分类引用，最后重建搜索索引。 该操作只修正可从正文重算的衍生数据，不会改动你的正文内容。'
	String get repairMessage => '将扫描全部日记，按正文重新生成卡片预览、媒体引用，并清理失效的分类引用，最后重建搜索索引。\n\n该操作只修正可从正文重算的衍生数据，不会改动你的正文内容。';

	/// zh: '开始修复'
	String get repairStart => '开始修复';

	/// zh: '正在修复数据...'
	String get repairRunning => '正在修复数据...';

	/// zh: '数据修复失败'
	String get repairFailed => '数据修复失败';

	/// zh: '共扫描 {count} 篇日记。'
	String repairScanned({required Object count}) => '共扫描 ${count} 篇日记。';

	/// zh: '所有数据正常，无需修复。'
	String get repairAllGood => '所有数据正常，无需修复。';

	/// zh: '修复 {count} 篇：'
	String repairFixed({required Object count}) => '修复 ${count} 篇：';

	/// zh: '· 卡片预览 {count} 篇'
	String repairFixedPreview({required Object count}) => '· 卡片预览 ${count} 篇';

	/// zh: '· 媒体引用 {count} 篇'
	String repairFixedMedia({required Object count}) => '· 媒体引用 ${count} 篇';

	/// zh: '· 失效分类 {count} 篇'
	String repairFixedOrphan({required Object count}) => '· 失效分类 ${count} 篇';

	/// zh: '搜索索引已重建（{count} 篇）。'
	String repairReindexed({required Object count}) => '搜索索引已重建（${count} 篇）。';

	/// zh: '修复完成'
	String get repairDoneTitle => '修复完成';

	/// zh: '好'
	String get repairOk => '好';

	/// zh: '重置所有数据'
	String get resetTitle => '重置所有数据';

	/// zh: '清空全部日记、设置与媒体，不可恢复'
	String get resetSubtitle => '清空全部日记、设置与媒体，不可恢复';

	/// zh: '此操作将永久删除全部日记、分类、媒体文件、字体，以及所有设置（包括同步配置、加密密钥、应用锁密码等），且无法恢复。 请确保已做好备份。确认后应用将自动关闭，请重新打开以完成重置。'
	String get resetMessage => '此操作将永久删除全部日记、分类、媒体文件、字体，以及所有设置（包括同步配置、加密密钥、应用锁密码等），且无法恢复。\n\n请确保已做好备份。确认后应用将自动关闭，请重新打开以完成重置。';

	/// zh: '确认重置'
	String get resetConfirm => '确认重置';

	/// zh: '正在重置...'
	String get resetRunning => '正在重置...';

	/// zh: '重置失败'
	String get resetFailed => '重置失败';

	/// zh: '数据已清空 请关闭并重新打开应用'
	String get resetDone => '数据已清空\n请关闭并重新打开应用';

	/// zh: '清理缓存'
	String get cacheClear => '清理缓存';

	/// zh: '清理成功'
	String get cacheCleared => '清理成功';

	/// zh: '字体名称获取失败'
	String get fontNameFailed => '字体名称获取失败';

	/// zh: '字体已存在'
	String get fontExists => '字体已存在';

	/// zh: '页面不存在'
	String get routeErrorTitle => '页面不存在';

	/// zh: '返回首页'
	String get routeErrorBackHome => '返回首页';
}

// Path: assistant
class Translations$assistant$zh {
	Translations$assistant$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '智能助手'
	String get settingFunctionAIAssistant => '智能助手';

	/// zh: '编辑'
	String get diaryEdit => '编辑';

	/// zh: '说点什么...'
	String get inputHint => '说点什么...';

	/// zh: '回到底部'
	String get scrollToBottom => '回到底部';

	/// zh: '发送'
	String get send => '发送';

	/// zh: '尚未配置可用的模型供应商，点击前往配置。'
	String get notConfiguredBanner => '尚未配置可用的模型供应商，点击前往配置。';

	/// zh: '请先在「模型供应商」中添加并选择一个可用的供应商。'
	String get needProvider => '请先在「模型供应商」中添加并选择一个可用的供应商。';

	/// zh: '请先在「模型供应商」中填写 API Key。'
	String get needApiKey => '请先在「模型供应商」中填写 API Key。';

	/// zh: 'AI 助手配置'
	String get settingTitle => 'AI 助手配置';

	/// zh: '助手基于 rig 构建。在「模型供应商」里自定义任意数量的服务商（OpenAI / Anthropic 兼容端点），自由切换激活项。API Key 仅保存在本机安全存储。'
	String get settingNote => '助手基于 rig 构建。在「模型供应商」里自定义任意数量的服务商（OpenAI / Anthropic 兼容端点），自由切换激活项。API Key 仅保存在本机安全存储。';

	/// zh: '助手预设'
	String get presetSectionTitle => '助手预设';

	/// zh: '助手预设'
	String get presetTileTitle => '助手预设';

	/// zh: '助手预设'
	String get presetPageTitle => '助手预设';

	/// zh: 'Moodiary助手'
	String get presetBuiltinName => 'Moodiary助手';

	/// zh: '出厂预设：温和、克制的日记伙伴。只读，可派生副本后自由修改。'
	String get presetBuiltinDes => '出厂预设：温和、克制的日记伙伴。只读，可派生副本后自由修改。';

	/// zh: '内置'
	String get presetBuiltinBadge => '内置';

	/// zh: '默认'
	String get presetDefaultBadge => '默认';

	/// zh: '设为默认'
	String get presetSetDefault => '设为默认';

	/// zh: '派生副本'
	String get presetDerive => '派生副本';

	/// zh: '{name} 副本'
	String presetCopyName({required Object name}) => '${name} 副本';

	/// zh: '编辑预设'
	String get presetEditTitle => '编辑预设';

	/// zh: '名称'
	String get presetNameLabel => '名称';

	/// zh: '简介'
	String get presetDescriptionLabel => '简介';

	/// zh: '人格'
	String get presetPersonaLabel => '人格';

	/// zh: '已保存预设'
	String get presetSaved => '已保存预设';

	/// zh: '删除预设'
	String get presetDeleteTitle => '删除预设';

	/// zh: '删除「{name}」？已用它创建的会话不受影响（人格已定格在会话里）。'
	String presetDeleteMessage({required Object name}) => '删除「${name}」？已用它创建的会话不受影响（人格已定格在会话里）。';

	/// zh: '已删除的预设'
	String get presetDeleted => '已删除的预设';

	/// zh: '选择预设'
	String get presetPickerTitle => '选择预设';

	/// zh: '本会话的配置已在创建时定格'
	String get presetInfoSubtitle => '本会话的配置已在创建时定格';

	/// zh: '自定义工具集'
	String get presetCustomTools => '自定义工具集';

	/// zh: '{count} 个工具'
	String presetToolCount({required Object count}) => '${count} 个工具';

	/// zh: '全部工具'
	String get presetToolsAll => '全部工具';

	/// zh: '不挂载工具'
	String get presetToolsNone => '不挂载工具';

	/// zh: '已切换到 {model}'
	String modelSwitched({required Object model}) => '已切换到 ${model}';

	/// zh: '加载中…'
	String get providerEntryLoading => '加载中…';

	/// zh: '尚未添加供应商，点击去添加'
	String get providerEntryEmpty => '尚未添加供应商，点击去添加';

	/// zh: '已复制'
	String get copied => '已复制';

	/// zh: '复制'
	String get copyTooltip => '复制';

	/// zh: '新对话'
	String get newChat => '新对话';

	/// zh: '还没有历史会话'
	String get historyEmpty => '还没有历史会话';

	/// zh: '今天'
	String get historyToday => '今天';

	/// zh: '近 7 天'
	String get historyLast7 => '近 7 天';

	/// zh: '更早'
	String get historyEarlier => '更早';

	/// zh: '未配置'
	String get historyModelUnset => '未配置';

	/// zh: '停止生成'
	String get stop => '停止生成';

	/// zh: '重新回答'
	String get regenerate => '重新回答';

	/// zh: '思考中…'
	String get thinking => '思考中…';

	/// zh: '协议'
	String get protocolTitle => '协议';

	/// zh: 'OpenAI /chat/completions'
	String get protocolOpenAiCompletions => 'OpenAI /chat/completions';

	/// zh: 'OpenAI /responses'
	String get protocolOpenAiResponses => 'OpenAI /responses';

	/// zh: 'Anthropic /messages'
	String get protocolAnthropicMessages => 'Anthropic /messages';

	/// zh: '从端点获取模型列表'
	String get modelListFetch => '从端点获取模型列表';

	/// zh: '请先填写 API Key'
	String get modelListNeedKey => '请先填写 API Key';

	/// zh: '获取到 {count} 个模型'
	String modelListFetched({required Object count}) => '获取到 ${count} 个模型';

	/// zh: '获取模型列表失败，可手动填写模型'
	String get modelListFailed => '获取模型列表失败，可手动填写模型';

	/// zh: '思考强度'
	String get reasoningEffort => '思考强度';

	/// zh: '不思考'
	String get reasoningOff => '不思考';

	/// zh: '已思考 {duration} 秒'
	String thoughtFor({required Object duration}) => '已思考 ${duration} 秒';

	/// zh: '工具'
	String get tool => '工具';

	/// zh: '助手会根据对话内容自动调用下列工具，无需你逐次确认。删除类操作请留意：日记会进回收站，记忆则是永久删除。'
	String get toolSectionNote => '助手会根据对话内容自动调用下列工具，无需你逐次确认。删除类操作请留意：日记会进回收站，记忆则是永久删除。';

	/// zh: '查询日记'
	String get toolQueryTitle => '查询日记';

	/// zh: '按关键词、时间范围或分类查询你的本地日记，用于回答涉及过往经历、情绪记录的问题。'
	String get toolQueryDes => '按关键词、时间范围或分类查询你的本地日记，用于回答涉及过往经历、情绪记录的问题。';

	/// zh: '语义检索'
	String get toolSemanticTitle => '语义检索';

	/// zh: '按含义而非关键词查找日记：用一句自然语言描述要找的内容，即使措辞不同也能召回。需先在设置中启用本地语义索引。'
	String get toolSemanticDes => '按含义而非关键词查找日记：用一句自然语言描述要找的内容，即使措辞不同也能召回。需先在设置中启用本地语义索引。';

	/// zh: '读取日记全文'
	String get toolGetTitle => '读取日记全文';

	/// zh: '按 id 读取日记的完整内容，可一次读多篇。'
	String get toolGetDes => '按 id 读取日记的完整内容，可一次读多篇。';

	/// zh: '日记概览'
	String get toolOverviewTitle => '日记概览';

	/// zh: '统计日记总数、各分类篇数与时间跨度。'
	String get toolOverviewDes => '统计日记总数、各分类篇数与时间跨度。';

	/// zh: '创建日记'
	String get toolCreateTitle => '创建日记';

	/// zh: '按你的请求把内容保存为一篇新的本地日记。'
	String get toolCreateDes => '按你的请求把内容保存为一篇新的本地日记。';

	/// zh: '修改日记'
	String get toolUpdateTitle => '修改日记';

	/// zh: '按你的要求修改日记的标题、正文、心情或归类，可一次改多篇。'
	String get toolUpdateDes => '按你的要求修改日记的标题、正文、心情或归类，可一次改多篇。';

	/// zh: '删除日记'
	String get toolDeleteTitle => '删除日记';

	/// zh: '把指定日记移入回收站（可在回收站恢复），可一次删多篇。'
	String get toolDeleteDes => '把指定日记移入回收站（可在回收站恢复），可一次删多篇。';

	/// zh: '查看分类'
	String get toolListCategoriesTitle => '查看分类';

	/// zh: '列出你的全部日记分类。'
	String get toolListCategoriesDes => '列出你的全部日记分类。';

	/// zh: '创建分类'
	String get toolCreateCategoryTitle => '创建分类';

	/// zh: '新建日记分类。'
	String get toolCreateCategoryDes => '新建日记分类。';

	/// zh: '重命名分类'
	String get toolUpdateCategoryTitle => '重命名分类';

	/// zh: '修改分类的名称。'
	String get toolUpdateCategoryDes => '修改分类的名称。';

	/// zh: '删除分类'
	String get toolDeleteCategoryTitle => '删除分类';

	/// zh: '删除分类（仅当其下没有日记时）。'
	String get toolDeleteCategoryDes => '删除分类（仅当其下没有日记时）。';

	/// zh: '查看记忆'
	String get toolListMemoriesTitle => '查看记忆';

	/// zh: '列出助手保存的关于你的长期记忆（偏好、主题、目标等）。'
	String get toolListMemoriesDes => '列出助手保存的关于你的长期记忆（偏好、主题、目标等）。';

	/// zh: '记住事实'
	String get toolRememberTitle => '记住事实';

	/// zh: '把关于你的长期事实（稳定偏好 / 反复出现的主题 / 持续目标）保存下来，供日后对话记起。'
	String get toolRememberDes => '把关于你的长期事实（稳定偏好 / 反复出现的主题 / 持续目标）保存下来，供日后对话记起。';

	/// zh: '更新记忆'
	String get toolUpdateMemoryTitle => '更新记忆';

	/// zh: '修改已保存记忆的内容。'
	String get toolUpdateMemoryDes => '修改已保存记忆的内容。';

	/// zh: '删除记忆'
	String get toolForgetTitle => '删除记忆';

	/// zh: '删除已保存的记忆。'
	String get toolForgetDes => '删除已保存的记忆。';

	/// zh: '运行脚本'
	String get toolJsTitle => '运行脚本';

	/// zh: '在隔离环境里运行一小段 JavaScript 做计算，无法联网，也读不到你的日记。'
	String get toolJsDes => '在隔离环境里运行一小段 JavaScript 做计算，无法联网，也读不到你的日记。';

	/// zh: '无返回值'
	String get toolJsEmpty => '无返回值';

	/// zh: '已折叠较早的消息以节省上下文'
	String get compactionNotice => '已折叠较早的消息以节省上下文';

	/// zh: '上下文摘要'
	String get compactionSheetTitle => '上下文摘要';

	/// zh: '为节省上下文，较早的消息已折叠成下面的摘要发送给模型。完整消息仍保留在本会话中，可随时向上翻看。'
	String get compactionSheetNote => '为节省上下文，较早的消息已折叠成下面的摘要发送给模型。完整消息仍保留在本会话中，可随时向上翻看。';

	/// zh: '恢复完整历史'
	String get compactionRestore => '恢复完整历史';

	/// zh: '使用前必读'
	String get disclaimerTitle => '使用前必读';

	/// zh: 'Moodiary 助手由第三方大语言模型驱动，使用前请知悉： • AI 生成的内容可能不准确、不完整甚至具有误导性，请勿将其作为医疗、心理、法律、财务等专业建议，或任何重要决策的依据。 • 发送消息后，你输入的内容会被发送给你所配置的模型供应商；当助手调用日记工具时，相关的本地日记摘要也会一并发送以生成回复。是否信任该供应商由你自行判断。 • 你的 API Key 仅保存在本机安全存储，不会上传到 Moodiary 的服务器。 继续使用即代表你已知悉并接受以上风险。'
	String get disclaimerContent => 'Moodiary 助手由第三方大语言模型驱动，使用前请知悉：\n\n• AI 生成的内容可能不准确、不完整甚至具有误导性，请勿将其作为医疗、心理、法律、财务等专业建议，或任何重要决策的依据。\n\n• 发送消息后，你输入的内容会被发送给你所配置的模型供应商；当助手调用日记工具时，相关的本地日记摘要也会一并发送以生成回复。是否信任该供应商由你自行判断。\n\n• 你的 API Key 仅保存在本机安全存储，不会上传到 Moodiary 的服务器。\n\n继续使用即代表你已知悉并接受以上风险。';

	/// zh: '同意并继续'
	String get disclaimerAgree => '同意并继续';

	/// zh: '暂不使用'
	String get disclaimerDecline => '暂不使用';

	/// zh: '需先同意免责声明才能使用助手'
	String get disclaimerGateTitle => '需先同意免责声明才能使用助手';

	/// zh: '查看免责声明'
	String get disclaimerGateAction => '查看免责声明';

	/// zh: '发送日记'
	String get toolSendDiary => '发送日记';

	/// zh: '发送图片'
	String get toolSendImage => '发送图片';

	/// zh: '[图片]'
	String get imageMessageLabel => '[图片]';

	/// zh: '这是我的一篇日记，请阅读后帮我分析或回应：'
	String get sendDiaryLead => '这是我的一篇日记，请阅读后帮我分析或回应：';

	/// zh: '模型供应商'
	String get modelProviderTitle => '模型供应商';

	/// zh: '新增'
	String get modelProviderAdd => '新增';

	/// zh: '缺少 Key'
	String get modelProviderNoKey => '缺少 Key';

	/// zh: '还没有模型供应商'
	String get modelProviderEmptyTitle => '还没有模型供应商';

	/// zh: '点击右下角「新增」添加一个服务商'
	String get modelProviderEmptyHint => '点击右下角「新增」添加一个服务商';

	/// zh: '删除供应商'
	String get modelProviderDeleteTitle => '删除供应商';

	/// zh: '确定删除「{name}」？其 API Key 也会一并清除。'
	String modelProviderDeleteContent({required Object name}) => '确定删除「${name}」？其 API Key 也会一并清除。';

	/// zh: '已删除'
	String get modelProviderDeleted => '已删除';

	/// zh: '新增供应商'
	String get modelProviderEditNew => '新增供应商';

	/// zh: '编辑供应商'
	String get modelProviderEditEdit => '编辑供应商';

	/// zh: '例如 DeepSeek / 本地 Ollama'
	String get modelProviderNameHint => '例如 DeepSeek / 本地 Ollama';

	/// zh: 'baseUrl'
	String get modelProviderBaseUrl => 'baseUrl';

	/// zh: '留空使用该协议官方端点'
	String get modelProviderBaseUrlHint => '留空使用该协议官方端点';

	/// zh: 'API Key'
	String get modelProviderApiKey => 'API Key';

	/// zh: '已配置，留空保持不变'
	String get modelProviderApiKeyHintSet => '已配置，留空保持不变';

	/// zh: '粘贴 API Key'
	String get modelProviderApiKeyHintUnset => '粘贴 API Key';

	/// zh: '模型'
	String get modelProviderModel => '模型';

	/// zh: '请填写名称'
	String get modelProviderNeedName => '请填写名称';

	/// zh: '请填写模型'
	String get modelProviderNeedModel => '请填写模型';

	/// zh: '已保存'
	String get modelProviderSaved => '已保存';

	/// zh: '获取 API Key'
	String get modelProviderGetApiKey => '获取 API Key';

	/// zh: '选择供应商'
	String get llmPickerTitle => '选择供应商';

	/// zh: '手动填写供应商配置'
	String get llmPickerCustomDes => '手动填写供应商配置';

	/// zh: '刷新'
	String get llmPickerRefresh => '刷新';

	/// zh: '已更新'
	String get llmPickerRefreshed => '已更新';

	/// zh: '加载失败'
	String get llmPickerLoadFailed => '加载失败';

	/// zh: '{count} 个模型'
	String llmPickerModelCount({required Object count}) => '${count} 个模型';

	/// zh: '更新于 {time}'
	String llmPickerUpdatedAt({required Object time}) => '更新于 ${time}';

	/// zh: '暂无可用的预设供应商'
	String get llmPickerEmpty => '暂无可用的预设供应商';

	/// zh: '数据来自 models.dev'
	String get llmPickerDataSource => '数据来自 models.dev';

	/// zh: '搜索供应商'
	String get llmPickerSearchHint => '搜索供应商';

	/// zh: '选择模型'
	String get modelProviderPickModel => '选择模型';

	/// zh: '推理'
	String get modelProviderBadgeReasoning => '推理';

	/// zh: '视觉'
	String get modelProviderBadgeVision => '视觉';

	/// zh: '模型能力'
	String get modelProviderCapabilities => '模型能力';

	/// zh: '按模型实际能力开启，决定是否启用工具、思考模式、发送图片。'
	String get modelProviderCapabilitiesHint => '按模型实际能力开启，决定是否启用工具、思考模式、发送图片。';

	/// zh: '搜索模型'
	String get modelProviderSearchModelHint => '搜索模型';

	/// zh: '无匹配模型'
	String get modelProviderNoModelMatch => '无匹配模型';

	/// zh: '加载中…'
	String get summaryLoading => '加载中…';

	/// zh: '未配置模型供应商'
	String get summaryNoProvider => '未配置模型供应商';

	/// zh: 'Key 已配置'
	String get summaryKeySet => 'Key 已配置';

	/// zh: 'Key 未配置'
	String get summaryKeyUnset => 'Key 未配置';

	/// zh: 'AI 助手配置'
	String get summaryTitle => 'AI 助手配置';

	/// zh: ' （出错：{error}）'
	String streamError({required Object error}) => '\n（出错：${error}）';

	/// zh: '（请求失败：{error}）'
	String requestFailed({required Object error}) => '（请求失败：${error}）';

	/// zh: '[图片]'
	String get imagePlaceholder => '[图片]';

	/// zh: '默认'
	String get modelProviderDefault => '默认';

	/// zh: '默认模型'
	String get modelProviderDefaultModel => '默认模型';

	/// zh: '共 {count} 个模型'
	String modelListCount({required Object count}) => '共 ${count} 个模型';

	/// zh: '更新列表'
	String get modelListUpdate => '更新列表';

	/// zh: '手动添加'
	String get modelListAdd => '手动添加';

	/// zh: '还没有可选模型'
	String get modelListEmpty => '还没有可选模型';

	/// zh: '已下线'
	String get modelDeprecated => '已下线';

	/// zh: '全屏编辑'
	String get composerFullscreen => '全屏编辑';

	/// zh: '已完成'
	String get toolDone => '已完成';

	/// zh: '未成功'
	String get toolFailed => '未成功';

	/// zh: '无结果'
	String get toolNoMatch => '无结果';

	/// zh: '{count} 篇'
	String toolMatched({required Object count}) => '${count} 篇';

	/// zh: '{count} 篇全文'
	String toolRead({required Object count}) => '${count} 篇全文';

	/// zh: '{count} 项'
	String toolListed({required Object count}) => '${count} 项';

	/// zh: '无标题'
	String get toolUntitled => '无标题';

	/// zh: '已更新'
	String get toolUpdated => '已更新';

	/// zh: '已移入回收站'
	String get toolTrashed => '已移入回收站';

	/// zh: '{count} 篇已移入回收站'
	String toolTrashedCount({required Object count}) => '${count} 篇已移入回收站';

	/// zh: '{count} 篇'
	String toolBatchDiaries({required Object count}) => '${count} 篇';

	/// zh: '{count} 项'
	String toolBatchItems({required Object count}) => '${count} 项';

	/// zh: '已删除'
	String get toolDeleted => '已删除';
}

// Path: common
class Translations$common$zh {
	Translations$common$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '确认'
	String get ok => '确认';

	/// zh: '低落'
	String get moodNegative => '低落';

	/// zh: '平静'
	String get moodNeutral => '平静';

	/// zh: '愉快'
	String get moodPositive => '愉快';

	/// zh: '兴奋'
	String get moodExcited => '兴奋';

	/// zh: '生气'
	String get moodAngry => '生气';

	/// zh: '焦虑'
	String get moodAnxious => '焦虑';

	/// zh: '疲惫'
	String get moodTired => '疲惫';

	/// zh: '无语'
	String get moodSpeechless => '无语';

	/// zh: '恋爱'
	String get moodLove => '恋爱';

	/// zh: '学习'
	String get moodStudy => '学习';

	/// zh: '摸鱼'
	String get moodSlacking => '摸鱼';

	/// zh: '好吃'
	String get moodFood => '好吃';

	/// zh: '工作'
	String get moodWork => '工作';

	/// zh: '旅行'
	String get moodTravel => '旅行';

	/// zh: '运动'
	String get moodSports => '运动';

	/// zh: '生病'
	String get moodSick => '生病';

	/// zh: '情绪'
	String get moodGroupEmotion => '情绪';

	/// zh: '状态'
	String get moodGroupState => '状态';

	/// zh: '取消'
	String get cancel => '取消';

	/// zh: '更多'
	String get more => '更多';

	/// zh: '自定义'
	String get custom => '自定义';

	/// zh: '保存'
	String get save => '保存';

	/// zh: '媒体'
	String get media => '媒体';

	/// zh: '音频'
	String get audio => '音频';

	/// zh: '视频'
	String get video => '视频';

	/// zh: '分类'
	String get category => '分类';

	/// zh: '名称'
	String get name => '名称';

	/// zh: '删除'
	String get delete => '删除';

	/// zh: '加载失败'
	String get loadFailed => '加载失败';

	/// zh: '无标题'
	String get untitled => '无标题';

	/// zh: '重试'
	String get retry => '重试';

	/// zh: '{count} 个分类'
	String categoryCount({required Object count}) => '${count} 个分类';

	/// zh: '文件名'
	String get fileName => '文件名';

	/// zh: '关闭'
	String get close => '关闭';

	/// zh: 'Moodiary'
	String get appName => 'Moodiary';

	/// zh: '已配置'
	String get configured => '已配置';

	/// zh: '未配置'
	String get notConfigured => '未配置';
}

// Path: diary
class Translations$diary$zh {
	Translations$diary$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '这里一片荒芜'
	String get tabViewEmpty => '这里一片荒芜';

	/// zh: '视图模式'
	String get pageViewModeButton => '视图模式';

	/// zh: '无分类'
	String get categoryNoCategory => '无分类';

	/// zh: '全部分类'
	String get allCategories => '全部分类';

	/// zh: '全部'
	String get categoryAll => '全部';

	/// zh: '颜色'
	String get categoryColorLabel => '颜色';

	/// zh: '搜索'
	String get search => '搜索';

	/// zh: '共有 {count} 篇'
	String searchResult({required Object count}) => '共有 ${count} 篇';

	/// zh: '耗时 {ms}ms'
	String searchTime({required Object ms}) => '耗时 ${ms}ms';

	/// zh: '全部时间'
	String get rangeAll => '全部时间';

	/// zh: '近 30 天'
	String get rangeLast30 => '近 30 天';

	/// zh: '今年'
	String get rangeThisYear => '今年';

	/// zh: '相关度'
	String get searchSortRelevance => '相关度';

	/// zh: '最新'
	String get searchSortNewest => '最新';

	/// zh: '最早'
	String get searchSortOldest => '最早';

	/// zh: '没有匹配的日记'
	String get searchNoResult => '没有匹配的日记';

	/// zh: '搜索历史'
	String get searchHistory => '搜索历史';

	/// zh: '清空'
	String get searchHistoryClear => '清空';

	/// zh: '暂无搜索历史'
	String get searchHistoryEmpty => '暂无搜索历史';

	/// zh: '时间线'
	String get viewModeTimeline => '时间线';

	/// zh: '信息流'
	String get viewModeFeed => '信息流';

	/// zh: '选择日记'
	String get assistantSelectDiaryTitle => '选择日记';

	/// zh: '搜索日记'
	String get assistantSelectDiarySearchHint => '搜索日记';

	/// zh: '没有可发送的日记'
	String get assistantSelectDiaryEmpty => '没有可发送的日记';

	/// zh: '日记不存在或已删除'
	String get linkNotFound => '日记不存在或已删除';

	/// zh: '知识图谱'
	String get knowledgeGraph => '知识图谱';

	/// zh: '{nodes} 篇 · {edges} 条链接'
	String graphCount({required Object nodes, required Object edges}) => '${nodes} 篇 · ${edges} 条链接';

	/// zh: '近一年'
	String get graphTimeLast365 => '近一年';

	/// zh: '打开日记'
	String get graphOpenDiary => '打开日记';

	/// zh: '布局风格'
	String get graphStyle => '布局风格';

	/// zh: '稀疏'
	String get graphStyleSparse => '稀疏';

	/// zh: '标准'
	String get graphStyleNormal => '标准';

	/// zh: '稠密'
	String get graphStyleDense => '稠密';

	/// zh: '视图'
	String get graphView => '视图';

	/// zh: '着色'
	String get graphColorBy => '着色';

	/// zh: '时间'
	String get graphColorByTime => '时间';

	/// zh: '素色'
	String get graphColorByPlain => '素色';

	/// zh: '显示标题'
	String get graphShowLabels => '显示标题';

	/// zh: '回到全景'
	String get graphResetCamera => '回到全景';

	/// zh: '还没有双链'
	String get graphEmptyTitle => '还没有双链';

	/// zh: '在日记里输入 [[ 引用另一篇日记，它们就会出现在这里'
	String get graphEmptyDesc => '在日记里输入 [[ 引用另一篇日记，它们就会出现在这里';

	/// zh: '写一篇日记'
	String get graphEmptyAction => '写一篇日记';

	/// zh: '当前筛选下没有链接'
	String get graphFilterEmpty => '当前筛选下没有链接';

	/// zh: '清除筛选'
	String get graphClearFilter => '清除筛选';

	/// zh: '关系图'
	String get graphLocal => '关系图';

	/// zh: '出链'
	String get graphOutgoing => '出链';

	/// zh: '入链'
	String get graphIncoming => '入链';

	/// zh: '{count} 条出链'
	String graphOutgoingCount({required Object count}) => '${count} 条出链';

	/// zh: '{count} 条入链'
	String graphIncomingCount({required Object count}) => '${count} 条入链';

	/// zh: '以此为中心'
	String get graphSetAsCenter => '以此为中心';

	/// zh: '回到中心'
	String get graphBackToCenter => '回到中心';

	/// zh: '链接'
	String get graphLinks => '链接';

	/// zh: '这篇日记还没有关联'
	String get graphNoLocalLinks => '这篇日记还没有关联';

	/// zh: '搜索分类'
	String get categorySearchHint => '搜索分类';

	/// zh: '全部日记'
	String get categoryAllDiary => '全部日记';

	/// zh: '没有匹配的分类'
	String get categoryNoMatch => '没有匹配的分类';

	/// zh: '正在同步分类…'
	String get categorySyncingPlaceholder => '正在同步分类…';

	/// zh: '管理分类'
	String get categoryManageEntry => '管理分类';

	/// zh: '排序'
	String get sortTitle => '排序';

	/// zh: '最新在前'
	String get sortNewestFirst => '最新在前';

	/// zh: '最早在前'
	String get sortOldestFirst => '最早在前';

	/// zh: '最近修改在前'
	String get sortModifiedFirst => '最近修改在前';

	/// zh: '(other) {{count} 篇}'
	String timelineMonthCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 篇',
	);

	/// zh: '近 7 天'
	String get rangeLast7 => '近 7 天';

	/// zh: '分类管理'
	String get categoryManagerTitle => '分类管理';

	/// zh: '已创建「{name}」'
	String categoryCreated({required Object name}) => '已创建「${name}」';

	/// zh: '创建失败'
	String get categoryCreateFailed => '创建失败';

	/// zh: '已重命名为「{name}」'
	String categoryRenamed({required Object name}) => '已重命名为「${name}」';

	/// zh: '重命名失败'
	String get categoryRenameFailed => '重命名失败';

	/// zh: '删除分类？'
	String get categoryDeleteTitle => '删除分类？';

	/// zh: '「{name}」下若仍有日记将无法删除。本操作不会影响日记本身。'
	String categoryDeleteMessage({required Object name}) => '「${name}」下若仍有日记将无法删除。本操作不会影响日记本身。';

	/// zh: '已删除'
	String get categoryDeleted => '已删除';

	/// zh: '分类下仍有日记，删除失败'
	String get categoryDeleteBlocked => '分类下仍有日记，删除失败';

	/// zh: '暂无分类'
	String get categoryEmpty => '暂无分类';

	/// zh: '新建分类'
	String get categoryNew => '新建分类';

	/// zh: '{count} 篇日记'
	String categoryDiaryCount({required Object count}) => '${count} 篇日记';

	/// zh: '暂无日记'
	String get categoryNoDiary => '暂无日记';

	/// zh: '重命名'
	String get rename => '重命名';

	/// zh: '分类名称'
	String get categoryNameHint => '分类名称';

	/// zh: '分类名称不能为空'
	String get categoryNameEmpty => '分类名称不能为空';

	/// zh: '回收站'
	String get recycleTitle => '回收站';

	/// zh: '清空回收站'
	String get recycleClear => '清空回收站';

	/// zh: '已恢复'
	String get recycleRestored => '已恢复';

	/// zh: '恢复失败'
	String get recycleRestoreFailed => '恢复失败';

	/// zh: '彻底删除？'
	String get recyclePurgeTitle => '彻底删除？';

	/// zh: '此操作不可恢复，日记将永久消失。'
	String get recyclePurgeMessage => '此操作不可恢复，日记将永久消失。';

	/// zh: '彻底删除'
	String get recyclePurgeConfirm => '彻底删除';

	/// zh: '已永久删除'
	String get recyclePurged => '已永久删除';

	/// zh: '删除失败'
	String get recyclePurgeFailed => '删除失败';

	/// zh: '清空回收站？'
	String get recycleClearTitle => '清空回收站？';

	/// zh: '将永久删除 {count} 条日记。此操作不可恢复。'
	String recycleClearMessage({required Object count}) => '将永久删除 ${count} 条日记。此操作不可恢复。';

	/// zh: '清空'
	String get recycleClearConfirm => '清空';

	/// zh: '已清空 {count} 条'
	String recycleCleared({required Object count}) => '已清空 ${count} 条';

	/// zh: '回收站为空'
	String get recycleEmpty => '回收站为空';

	/// zh: '恢复'
	String get recycleRestore => '恢复';

	/// zh: '日记管理'
	String get managerTitle => '日记管理';

	/// zh: '已选 {count}'
	String managerSelected({required Object count}) => '已选 ${count}';

	/// zh: '批量移入回收站'
	String get managerBatchRecycle => '批量移入回收站';

	/// zh: '当前筛选下没有日记'
	String get managerEmpty => '当前筛选下没有日记';

	/// zh: '批量移入回收站？'
	String get managerRecycleTitle => '批量移入回收站？';

	/// zh: '共 {count} 条日记将被移入回收站，可在「回收站」内恢复。'
	String managerRecycleMessage({required Object count}) => '共 ${count} 条日记将被移入回收站，可在「回收站」内恢复。';

	/// zh: '移入回收站'
	String get managerRecycleConfirm => '移入回收站';

	/// zh: '已移入回收站 {done} / {total}'
	String managerRecycled({required Object done, required Object total}) => '已移入回收站 ${done} / ${total}';

	/// zh: '全部'
	String get managerAll => '全部';

	/// zh: '足迹'
	String get mapTitle => '足迹';

	/// zh: '添加标签'
	String get addTag => '添加标签';

	/// zh: '标签名'
	String get tagNameHint => '标签名';

	/// zh: '添加'
	String get add => '添加';

	/// zh: '获取天气失败：请检查实验室内的和风天气配置'
	String get weatherFailed => '获取天气失败：请检查实验室内的和风天气配置';

	/// zh: '已获取天气：{weather} {temperature}°C'
	String weatherFetched({required Object weather, required Object temperature}) => '已获取天气：${weather} ${temperature}°C';

	/// zh: '获取位置失败：请检查定位权限'
	String get positionFailed => '获取位置失败：请检查定位权限';

	/// zh: '主页'
	String get home => '主页';

	/// zh: '后退'
	String get goBack => '后退';

	/// zh: '前进'
	String get goForward => '前进';

	/// zh: '编辑'
	String get edit => '编辑';

	/// zh: '分享'
	String get share => '分享';

	/// zh: '目录'
	String get outline => '目录';

	/// zh: '{count} 字'
	String wordCount({required Object count}) => '${count} 字';

	/// zh: '保存中'
	String get saving => '保存中';

	/// zh: '已保存'
	String get saved => '已保存';

	/// zh: '未保存'
	String get unsaved => '未保存';

	/// zh: '保存失败'
	String get saveFailed => '保存失败';

	/// zh: '未知分类'
	String get unknownCategory => '未知分类';

	/// zh: '加载中…'
	String get loading => '加载中…';

	/// zh: '升级后需重建索引，旧日记正文才能被搜索到'
	String get searchReindexHint => '升级后需重建索引，旧日记正文才能被搜索到';

	/// zh: '重建'
	String get searchReindex => '重建';

	/// zh: '自动保存'
	String get autoSaved => '自动保存';

	/// zh: '日历'
	String get calendarTitle => '日历';

	/// zh: '回到今天'
	String get calendarBackToToday => '回到今天';

	/// zh: '这天没有写'
	String get calendarEmptyDay => '这天没有写';
}

// Path: editor
class Translations$editor$zh {
	Translations$editor$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '请开启定位权限'
	String get noticeEnableLocation => '请开启定位权限';

	/// zh: '请前往设置中开启定位权限'
	String get noticeEnableLocation2 => '请前往设置中开启定位权限';

	/// zh: '音频文件错误'
	String get audioFileError => '音频文件错误';

	/// zh: '选择音频'
	String get pickAudio => '选择音频';

	/// zh: '录音'
	String get pickAudioFromRecord => '录音';

	/// zh: '音频文件'
	String get pickAudioFromFile => '音频文件';

	/// zh: '正文'
	String get content => '正文';

	/// zh: '当前平台暂不支持编辑器'
	String get unsupportedPlatform => '当前平台暂不支持编辑器';

	/// zh: '编辑器加载失败 {error}'
	String loadFailed({required Object error}) => '编辑器加载失败\n${error}';

	/// zh: '选择分类'
	String get pickCategory => '选择分类';

	/// zh: '不分类'
	String get noCategory => '不分类';

	/// zh: '迁移到新编辑器'
	String get migrationTitle => '迁移到新编辑器';

	/// zh: '转换前会自动备份原文；中途退出不丢数据，下次启动会继续。'
	String get migrationNote => '转换前会自动备份原文；中途退出不丢数据，下次启动会继续。';

	/// zh: '{count} 篇迁移失败，请重试'
	String migrationFailedCount({required Object count}) => '${count} 篇迁移失败，请重试';

	/// zh: '迁移出错，请重试'
	String get migrationError => '迁移出错，请重试';

	/// zh: '重试'
	String get migrationRetry => '重试';

	/// zh: '正在迁移 {done} / {total}'
	String migrationProgress({required Object done, required Object total}) => '正在迁移 ${done} / ${total}';

	/// zh: '正在升级数据库（不会丢失任何数据）'
	String get migrationEngineStage => '正在升级数据库（不会丢失任何数据）';
}

// Path: export
class Translations$export$zh {
	Translations$export$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '导入与导出'
	String get pageTitle => '导入与导出';

	/// zh: '导出'
	String get sectionExport => '导出';

	/// zh: '备份'
	String get sectionBackup => '备份';

	/// zh: 'DOCX'
	String get formatDocx => 'DOCX';

	/// zh: '导出备份'
	String get backupExport => '导出备份';

	/// zh: '打包全部日记与媒体'
	String get backupExportSubtitle => '打包全部日记与媒体';

	/// zh: '从备份恢复'
	String get restoreFromBackup => '从备份恢复';

	/// zh: '按修改时间合并'
	String get backupRestoreSubtitle => '按修改时间合并';

	/// zh: '备份与本地数据按最后修改时间合并，较新的条目覆盖较旧的。'
	String get restoreConfirmMessage => '备份与本地数据按最后修改时间合并，较新的条目覆盖较旧的。';

	/// zh: '恢复'
	String get restoreConfirmLabel => '恢复';

	/// zh: '正在恢复…'
	String get restoring => '正在恢复…';

	/// zh: '恢复完成：{summary}'
	String restoreDone({required Object summary}) => '恢复完成：${summary}';

	/// zh: '日记 {diary} 条 / 分类 {category} 条 / 媒体信息 {media} 条'
	String restoreSummary({required Object diary, required Object category, required Object media}) => '日记 ${diary} 条 / 分类 ${category} 条 / 媒体信息 ${media} 条';

	/// zh: '{base}，失败 {failed} 条'
	String restoreSummaryFailed({required Object base, required Object failed}) => '${base}，失败 ${failed} 条';

	/// zh: '恢复已停止（未完成）：{summary}'
	String restoreStopped({required Object summary}) => '恢复已停止（未完成）：${summary}';

	/// zh: '恢复失败：{error}'
	String restoreFailed({required Object error}) => '恢复失败：${error}';

	/// zh: '正在打包备份…'
	String get packingBackup => '正在打包备份…';

	/// zh: '备份已生成'
	String get backupReady => '备份已生成';

	/// zh: '导出失败：{error}'
	String failed({required Object error}) => '导出失败：${error}';

	/// zh: '产物不见了，请重试'
	String get artifactMissing => '产物不见了，请重试';

	/// zh: '已生成'
	String get generated => '已生成';

	/// zh: '导出为 Markdown'
	String get titleMarkdown => '导出为 Markdown';

	/// zh: '导出为 DOCX'
	String get titleDocx => '导出为 DOCX';

	/// zh: '导出为 PDF'
	String get titlePdf => '导出为 PDF';

	/// zh: '范围'
	String get sectionScope => '范围';

	/// zh: '选择日记'
	String get selectDiaries => '选择日记';

	/// zh: '统计中…'
	String get counting => '统计中…';

	/// zh: '{count} 篇'
	String entryCount({required Object count}) => '${count} 篇';

	/// zh: '合并成一个文件'
	String get mergeIntoOneFile => '合并成一个文件';

	/// zh: '关闭后每篇一个文件'
	String get mergeSubtitle => '关闭后每篇一个文件';

	/// zh: '文件名模板'
	String get fileNameTemplate => '文件名模板';

	/// zh: '可用占位符：{date} 日期、{title} 标题、{id} 日记 id'
	String fileNameTemplateHint({required Object date, required Object title, required Object id}) => '可用占位符：${date} 日期、${title} 标题、${id} 日记 id';

	/// zh: '模板不能为空'
	String get templateEmpty => '模板不能为空';

	/// zh: '内容'
	String get sectionContent => '内容';

	/// zh: '标题'
	String get includeTitle => '标题';

	/// zh: '日期、天气与位置'
	String get includeMeta => '日期、天气与位置';

	/// zh: '内嵌图片'
	String get mediaEmbed => '内嵌图片';

	/// zh: '只写占位文字'
	String get mediaPlaceholder => '只写占位文字';

	/// zh: '不含媒体'
	String get mediaNone => '不含媒体';

	/// zh: 'GitHub 风味'
	String get markdownGfm => 'GitHub 风味';

	/// zh: '支持表格与任务清单'
	String get markdownGfmSubtitle => '支持表格与任务清单';

	/// zh: '写入 Front Matter'
	String get markdownFrontMatter => '写入 Front Matter';

	/// zh: '在文件开头记录日期、分类等信息'
	String get markdownFrontMatterSubtitle => '在文件开头记录日期、分类等信息';

	/// zh: '排版'
	String get sectionLayout => '排版';

	/// zh: '字体'
	String get font => '字体';

	/// zh: '中文字体'
	String get eastAsiaFont => '中文字体';

	/// zh: '西文字体'
	String get asciiFont => '西文字体';

	/// zh: '还没有选择字体'
	String get noFontSelected => '还没有选择字体';

	/// zh: '字号'
	String get fontSize => '字号';

	/// zh: '{size} pt'
	String fontSizeValue({required Object size}) => '${size} pt';

	/// zh: '行距'
	String get lineSpacing => '行距';

	/// zh: '{value} 倍'
	String lineSpacingValue({required Object value}) => '${value} 倍';

	/// zh: '首行缩进两字符'
	String get firstLineIndent => '首行缩进两字符';

	/// zh: '纸张'
	String get paper => '纸张';

	/// zh: '填写字体名，如「宋体」「Georgia」。'
	String get fontNameHint => '填写字体名，如「宋体」「Georgia」。';

	/// zh: '字体名不能为空'
	String get fontNameEmpty => '字体名不能为空';

	/// zh: '这个范围里没有日记'
	String get scopeEmpty => '这个范围里没有日记';

	/// zh: '已取消导出'
	String get cancelled => '已取消导出';

	/// zh: '请先选择一个字体'
	String get pickFontFirst => '请先选择一个字体';

	/// zh: '导出 {count} 篇'
	String runButton({required Object count}) => '导出 ${count} 篇';

	/// zh: '导出完成，但有几处没带上'
	String get partialTitle => '导出完成，但有几处没带上';

	/// zh: '{count} 个媒体文件找不到，已跳过'
	String skippedMedia({required Object count}) => '${count} 个媒体文件找不到，已跳过';

	/// zh: '有 {count} 种内容这个版本还导不出：{types}'
	String unsupportedNodes({required Object count, required Object types}) => '有 ${count} 种内容这个版本还导不出：${types}';

	/// zh: '全部日记'
	String get scopeAll => '全部日记';

	/// zh: '按分类'
	String get scopeByCategory => '按分类';

	/// zh: '按时间'
	String get scopeByDate => '按时间';

	/// zh: '手动挑选'
	String get scopePicked => '手动挑选';

	/// zh: '已选 {count} 篇'
	String scopePickedLabel({required Object count}) => '已选 ${count} 篇';

	/// zh: '时间区间'
	String get dateRange => '时间区间';

	/// zh: '点击选择'
	String get tapToPick => '点击选择';

	/// zh: '{from} 至 {to}'
	String dateRangeValue({required Object from, required Object to}) => '${from} 至 ${to}';

	/// zh: '全选'
	String get selectAll => '全选';

	/// zh: '还没有选择'
	String get nothingSelected => '还没有选择';

	/// zh: '确定'
	String get confirm => '确定';

	/// zh: '未分类'
	String get uncategorized => '未分类';

	/// zh: '已删除分类'
	String get deletedCategory => '已删除分类';

	/// zh: 'PDF 字体'
	String get pdfFontPageTitle => 'PDF 字体';

	/// zh: '已导入的字体'
	String get importedFonts => '已导入的字体';

	/// zh: '导入字体'
	String get importFont => '导入字体';

	/// zh: '正在导入…'
	String get importingFont => '正在导入…';

	/// zh: '导入失败：{error}'
	String importFailed({required Object error}) => '导入失败：${error}';

	/// zh: '读不出字体名，文件可能已损坏'
	String get fontNameUnreadable => '读不出字体名，文件可能已损坏';

	/// zh: '还没有可用于 PDF 的字体'
	String get noPdfFontTitle => '还没有可用于 PDF 的字体';

	/// zh: '导入一个 .ttf 字体后可在此选择。'
	String get noPdfFontMessage => '导入一个 .ttf 字体后可在此选择。';

	/// zh: '正在转换 {done}/{total}'
	String progressConverting({required Object done, required Object total}) => '正在转换 ${done}/${total}';

	/// zh: '正在排版…'
	String get progressWriting => '正在排版…';

	/// zh: '正在排版 {done}/{total}'
	String progressWritingCount({required Object done, required Object total}) => '正在排版 ${done}/${total}';

	/// zh: '正在生成文件…'
	String get progressSerializing => '正在生成文件…';

	/// zh: '视频'
	String get mediaVideo => '视频';

	/// zh: '音频'
	String get mediaAudio => '音频';
}

// Path: lock
class Translations$lock$zh {
	Translations$lock$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '应用锁'
	String get title => '应用锁';

	/// zh: '已开启'
	String get enabled => '已开启';

	/// zh: '未开启'
	String get disabled => '未开启';

	/// zh: '开启后，每次启动应用都需要输入密码。'
	String get turnOnMessage => '开启后，每次启动应用都需要输入密码。';

	/// zh: '关闭后启动将不再需要密码。'
	String get turnOffMessage => '关闭后启动将不再需要密码。';

	/// zh: '去设置'
	String get turnOnAction => '去设置';

	/// zh: '去关闭'
	String get turnOffAction => '去关闭';

	/// zh: '修改密码'
	String get changePassword => '修改密码';

	/// zh: '立即锁定'
	String get lockNow => '立即锁定';

	/// zh: '退到后台后再回来需重新解锁'
	String get lockNowSubtitle => '退到后台后再回来需重新解锁';

	/// zh: '生物识别解锁'
	String get biometric => '生物识别解锁';

	/// zh: '用指纹 / 面容快速解锁'
	String get biometricSubtitle => '用指纹 / 面容快速解锁';

	/// zh: '已开启应用锁'
	String get turnedOn => '已开启应用锁';

	/// zh: '已关闭应用锁'
	String get turnedOff => '已关闭应用锁';

	/// zh: '密码已修改'
	String get passwordChanged => '密码已修改';

	/// zh: '设置密码'
	String get setPassword => '设置密码';

	/// zh: '确认密码'
	String get confirmPassword => '确认密码';

	/// zh: '两次输入不一致，请重新设置'
	String get mismatch => '两次输入不一致，请重新设置';

	/// zh: '密码保存失败，请重试'
	String get saveFailed => '密码保存失败，请重试';

	/// zh: '密码错误'
	String get wrongPassword => '密码错误';

	/// zh: '输入密码以关闭'
	String get enterToTurnOff => '输入密码以关闭';

	/// zh: '输入当前密码'
	String get verifyCurrent => '输入当前密码';

	/// zh: '设置新密码'
	String get enterNew => '设置新密码';

	/// zh: '确认新密码'
	String get confirmNew => '确认新密码';

	/// zh: '请输入密码'
	String get prompt => '请输入密码';

	/// zh: '密码错误，还可重试 {count} 次'
	String attemptsLeft({required Object count}) => '密码错误，还可重试 ${count} 次';

	/// zh: '尝试次数过多，请等待 {seconds} 秒'
	String cooldown({required Object seconds}) => '尝试次数过多，请等待 ${seconds} 秒';

	/// zh: '安全验证'
	String get biometricReason => '安全验证';
}

// Path: media
class Translations$media$zh {
	Translations$media$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '媒体库'
	String get title => '媒体库';

	/// zh: '图片'
	String get typeImage => '图片';

	/// zh: '清理无用文件'
	String get deleteUseLessFile => '清理无用文件';

	/// zh: '这里还没有媒体'
	String get empty => '这里还没有媒体';

	/// zh: '正在扫描无用文件'
	String get cleanupScanning => '正在扫描无用文件';

	/// zh: '没有发现无用文件'
	String get cleanupEmpty => '没有发现无用文件';

	/// zh: '清理无用文件'
	String get cleanupConfirmTitle => '清理无用文件';

	/// zh: '发现 {count} 个未被任何日记引用的文件（{size}），确认清理？此操作不可恢复。'
	String cleanupConfirmMessage({required Object count, required Object size}) => '发现 ${count} 个未被任何日记引用的文件（${size}），确认清理？此操作不可恢复。';

	/// zh: '已清理 {count} 个文件'
	String cleanupDone({required Object count}) => '已清理 ${count} 个文件';

	/// zh: '重命名'
	String get rename => '重命名';

	/// zh: '(other) {{count} 张照片}'
	String imageCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 张照片',
	);

	/// zh: '(other) {{count} 段音频}'
	String audioCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 段音频',
	);

	/// zh: '(other) {{count} 段视频}'
	String videoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 段视频',
	);
}

// Path: onboarding
class Translations$onboarding$zh {
	Translations$onboarding$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '欢迎使用 Moodiary'
	String get welcomeTitle => '欢迎使用 Moodiary';

	/// zh: '一本离线优先的私密日记，数据默认只留在你的设备上。'
	String get welcomeBody => '一本离线优先的私密日记，数据默认只留在你的设备上。';

	/// zh: '记录每一种情绪'
	String get moodTitle => '记录每一种情绪';

	/// zh: '心情、分类、标签随心组织，写作时长与字数实时可见。'
	String get moodBody => '心情、分类、标签随心组织，写作时长与字数实时可见。';

	/// zh: '数据始终归你掌控'
	String get ownershipTitle => '数据始终归你掌控';

	/// zh: '一键导出 JSON 备份，也可开启 WebDAV / S3 云同步，端到端加密可选。'
	String get ownershipBody => '一键导出 JSON 备份，也可开启 WebDAV / S3 云同步，端到端加密可选。';

	/// zh: '跳过'
	String get skip => '跳过';

	/// zh: '下一步'
	String get next => '下一步';

	/// zh: '开始记录'
	String get start => '开始记录';

	/// zh: '用户协议'
	String get userAgreement => '用户协议';

	/// zh: '隐私政策'
	String get privacyPolicy => '隐私政策';
}

// Path: picker
class Translations$picker$zh {
	Translations$picker$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '最近'
	String get recentAlbum => '最近';

	/// zh: '完成'
	String get done => '完成';

	/// zh: '完成 {count}/{max}'
	String doneCount({required Object count, required Object max}) => '完成 ${count}/${max}';

	/// zh: '你只允许应用访问部分照片'
	String get limitedTip => '你只允许应用访问部分照片';

	/// zh: '管理'
	String get limitedManage => '管理';

	/// zh: '请前往设置中开启相册权限'
	String get permissionDenied => '请前往设置中开启相册权限';

	/// zh: '选择'
	String get a11ySelect => '选择';

	/// zh: '取消选择'
	String get a11yUnselect => '取消选择';

	/// zh: '拍摄'
	String get capture => '拍摄';

	/// zh: '录像'
	String get record => '录像';

	/// zh: '拍摄失败'
	String get captureFailed => '拍摄失败';
}

// Path: share
class Translations$share$zh {
	Translations$share$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '分享'
	String get title => '分享';

	/// zh: '没有可分享的日记'
	String get empty => '没有可分享的日记';

	/// zh: '复制文本'
	String get copyText => '复制文本';

	/// zh: '导出图片'
	String get exportImage => '导出图片';

	/// zh: '已复制到剪贴板'
	String get copied => '已复制到剪贴板';

	/// zh: '来自 Moodiary 的分享'
	String get subject => '来自 Moodiary 的分享';

	/// zh: '已生成图片：{path}（路径已复制）'
	String imageSaved({required Object path}) => '已生成图片：${path}（路径已复制）';

	/// zh: '简约'
	String get templateMinimal => '简约';

	/// zh: '便签'
	String get templateNote => '便签';
}

// Path: sync
class Translations$sync$zh {
	Translations$sync$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: 'WebDAV'
	String get backupSyncWebdav => 'WebDAV';

	/// zh: '未配置'
	String get backupSyncWebdavNoOption => '未配置';

	/// zh: '已配置'
	String get backupSyncWebdavOption => '已配置';

	/// zh: '服务器地址'
	String get webdavOptionServer => '服务器地址';

	/// zh: '用户名'
	String get webdavOptionUsername => '用户名';

	/// zh: '密码'
	String get webdavOptionPassword => '密码';

	/// zh: 'S3 / MinIO'
	String get backupSyncS3 => 'S3 / MinIO';

	/// zh: 'Endpoint'
	String get s3OptionEndpoint => 'Endpoint';

	/// zh: 'Region'
	String get s3OptionRegion => 'Region';

	/// zh: 'Bucket'
	String get s3OptionBucket => 'Bucket';

	/// zh: 'Access Key'
	String get s3OptionAccessKey => 'Access Key';

	/// zh: 'Secret Key'
	String get s3OptionSecretKey => 'Secret Key';

	/// zh: '使用 HTTPS'
	String get s3OptionUseSsl => '使用 HTTPS';

	/// zh: '连接'
	String get sectionConnection => '连接';

	/// zh: '凭证'
	String get sectionCredentials => '凭证';

	/// zh: '选项'
	String get sectionOptions => '选项';

	/// zh: '清除配置'
	String get configClear => '清除配置';

	/// zh: '清除配置？'
	String get configClearConfirmTitle => '清除配置？';

	/// zh: '清除后将停止与该后端同步，本地日记不受影响。'
	String get configClearConfirmMessage => '清除后将停止与该后端同步，本地日记不受影响。';

	/// zh: '已清除配置'
	String get configCleared => '已清除配置';

	/// zh: '{field: String}不能为空'
	String fieldRequired({required String field}) => '${field}不能为空';

	/// zh: '可留空'
	String get fieldOptional => '可留空';

	/// zh: '地址格式不正确'
	String get fieldInvalidUrl => '地址格式不正确';

	/// zh: '备份与同步'
	String get pageTitle => '备份与同步';

	/// zh: '云端同步'
	String get cloudSection => '云端同步';

	/// zh: '同步方式'
	String get method => '同步方式';

	/// zh: '{name} 配置'
	String methodConfig({required Object name}) => '${name} 配置';

	/// zh: '未配置（点击设置）'
	String get notConfiguredTap => '未配置（点击设置）';

	/// zh: '测试连接'
	String get testConnection => '测试连接';

	/// zh: '正在测试连接...'
	String get testing => '正在测试连接...';

	/// zh: '连接成功'
	String get connectOk => '连接成功';

	/// zh: '连接失败：{error}'
	String connectFailed({required Object error}) => '连接失败：${error}';

	/// zh: '请先完成配置'
	String get configureFirst => '请先完成配置';

	/// zh: '完成：{message}'
	String doneToast({required Object message}) => '完成：${message}';

	/// zh: '失败：{message}'
	String failedToast({required Object message}) => '失败：${message}';

	/// zh: '正在停止…'
	String get stopping => '正在停止…';

	/// zh: '停止同步'
	String get stop => '停止同步';

	/// zh: '等待当前条目完成后收尾'
	String get stoppingSubtitle => '等待当前条目完成后收尾';

	/// zh: '正在后台同步，点击停止'
	String get stopSubtitle => '正在后台同步，点击停止';

	/// zh: '将在当前条目完成后停止'
	String get willStop => '将在当前条目完成后停止';

	/// zh: '立即同步'
	String get syncNow => '立即同步';

	/// zh: '上次同步：{time}'
	String lastSync({required Object time}) => '上次同步：${time}';

	/// zh: '尚未同步'
	String get neverSynced => '尚未同步';

	/// zh: '同步日志'
	String get logEntry => '同步日志';

	/// zh: '按日期查看同步事件'
	String get logEntrySubtitle => '按日期查看同步事件';

	/// zh: '局域网同步'
	String get lanSection => '局域网同步';

	/// zh: '发送'
	String get lanSend => '发送';

	/// zh: '发送日记到同一 Wi-Fi 下的设备'
	String get lanSendSubtitle => '发送日记到同一 Wi-Fi 下的设备';

	/// zh: '接收'
	String get lanReceive => '接收';

	/// zh: '等待其它设备发送到本机'
	String get lanReceiveSubtitle => '等待其它设备发送到本机';

	/// zh: '加密'
	String get encryptionSection => '加密';

	/// zh: '自动同步'
	String get autoSection => '自动同步';

	/// zh: '自动同步'
	String get autoSync => '自动同步';

	/// zh: '日记变更后自动推送，并定时拉取其它设备的变更'
	String get autoSyncSubtitle => '日记变更后自动推送，并定时拉取其它设备的变更';

	/// zh: '轮询间隔'
	String get pollInterval => '轮询间隔';

	/// zh: '每隔此时间在后台拉取其它设备的变更'
	String get pollIntervalSubtitle => '每隔此时间在后台拉取其它设备的变更';

	/// zh: '每隔此时间在后台跑一次双向同步。间隔越短，与其它设备的变更同步越及时；但每次轮询都会抢占远端锁、读取清单并发起网络请求 —— 间隔过短会显著增加流量与耗电，还可能触发 WebDAV / S3 服务端限流甚至临时封禁。建议不低于 30 秒。'
	String get pollIntervalNote => '每隔此时间在后台跑一次双向同步。间隔越短，与其它设备的变更同步越及时；但每次轮询都会抢占远端锁、读取清单并发起网络请求 —— 间隔过短会显著增加流量与耗电，还可能触发 WebDAV / S3 服务端限流甚至临时封禁。建议不低于 30 秒。';

	/// zh: '网络'
	String get networkSection => '网络';

	/// zh: '并发请求数'
	String get concurrency => '并发请求数';

	/// zh: '同步时同时进行的网络请求上限，弱网或服务端限流时调小'
	String get concurrencySubtitle => '同步时同时进行的网络请求上限，弱网或服务端限流时调小';

	/// zh: '默认 8。值越大同步越快，但可能触发 WebDAV / S3 服务端限流或连接拒绝。'
	String get concurrencyNote => '默认 8。值越大同步越快，但可能触发 WebDAV / S3 服务端限流或连接拒绝。';

	/// zh: '{count} 秒'
	String seconds({required Object count}) => '${count} 秒';

	/// zh: '{count} 分钟'
	String minutes({required Object count}) => '${count} 分钟';

	/// zh: '{minutes} 分 {seconds} 秒'
	String minutesSeconds({required Object minutes, required Object seconds}) => '${minutes} 分 ${seconds} 秒';

	/// zh: '同步日志'
	String get logTitle => '同步日志';

	/// zh: '选择日期'
	String get logPickDate => '选择日期';

	/// zh: '按日期筛选'
	String get logFilterByDate => '按日期筛选';

	/// zh: '今天'
	String get logToday => '今天';

	/// zh: '（今天）'
	String get logTodaySuffix => '（今天）';

	/// zh: '清空日志'
	String get logClear => '清空日志';

	/// zh: '将删除内存中的事件流和按天滚动的所有 jsonl 文件，操作不可恢复。'
	String get logClearMessage => '将删除内存中的事件流和按天滚动的所有 jsonl 文件，操作不可恢复。';

	/// zh: '{count} 条'
	String logEventCount({required Object count}) => '${count} 条';

	/// zh: '该日期暂无同步事件'
	String get logEmpty => '该日期暂无同步事件';

	/// zh: '{kind} · {count} 条'
	String logGroupCount({required Object kind, required Object count}) => '${kind} · ${count} 条';

	/// zh: '事件详情'
	String get logDetail => '事件详情';

	/// zh: '复制'
	String get logCopy => '复制';

	/// zh: '同步开始'
	String get kindSyncStart => '同步开始';

	/// zh: '同步结束'
	String get kindSyncEnd => '同步结束';

	/// zh: '读取清单'
	String get kindManifestRead => '读取清单';

	/// zh: '写回清单'
	String get kindManifestWrite => '写回清单';

	/// zh: '上传日记'
	String get kindDiaryUpload => '上传日记';

	/// zh: '下载日记'
	String get kindDiaryDownload => '下载日记';

	/// zh: '跳过日记'
	String get kindDiarySkip => '跳过日记';

	/// zh: '推送日记删除'
	String get kindDiaryTombstonePush => '推送日记删除';

	/// zh: '同步日记删除'
	String get kindDiaryTombstonePull => '同步日记删除';

	/// zh: '上传分类'
	String get kindCategoryUpload => '上传分类';

	/// zh: '下载分类'
	String get kindCategoryDownload => '下载分类';

	/// zh: '跳过分类'
	String get kindCategorySkip => '跳过分类';

	/// zh: '推送分类删除'
	String get kindCategoryTombstonePush => '推送分类删除';

	/// zh: '同步分类删除'
	String get kindCategoryTombstonePull => '同步分类删除';

	/// zh: '上传媒体'
	String get kindMediaUpload => '上传媒体';

	/// zh: '下载媒体'
	String get kindMediaDownload => '下载媒体';

	/// zh: '跳过媒体'
	String get kindMediaSkip => '跳过媒体';

	/// zh: '删除媒体'
	String get kindMediaDelete => '删除媒体';

	/// zh: '获取同步锁'
	String get kindLockAcquire => '获取同步锁';

	/// zh: '释放同步锁'
	String get kindLockRelease => '释放同步锁';

	/// zh: '错误'
	String get kindError => '错误';

	/// zh: '同步状态'
	String get statusTitle => '同步状态';

	/// zh: '{backend} · {encryption}'
	String statusSubtitle({required Object backend, required Object encryption}) => '${backend} · ${encryption}';

	/// zh: '已加密'
	String get encrypted => '已加密';

	/// zh: '未加密'
	String get notEncrypted => '未加密';

	/// zh: '查看日志'
	String get viewLog => '查看日志';

	/// zh: '数据概览'
	String get overview => '数据概览';

	/// zh: '刷新数据概览'
	String get overviewRefresh => '刷新数据概览';

	/// zh: '远端有 {count} 篇日记待拉取'
	String pendingPull({required Object count}) => '远端有 ${count} 篇日记待拉取';

	/// zh: '同步完成'
	String get statusDone => '同步完成';

	/// zh: '同步失败'
	String get statusFailed => '同步失败';

	/// zh: '未配置同步后端'
	String get statusNoBackend => '未配置同步后端';

	/// zh: '去「备份与同步」填一个'
	String get statusNoBackendDetail => '去「备份与同步」填一个';

	/// zh: '已同步'
	String get statusSynced => '已同步';

	/// zh: '上次同步 '
	String get statusLastSync => '上次同步 ';

	/// zh: '尚未同步'
	String get statusNever => '尚未同步';

	/// zh: '本地'
	String get columnLocal => '本地';

	/// zh: '远端'
	String get columnRemote => '远端';

	/// zh: '日记'
	String get rowDiary => '日记';

	/// zh: '分类'
	String get rowCategory => '分类';

	/// zh: '媒体'
	String get rowMedia => '媒体';

	/// zh: '正在同步'
	String get statusRunning => '正在同步';

	/// zh: '局域网发送'
	String get lanSendTitle => '局域网发送';

	/// zh: '只发送对方缺少的内容，按最后修改时间自动合并，重复发送不会产生重复数据。'
	String get lanSendIntro => '只发送对方缺少的内容，按最后修改时间自动合并，重复发送不会产生重复数据。';

	/// zh: '附近的设备'
	String get lanNearbyDevices => '附近的设备';

	/// zh: '接收方地址'
	String get lanReceiverAddress => '接收方地址';

	/// zh: '选择上方设备后自动填写'
	String get lanAddressHint => '选择上方设备后自动填写';

	/// zh: '配对码'
	String get lanPin => '配对码';

	/// zh: '输入接收页显示的 6 位数字'
	String get lanPinHint => '输入接收页显示的 6 位数字';

	/// zh: '发送'
	String get lanSendAction => '发送';

	/// zh: '请先选择接收设备'
	String get lanPickDevice => '请先选择接收设备';

	/// zh: '请输入 6 位配对码'
	String get lanNeedPin => '请输入 6 位配对码';

	/// zh: '地址格式不正确'
	String get lanBadAddress => '地址格式不正确';

	/// zh: '正在搜索，请在接收设备上打开「接收」页'
	String get lanSearching => '正在搜索，请在接收设备上打开「接收」页';

	/// zh: '正在连接…'
	String get lanConnecting => '正在连接…';

	/// zh: '正在准备数据…'
	String get lanPacking => '正在准备数据…';

	/// zh: '正在发送'
	String get lanUploading => '正在发送';

	/// zh: '等待对方保存…'
	String get lanApplying => '等待对方保存…';

	/// zh: '局域网接收'
	String get lanReceiveTitle => '局域网接收';

	/// zh: '无法启动接收：{error}'
	String lanStartFailed({required Object error}) => '无法启动接收：${error}';

	/// zh: '配对码已复制'
	String get lanPinCopied => '配对码已复制';

	/// zh: '在发送设备上输入 · 轻点复制'
	String get lanPinHelp => '在发送设备上输入 · 轻点复制';

	/// zh: '地址已复制'
	String get lanAddressCopied => '地址已复制';

	/// zh: '内容已是最新，没有变更'
	String get lanUpToDate => '内容已是最新，没有变更';

	/// zh: '日记 {diary} 条 · 分类 {category} 条'
	String lanReceived({required Object diary, required Object category}) => '日记 ${diary} 条 · 分类 ${category} 条';

	/// zh: '{base}（{failed} 条失败）'
	String lanReceivedFailed({required Object base, required Object failed}) => '${base}（${failed} 条失败）';

	/// zh: '等待发送方连接…'
	String get lanWaiting => '等待发送方连接…';

	/// zh: '正在接收'
	String get lanReceiving => '正在接收';

	/// zh: '正在保存…'
	String get lanSaving => '正在保存…';

	/// zh: '接收完成'
	String get lanDone => '接收完成';

	/// zh: '可继续接收，配对码不变'
	String get lanDoneHint => '可继续接收，配对码不变';

	/// zh: '接收失败'
	String get lanFailed => '接收失败';

	/// zh: '配对码不变，对方可直接重试'
	String get lanFailedHint => '配对码不变，对方可直接重试';

	/// zh: '本机地址'
	String get lanLocalAddress => '本机地址';

	/// zh: '未连接 Wi-Fi，无法获取本机地址'
	String get lanNoWifi => '未连接 Wi-Fi，无法获取本机地址';

	/// zh: '远端数据已加密但缺少密钥文件（keys.json），无法解密。请清空远端数据后重新上传。'
	String get keyGuardMissing => '远端数据已加密但缺少密钥文件（keys.json），无法解密。请清空远端数据后重新上传。';

	/// zh: '远端备份已加密'
	String get keyGuardTitle => '远端备份已加密';

	/// zh: '当前设备的密钥无法解密远端数据。请输入与原设备一致的加密密码，验证通过后开始同步。'
	String get keyGuardMessageMismatch => '当前设备的密钥无法解密远端数据。请输入与原设备一致的加密密码，验证通过后开始同步。';

	/// zh: '远端数据已加密。请输入与原设备一致的加密密码，验证通过后开始同步。'
	String get keyGuardMessage => '远端数据已加密。请输入与原设备一致的加密密码，验证通过后开始同步。';

	/// zh: '加密密码'
	String get keyGuardHint => '加密密码';

	/// zh: '验证并保存'
	String get keyGuardConfirm => '验证并保存';

	/// zh: '请输入密码'
	String get keyNeedPassword => '请输入密码';

	/// zh: '密码不正确，无法解密远端数据'
	String get keyGuardWrong => '密码不正确，无法解密远端数据';

	/// zh: '密钥已配置'
	String get keyConfigured => '密钥已配置';

	/// zh: '端到端加密'
	String get e2eTitle => '端到端加密';

	/// zh: '已开启'
	String get e2eOn => '已开启';

	/// zh: '未开启'
	String get e2eOff => '未开启';

	/// zh: '管理加密'
	String get e2eManage => '管理加密';

	/// zh: '密码不正确'
	String get keyWrong => '密码不正确';

	/// zh: '验证成功'
	String get keyVerified => '验证成功';

	/// zh: '请先验证当前密码'
	String get keyVerifyFirst => '请先验证当前密码';

	/// zh: '两次输入的密码不一致'
	String get keyMismatch => '两次输入的密码不一致';

	/// zh: '加密管理'
	String get keyManageTitle => '加密管理';

	/// zh: '当前密码'
	String get keyCurrent => '当前密码';

	/// zh: '验证'
	String get keyVerify => '验证';

	/// zh: '新密码'
	String get keyNew => '新密码';

	/// zh: '加密密码'
	String get keyPassword => '加密密码';

	/// zh: '确认密码'
	String get keyConfirm => '确认密码';

	/// zh: '关闭加密'
	String get keyTurnOff => '关闭加密';

	/// zh: '密码已更换（数据密钥不变，云端无需重新加密）'
	String get keyChanged => '密码已更换（数据密钥不变，云端无需重新加密）';

	/// zh: '加密云端已有数据'
	String get keyEncryptCloudTitle => '加密云端已有数据';

	/// zh: '检测到当前同步后端已存在数据。确认后会生成随机数据密钥并加密云端的日记、分类与媒体文件；该密钥由你的密码封装存放在云端。'
	String get keyEncryptCloudMessage => '检测到当前同步后端已存在数据。确认后会生成随机数据密钥并加密云端的日记、分类与媒体文件；该密钥由你的密码封装存放在云端。';

	/// zh: '继续'
	String get keyContinue => '继续';

	/// zh: '密钥文件写入云端失败，已取消：{error}'
	String keyWriteFailed({required Object error}) => '密钥文件写入云端失败，已取消：${error}';

	/// zh: '云端已加密：{report}'
	String keyCloudEncrypted({required Object report}) => '云端已加密：${report}';

	/// zh: '加密已开启'
	String get keyEncryptionOn => '加密已开启';

	/// zh: '解密云端数据'
	String get keyDecryptTitle => '解密云端数据';

	/// zh: '关闭加密后，云端的日记、分类与媒体文件会被解密回明文，密钥文件将被删除。确认要继续吗？'
	String get keyDecryptMessage => '关闭加密后，云端的日记、分类与媒体文件会被解密回明文，密钥文件将被删除。确认要继续吗？';

	/// zh: '加密已关闭'
	String get keyEncryptionOff => '加密已关闭';

	/// zh: '重新加密失败：{error}'
	String keyReCipherFailed({required Object error}) => '重新加密失败：${error}';

	/// zh: '远端为空，仅保存本地密钥'
	String get keyRemoteEmpty => '远端为空，仅保存本地密钥';

	/// zh: '正在处理云端数据'
	String get keyProcessing => '正在处理云端数据';

	/// zh: '准备'
	String get keyPreparing => '准备';

	/// zh: '发送方通常会自动发现本机，也可手动输入上方地址。接收期间请保持本页打开。'
	String get lanReceiveHint => '发送方通常会自动发现本机，也可手动输入上方地址。接收期间请保持本页打开。';

	/// zh: '远端密钥文件已损坏（非 JSON 对象）'
	String get errKeyfileCorrupt => '远端密钥文件已损坏（非 JSON 对象）';

	/// zh: '远端密钥文件已损坏（KDF 参数缺失）'
	String get errKeyfileKdfMissing => '远端密钥文件已损坏（KDF 参数缺失）';

	/// zh: '远端密钥文件的 KDF 参数超出允许范围'
	String get errKeyfileKdfRange => '远端密钥文件的 KDF 参数超出允许范围';

	/// zh: '远端密钥文件解析失败：{error}'
	String errKeyfileParse({required Object error}) => '远端密钥文件解析失败：${error}';

	/// zh: '远端密钥文件已损坏（字段缺失）'
	String get errKeyfileFields => '远端密钥文件已损坏（字段缺失）';

	/// zh: '远端密钥文件版本不兼容（v{version}，本机支持 ≤ v{supported}），请升级客户端'
	String errKeyfileVersion({required Object version, required Object supported}) => '远端密钥文件版本不兼容（v${version}，本机支持 ≤ v${supported}），请升级客户端';

	/// zh: '远端 manifest 已损坏（非 JSON 对象），已中止同步以防丢失远端条目'
	String get errManifestCorrupt => '远端 manifest 已损坏（非 JSON 对象），已中止同步以防丢失远端条目';

	/// zh: '远端 manifest 格式异常，无法重新加密'
	String get errManifestReCipher => '远端 manifest 格式异常，无法重新加密';

	/// zh: 'manifest 写入被其它设备并发覆盖，已中止重新加密'
	String get errManifestRace => 'manifest 写入被其它设备并发覆盖，已中止重新加密';

	/// zh: '不是有效的 Moodiary 备份文件'
	String get errNotBackup => '不是有效的 Moodiary 备份文件';

	/// zh: '这是 2.8.0 之前版本的备份，新版不支持导入；请先在旧版本中恢复，再升级到新版'
	String get errLegacyBackup => '这是 2.8.0 之前版本的备份，新版不支持导入；请先在旧版本中恢复，再升级到新版';

	/// zh: '备份文件解析失败：{error}'
	String errBackupParse({required Object error}) => '备份文件解析失败：${error}';

	/// zh: '对方不是 Moodiary 局域网接收端'
	String get errNotReceiver => '对方不是 Moodiary 局域网接收端';

	/// zh: '版本不兼容，请将两台设备的 Moodiary 升级到同一版本'
	String get errVersionMismatch => '版本不兼容，请将两台设备的 Moodiary 升级到同一版本';

	/// zh: '对方设备未在接收，请确认已打开「局域网接收」'
	String get errReceiverOffline => '对方设备未在接收，请确认已打开「局域网接收」';

	/// zh: '请先完成 S3 配置'
	String get errS3Config => '请先完成 S3 配置';

	/// zh: '请先完成 WebDAV 配置'
	String get errWebdavConfig => '请先完成 WebDAV 配置';

	/// zh: '密码不正确，无法解开密钥文件'
	String get errWrongKeyPassword => '密码不正确，无法解开密钥文件';

	/// zh: '密钥派生失败：{error}'
	String errKdf({required Object error}) => '密钥派生失败：${error}';

	/// zh: '另一台设备正在同步，请稍后再试'
	String get errLocked => '另一台设备正在同步，请稍后再试';

	/// zh: '部分媒体文件上传失败，已跳过此日记'
	String get errMediaUpload => '部分媒体文件上传失败，已跳过此日记';

	/// zh: '远端文件已加密，但当前未配置用户密钥'
	String get errNoUserKey => '远端文件已加密，但当前未配置用户密钥';

	/// zh: '读取远端对象失败（{key}）：{error}'
	String errReadRemote({required Object key, required Object error}) => '读取远端对象失败（${key}）：${error}';

	/// zh: '条件创建远端对象失败（{key}）：{error}'
	String errCreateRemote({required Object key, required Object error}) => '条件创建远端对象失败（${key}）：${error}';

	/// zh: '尚未配置同步后端'
	String get errNoBackend => '尚未配置同步后端';

	/// zh: '远端 manifest 格式异常'
	String get errManifestBroken => '远端 manifest 格式异常';

	/// zh: '上传 / 导出中：{backend}'
	String uploading({required Object backend}) => '上传 / 导出中：${backend}';

	/// zh: '下载 / 导入中：{backend}'
	String downloading({required Object backend}) => '下载 / 导入中：${backend}';

	/// zh: '同步中：{backend}'
	String syncing({required Object backend}) => '同步中：${backend}';

	/// zh: '云端同步中：{parts}'
	String pendingSummary({required Object parts}) => '云端同步中：${parts}';

	/// zh: '{count} 篇待下载'
	String pendingNew({required Object count}) => '${count} 篇待下载';

	/// zh: '{count} 篇待更新'
	String pendingUpdate({required Object count}) => '${count} 篇待更新';

	/// zh: '远端为空（尚未上传任何备份）'
	String get warnRemoteEmpty => '远端为空（尚未上传任何备份）';

	/// zh: '{count} 个条目同步失败已跳过'
	String warnFailedSkipped({required Object count}) => '${count} 个条目同步失败已跳过';

	/// zh: '已手动停止，剩余条目将在下次同步继续'
	String get warnStopped => '已手动停止，剩余条目将在下次同步继续';

	/// zh: '{count} 条失败'
	String warnFailedCount({required Object count}) => '${count} 条失败';

	/// zh: '日记 {diary} + 分类 {category} + 媒体信息 {mediaInfo} + 媒体 {media}（耗时 {ms}ms）'
	String reCipherSummary({required Object diary, required Object category, required Object mediaInfo, required Object media, required Object ms}) => '日记 ${diary} + 分类 ${category} + 媒体信息 ${mediaInfo} + 媒体 ${media}（耗时 ${ms}ms）';

	/// zh: '{base} {failed} 个对象失败已跳过'
	String reCipherFailedSuffix({required Object base, required Object failed}) => '${base}\n${failed} 个对象失败已跳过';

	/// zh: '准备'
	String get stepPrepare => '准备';

	/// zh: '日记 {id}'
	String stepDiary({required Object id}) => '日记 ${id}';

	/// zh: '分类 {id}'
	String stepCategory({required Object id}) => '分类 ${id}';

	/// zh: '媒体信息 {id}'
	String stepMediaInfo({required Object id}) => '媒体信息 ${id}';

	/// zh: '媒体 {ref}'
	String stepMedia({required Object ref}) => '媒体 ${ref}';

	/// zh: '写回 manifest'
	String get stepManifest => '写回 manifest';
}

// Path: ui
class Translations$ui$zh {
	Translations$ui$zh.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// zh: '保存到相册'
	String get imageBrowserSave => '保存到相册';

	/// zh: '已保存到相册'
	String get imageBrowserSaved => '已保存到相册';

	/// zh: '保存失败'
	String get imageBrowserSaveFailed => '保存失败';

	/// zh: '图片信息'
	String get imageBrowserInfo => '图片信息';

	/// zh: '链接'
	String get imageBrowserInfoUrl => '链接';

	/// zh: '分辨率'
	String get imageBrowserInfoResolution => '分辨率';

	/// zh: '大小'
	String get imageBrowserInfoSize => '大小';

	/// zh: '格式'
	String get imageBrowserInfoFormat => '格式';

	/// zh: '修改时间'
	String get imageBrowserInfoModified => '修改时间';

	/// zh: '视频加载失败'
	String get videoPlayerLoadFailed => '视频加载失败';

	/// zh: '播放'
	String get play => '播放';

	/// zh: '暂停'
	String get pause => '暂停';

	/// zh: '播放进度'
	String get playbackProgress => '播放进度';

	/// zh: '重播'
	String get videoPlayerReplay => '重播';

	/// zh: '亮度'
	String get videoPlayerBrightness => '亮度';

	/// zh: '音量'
	String get videoPlayerVolume => '音量';

	/// zh: '{speed: String}× 倍速播放中'
	String videoPlayerSpeedBoost({required String speed}) => '${speed}× 倍速播放中';
}
