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

	/// zh: '确认'
	String get ok => '确认';

	/// zh: '取消'
	String get cancel => '取消';

	/// zh: '更多'
	String get more => '更多';

	/// zh: '主题色'
	String get accentTitle => '主题色';

	/// zh: '默认'
	String get accentNeutral => '默认';

	/// zh: '壁纸取色'
	String get accentSystem => '壁纸取色';

	/// zh: '自定义'
	String get accentCustom => '自定义';

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

	/// zh: '保存'
	String get save => '保存';

	/// zh: 'Moodiary'
	String get appName => 'Moodiary';

	/// zh: '智能助手'
	String get settingFunctionAIAssistant => '智能助手';

	/// zh: '语言'
	String get settingLanguage => '语言';

	/// zh: '跟随系统'
	String get settingLanguageSystem => '跟随系统';

	/// zh: '简体中文'
	String get settingLanguageSimpleChinese => '简体中文';

	/// zh: 'English'
	String get settingLanguageEnglish => 'English';

	/// zh: '日记'
	String get homeNavigatorDiary => '日记';

	/// zh: '媒体'
	String get homeNavigatorMedia => '媒体';

	/// zh: '设置'
	String get homeNavigatorSetting => '设置';

	/// zh: '助手'
	String get homeNavigatorAssistant => '助手';

	/// zh: '新建日记'
	String get homePageAddDiaryButton => '新建日记';

	/// zh: '这里一片荒芜'
	String get diaryTabViewEmpty => '这里一片荒芜';

	/// zh: '视图模式'
	String get diaryPageViewModeButton => '视图模式';

	/// zh: '媒体库'
	String get mediaTitle => '媒体库';

	/// zh: '图片'
	String get mediaTypeImage => '图片';

	/// zh: '音频'
	String get mediaTypeAudio => '音频';

	/// zh: '视频'
	String get mediaTypeVideo => '视频';

	/// zh: '清理无用文件'
	String get mediaDeleteUseLessFile => '清理无用文件';

	/// zh: '这里还没有媒体'
	String get mediaEmpty => '这里还没有媒体';

	/// zh: '正在扫描无用文件'
	String get mediaCleanupScanning => '正在扫描无用文件';

	/// zh: '没有发现无用文件'
	String get mediaCleanupEmpty => '没有发现无用文件';

	/// zh: '清理无用文件'
	String get mediaCleanupConfirmTitle => '清理无用文件';

	/// zh: '发现 {count} 个未被任何日记引用的文件（{size}），确认清理？此操作不可恢复。'
	String mediaCleanupConfirmMessage({required Object count, required Object size}) => '发现 ${count} 个未被任何日记引用的文件（${size}），确认清理？此操作不可恢复。';

	/// zh: '已清理 {count} 个文件'
	String mediaCleanupDone({required Object count}) => '已清理 ${count} 个文件';

	/// zh: 'WebDAV'
	String get backupSyncWebdav => 'WebDAV';

	/// zh: '未配置'
	String get backupSyncWebdavNoOption => '未配置';

	/// zh: '已配置'
	String get backupSyncWebdavOption => '已配置';

	/// zh: '无分类'
	String get categoryNoCategory => '无分类';

	/// zh: '全部分类'
	String get categoryAllCategory => '全部分类';

	/// zh: '全部'
	String get categoryAll => '全部';

	/// zh: '颜色'
	String get categoryColorLabel => '颜色';

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
	String get syncSectionConnection => '连接';

	/// zh: '凭证'
	String get syncSectionCredentials => '凭证';

	/// zh: '选项'
	String get syncSectionOptions => '选项';

	/// zh: '清除配置'
	String get syncConfigClear => '清除配置';

	/// zh: '清除配置？'
	String get syncConfigClearConfirmTitle => '清除配置？';

	/// zh: '清除后将停止与该后端同步，本地日记不受影响。'
	String get syncConfigClearConfirmMessage => '清除后将停止与该后端同步，本地日记不受影响。';

	/// zh: '已清除配置'
	String get syncConfigCleared => '已清除配置';

	/// zh: '{field: String}不能为空'
	String syncFieldRequired({required String field}) => '${field}不能为空';

	/// zh: '可留空'
	String get syncFieldOptional => '可留空';

	/// zh: '地址格式不正确'
	String get syncFieldInvalidUrl => '地址格式不正确';

	/// zh: '请开启定位权限'
	String get noticeEnableLocation => '请开启定位权限';

	/// zh: '请前往设置中开启定位权限'
	String get noticeEnableLocation2 => '请前往设置中开启定位权限';

	/// zh: '请前往设置中开启相册权限'
	String get noticeEnablePhotoPermission => '请前往设置中开启相册权限';

	/// zh: '请前往设置中开启相机权限'
	String get noticeEnableCameraPermission => '请前往设置中开启相机权限';

	/// zh: '最近'
	String get pickerRecentAlbum => '最近';

	/// zh: '搜索'
	String get diarySearch => '搜索';

	/// zh: '共有 {count} 篇'
	String diarySearchResult({required Object count}) => '共有 ${count} 篇';

	/// zh: '耗时 {ms}ms'
	String diarySearchTime({required Object ms}) => '耗时 ${ms}ms';

	/// zh: '全部时间'
	String get searchRangeAll => '全部时间';

	/// zh: '近 7 天'
	String get searchRange7d => '近 7 天';

	/// zh: '近 30 天'
	String get searchRange30d => '近 30 天';

	/// zh: '今年'
	String get searchRangeYear => '今年';

	/// zh: '自定义'
	String get searchRangeCustom => '自定义';

	/// zh: '全部分类'
	String get searchCategoryAll => '全部分类';

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

	/// zh: '选择图片'
	String get editPickImage => '选择图片';

	/// zh: '拍照'
	String get editPickImageFromCamera => '拍照';

	/// zh: '相册'
	String get editPickImageFromGallery => '相册';

	/// zh: '选择视频'
	String get editPickVideo => '选择视频';

	/// zh: '录像'
	String get editPickVideoFromCamera => '录像';

	/// zh: '相册'
	String get editPickVideoFromGallery => '相册';

	/// zh: '选择音频'
	String get editPickAudio => '选择音频';

	/// zh: '录音'
	String get editPickAudioFromRecord => '录音';

	/// zh: '音频文件'
	String get editPickAudioFromFile => '音频文件';

	/// zh: '分类'
	String get editCategory => '分类';

	/// zh: '正文'
	String get editContent => '正文';

	/// zh: '音频文件错误'
	String get audioFileError => '音频文件错误';

	/// zh: '名称'
	String get audioNameLabel => '名称';

	/// zh: '音频'
	String get audioDefaultName => '音频';

	/// zh: '重命名'
	String get mediaRename => '重命名';

	/// zh: '删除'
	String get diaryDelete => '删除';

	/// zh: '编辑'
	String get diaryEdit => '编辑';

	/// zh: '(other) {{count} 张照片}'
	String mediaImageCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 张照片',
	);

	/// zh: '(other) {{count} 段音频}'
	String mediaAudioCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 段音频',
	);

	/// zh: '(other) {{count} 段视频}'
	String mediaVideoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 段视频',
	);

	/// zh: '时间线'
	String get diaryViewModeTimeline => '时间线';

	/// zh: '信息流'
	String get diaryViewModeFeed => '信息流';

	/// zh: '配置'
	String get assistantConfigTooltip => '配置';

	/// zh: '你好，我是 Moodiary 助手，有什么可以帮你的吗？'
	String get assistantWelcome => '你好，我是 Moodiary 助手，有什么可以帮你的吗？';

	/// zh: '说点什么...'
	String get assistantInputHint => '说点什么...';

	/// zh: '尚未配置可用的模型供应商，点击前往配置。'
	String get assistantNotConfiguredBanner => '尚未配置可用的模型供应商，点击前往配置。';

	/// zh: '请先在「模型供应商」中添加并选择一个可用的供应商。'
	String get assistantNeedProvider => '请先在「模型供应商」中添加并选择一个可用的供应商。';

	/// zh: '请先在「模型供应商」中填写 API Key。'
	String get assistantNeedApiKey => '请先在「模型供应商」中填写 API Key。';

	/// zh: 'AI 助手配置'
	String get assistantSettingTitle => 'AI 助手配置';

	/// zh: '助手基于 rig 构建。在「模型供应商」里自定义任意数量的服务商（OpenAI / Anthropic 兼容端点），自由切换激活项。API Key 仅保存在本机安全存储。'
	String get assistantSettingNote => '助手基于 rig 构建。在「模型供应商」里自定义任意数量的服务商（OpenAI / Anthropic 兼容端点），自由切换激活项。API Key 仅保存在本机安全存储。';

	/// zh: '人格'
	String get assistantSectionSoul => '人格';

	/// zh: '自定义人格（SOUL）'
	String get assistantSoulTileTitle => '自定义人格（SOUL）';

	/// zh: '使用默认人格'
	String get assistantSoulTileSubtitleDefault => '使用默认人格';

	/// zh: '已自定义'
	String get assistantSoulTileSubtitleCustom => '已自定义';

	/// zh: '自定义人格'
	String get assistantSoulPageTitle => '自定义人格';

	/// zh: '这段文字只影响助手的语气与风格，会叠加在内置的安全与工具规则之上，不能改变助手被允许做的事。留空即恢复默认人格。'
	String get assistantSoulNote => '这段文字只影响助手的语气与风格，会叠加在内置的安全与工具规则之上，不能改变助手被允许做的事。留空即恢复默认人格。';

	/// zh: '用 Markdown 描述你想要的助手人格：语气、说话方式、关注点……'
	String get assistantSoulEditorHint => '用 Markdown 描述你想要的助手人格：语气、说话方式、关注点……';

	/// zh: '保存'
	String get assistantSoulSave => '保存';

	/// zh: '已保存人格'
	String get assistantSoulSaved => '已保存人格';

	/// zh: '重置为默认'
	String get assistantSoulReset => '重置为默认';

	/// zh: '已重置为默认人格'
	String get assistantSoulResetDone => '已重置为默认人格';

	/// zh: '加载中…'
	String get assistantProviderEntryLoading => '加载中…';

	/// zh: '尚未添加供应商，点击去添加'
	String get assistantProviderEntryEmpty => '尚未添加供应商，点击去添加';

	/// zh: '已复制'
	String get assistantCopied => '已复制';

	/// zh: '复制'
	String get assistantCopyTooltip => '复制';

	/// zh: '新对话'
	String get assistantNewChat => '新对话';

	/// zh: '还没有历史会话'
	String get assistantHistoryEmpty => '还没有历史会话';

	/// zh: '删除'
	String get assistantSessionDelete => '删除';

	/// zh: '停止生成'
	String get assistantStop => '停止生成';

	/// zh: '重新回答'
	String get assistantRegenerate => '重新回答';

	/// zh: '深度思考'
	String get assistantThinkingToggle => '深度思考';

	/// zh: '思考中…'
	String get assistantThinking => '思考中…';

	/// zh: '已深度思考 {duration} 秒'
	String assistantThoughtFor({required Object duration}) => '已深度思考 ${duration} 秒';

	/// zh: '工具'
	String get assistantSectionTool => '工具';

	/// zh: '助手会根据对话内容自动调用下列工具。只读工具直接执行；涉及写入或删除的工具会先请你确认。'
	String get assistantToolSectionNote => '助手会根据对话内容自动调用下列工具。只读工具直接执行；涉及写入或删除的工具会先请你确认。';

	/// zh: '查询日记'
	String get assistantToolQueryTitle => '查询日记';

	/// zh: '按关键词、时间范围或分类查询你的本地日记，用于回答涉及过往经历、情绪记录的问题。'
	String get assistantToolQueryDes => '按关键词、时间范围或分类查询你的本地日记，用于回答涉及过往经历、情绪记录的问题。';

	/// zh: '读取日记全文'
	String get assistantToolGetTitle => '读取日记全文';

	/// zh: '按 id 读取某篇日记的完整内容。'
	String get assistantToolGetDes => '按 id 读取某篇日记的完整内容。';

	/// zh: '日记概览'
	String get assistantToolOverviewTitle => '日记概览';

	/// zh: '统计日记总数、各分类篇数与时间跨度。'
	String get assistantToolOverviewDes => '统计日记总数、各分类篇数与时间跨度。';

	/// zh: '创建日记'
	String get assistantToolCreateTitle => '创建日记';

	/// zh: '按你的请求把内容保存为一篇新的本地日记。'
	String get assistantToolCreateDes => '按你的请求把内容保存为一篇新的本地日记。';

	/// zh: '修改日记'
	String get assistantToolUpdateTitle => '修改日记';

	/// zh: '按你的要求修改某篇日记的标题、正文、心情或归类。'
	String get assistantToolUpdateDes => '按你的要求修改某篇日记的标题、正文、心情或归类。';

	/// zh: '删除日记'
	String get assistantToolDeleteTitle => '删除日记';

	/// zh: '把指定日记移入回收站（可在回收站恢复）。'
	String get assistantToolDeleteDes => '把指定日记移入回收站（可在回收站恢复）。';

	/// zh: '查看分类'
	String get assistantToolListCategoriesTitle => '查看分类';

	/// zh: '列出你的全部日记分类。'
	String get assistantToolListCategoriesDes => '列出你的全部日记分类。';

	/// zh: '创建分类'
	String get assistantToolCreateCategoryTitle => '创建分类';

	/// zh: '新建一个日记分类。'
	String get assistantToolCreateCategoryDes => '新建一个日记分类。';

	/// zh: '重命名分类'
	String get assistantToolUpdateCategoryTitle => '重命名分类';

	/// zh: '修改某个分类的名称。'
	String get assistantToolUpdateCategoryDes => '修改某个分类的名称。';

	/// zh: '删除分类'
	String get assistantToolDeleteCategoryTitle => '删除分类';

	/// zh: '删除一个分类（仅当其下没有日记时）。'
	String get assistantToolDeleteCategoryDes => '删除一个分类（仅当其下没有日记时）。';

	/// zh: '查看记忆'
	String get assistantToolListMemoriesTitle => '查看记忆';

	/// zh: '列出助手保存的关于你的长期记忆（偏好、主题、目标等）。'
	String get assistantToolListMemoriesDes => '列出助手保存的关于你的长期记忆（偏好、主题、目标等）。';

	/// zh: '记住事实'
	String get assistantToolRememberTitle => '记住事实';

	/// zh: '把关于你的一条长期事实（稳定偏好 / 反复出现的主题 / 持续目标）保存下来，供日后对话记起。'
	String get assistantToolRememberDes => '把关于你的一条长期事实（稳定偏好 / 反复出现的主题 / 持续目标）保存下来，供日后对话记起。';

	/// zh: '更新记忆'
	String get assistantToolUpdateMemoryTitle => '更新记忆';

	/// zh: '修改某条已保存记忆的内容。'
	String get assistantToolUpdateMemoryDes => '修改某条已保存记忆的内容。';

	/// zh: '删除记忆'
	String get assistantToolForgetTitle => '删除记忆';

	/// zh: '删除某条已保存的记忆。'
	String get assistantToolForgetDes => '删除某条已保存的记忆。';

	/// zh: '已折叠较早的消息以节省上下文'
	String get assistantCompactionNotice => '已折叠较早的消息以节省上下文';

	/// zh: '上下文摘要'
	String get assistantCompactionSheetTitle => '上下文摘要';

	/// zh: '为节省上下文，较早的消息已折叠成下面的摘要发送给模型。完整消息仍保留在本会话中，可随时向上翻看。'
	String get assistantCompactionSheetNote => '为节省上下文，较早的消息已折叠成下面的摘要发送给模型。完整消息仍保留在本会话中，可随时向上翻看。';

	/// zh: '恢复完整历史'
	String get assistantCompactionRestore => '恢复完整历史';

	/// zh: '更多'
	String get assistantMenuTooltip => '更多';

	/// zh: '立即压缩上下文'
	String get assistantCompactNow => '立即压缩上下文';

	/// zh: '已压缩较早的对话'
	String get assistantCompactionDone => '已压缩较早的对话';

	/// zh: '暂无可压缩的内容'
	String get assistantCompactionNothing => '暂无可压缩的内容';

	/// zh: '上下文占用'
	String get assistantContextUsageLabel => '上下文占用';

	/// zh: '危险'
	String get assistantToolDangerBadge => '危险';

	/// zh: '只读'
	String get assistantToolReadOnlyBadge => '只读';

	/// zh: '助手请求执行操作'
	String get assistantToolPermissionTitle => '助手请求执行操作';

	/// zh: '这是危险操作，会修改或删除你的数据，请谨慎确认。'
	String get assistantToolPermissionDangerNote => '这是危险操作，会修改或删除你的数据，请谨慎确认。';

	/// zh: '允许一次'
	String get assistantToolAllowOnce => '允许一次';

	/// zh: '始终允许'
	String get assistantToolAllowAlways => '始终允许';

	/// zh: '拒绝'
	String get assistantToolDeny => '拒绝';

	/// zh: '已设为始终允许'
	String get assistantToolAlwaysAllowedHint => '已设为始终允许';

	/// zh: '已允许本次执行'
	String get assistantToolStatusAllowedOnce => '已允许本次执行';

	/// zh: '已拒绝执行'
	String get assistantToolStatusDenied => '已拒绝执行';

	/// zh: '已取消'
	String get assistantToolStatusCanceled => '已取消';

	/// zh: '重置已授权的工具'
	String get assistantToolResetGrants => '重置已授权的工具';

	/// zh: '已重置工具授权'
	String get assistantToolResetGrantsDone => '已重置工具授权';

	/// zh: '使用前必读'
	String get assistantDisclaimerTitle => '使用前必读';

	/// zh: 'Moodiary 助手由第三方大语言模型驱动，使用前请知悉： • AI 生成的内容可能不准确、不完整甚至具有误导性，请勿将其作为医疗、心理、法律、财务等专业建议，或任何重要决策的依据。 • 发送消息后，你输入的内容会被发送给你所配置的模型供应商；当助手调用日记工具时，相关的本地日记摘要也会一并发送以生成回复。是否信任该供应商由你自行判断。 • 你的 API Key 仅保存在本机安全存储，不会上传到 Moodiary 的服务器。 继续使用即代表你已知悉并接受以上风险。'
	String get assistantDisclaimerContent => 'Moodiary 助手由第三方大语言模型驱动，使用前请知悉：\n\n• AI 生成的内容可能不准确、不完整甚至具有误导性，请勿将其作为医疗、心理、法律、财务等专业建议，或任何重要决策的依据。\n\n• 发送消息后，你输入的内容会被发送给你所配置的模型供应商；当助手调用日记工具时，相关的本地日记摘要也会一并发送以生成回复。是否信任该供应商由你自行判断。\n\n• 你的 API Key 仅保存在本机安全存储，不会上传到 Moodiary 的服务器。\n\n继续使用即代表你已知悉并接受以上风险。';

	/// zh: '同意并继续'
	String get assistantDisclaimerAgree => '同意并继续';

	/// zh: '暂不使用'
	String get assistantDisclaimerDecline => '暂不使用';

	/// zh: '需先同意免责声明才能使用助手'
	String get assistantDisclaimerGateTitle => '需先同意免责声明才能使用助手';

	/// zh: '查看免责声明'
	String get assistantDisclaimerGateAction => '查看免责声明';

	/// zh: '工具'
	String get assistantToolPanelTitle => '工具';

	/// zh: '发送日记'
	String get assistantToolSendDiary => '发送日记';

	/// zh: '发送图片'
	String get assistantToolSendImage => '发送图片';

	/// zh: '[图片]'
	String get assistantImageMessageLabel => '[图片]';

	/// zh: '选择日记'
	String get assistantSelectDiaryTitle => '选择日记';

	/// zh: '搜索日记'
	String get assistantSelectDiarySearchHint => '搜索日记';

	/// zh: '没有可发送的日记'
	String get assistantSelectDiaryEmpty => '没有可发送的日记';

	/// zh: '无标题'
	String get assistantDiaryUntitled => '无标题';

	/// zh: '这是我的一篇日记，请阅读后帮我分析或回应：'
	String get assistantSendDiaryLead => '这是我的一篇日记，请阅读后帮我分析或回应：';

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

	/// zh: '名称'
	String get modelProviderName => '名称';

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

	/// zh: '自定义'
	String get llmPickerCustom => '自定义';

	/// zh: '手动填写供应商配置'
	String get llmPickerCustomDes => '手动填写供应商配置';

	/// zh: '刷新'
	String get llmPickerRefresh => '刷新';

	/// zh: '已更新'
	String get llmPickerRefreshed => '已更新';

	/// zh: '加载失败'
	String get llmPickerLoadFailed => '加载失败';

	/// zh: '重试'
	String get llmPickerRetry => '重试';

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

	/// zh: '显示全部'
	String get modelProviderShowAll => '显示全部';

	/// zh: '仅工具可用'
	String get modelProviderShowToolOnly => '仅工具可用';

	/// zh: '工具'
	String get modelProviderBadgeTools => '工具';

	/// zh: '推理'
	String get modelProviderBadgeReasoning => '推理';

	/// zh: '视觉'
	String get modelProviderBadgeVision => '视觉';

	/// zh: '模型能力'
	String get modelProviderCapabilities => '模型能力';

	/// zh: '按模型实际能力开启，决定是否启用工具、深度思考、发送图片。'
	String get modelProviderCapabilitiesHint => '按模型实际能力开启，决定是否启用工具、深度思考、发送图片。';

	/// zh: '搜索模型'
	String get modelProviderSearchModelHint => '搜索模型';

	/// zh: '无匹配模型'
	String get modelProviderNoModelMatch => '无匹配模型';

	/// zh: '日记不存在或已删除'
	String get diaryLinkNotFound => '日记不存在或已删除';

	/// zh: '知识图谱'
	String get knowledgeGraph => '知识图谱';

	/// zh: '{nodes} 篇 · {edges} 条链接'
	String graphCount({required Object nodes, required Object edges}) => '${nodes} 篇 · ${edges} 条链接';

	/// zh: '全部时间'
	String get graphTimeAll => '全部时间';

	/// zh: '近 30 天'
	String get graphTimeLast30 => '近 30 天';

	/// zh: '今年'
	String get graphTimeThisYear => '今年';

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

	/// zh: '分类'
	String get graphColorByCategory => '分类';

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

	/// zh: '{count} 个分类'
	String categorySwitcherCount({required Object count}) => '${count} 个分类';

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
	String get diarySortTitle => '排序';

	/// zh: '最新在前'
	String get diarySortNewestFirst => '最新在前';

	/// zh: '最早在前'
	String get diarySortOldestFirst => '最早在前';

	/// zh: '最近修改在前'
	String get diarySortModifiedFirst => '最近修改在前';

	/// zh: '分类已被删除，已切回全部'
	String get categoryDeletedReset => '分类已被删除，已切回全部';

	/// zh: '保存到相册'
	String get imageBrowserSave => '保存到相册';

	/// zh: '已保存到相册'
	String get imageBrowserSaved => '已保存到相册';

	/// zh: '保存失败'
	String get imageBrowserSaveFailed => '保存失败';

	/// zh: '图片信息'
	String get imageBrowserInfo => '图片信息';

	/// zh: '文件名'
	String get imageBrowserInfoName => '文件名';

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

	/// zh: '重试'
	String get videoPlayerRetry => '重试';

	/// zh: '关闭'
	String get videoPlayerClose => '关闭';

	/// zh: '关闭'
	String get audioPlayerClose => '关闭';

	/// zh: '播放'
	String get audioPlayerPlay => '播放';

	/// zh: '暂停'
	String get audioPlayerPause => '暂停';

	/// zh: '播放进度'
	String get audioPlayerProgress => '播放进度';

	/// zh: '播放'
	String get videoPlayerPlay => '播放';

	/// zh: '暂停'
	String get videoPlayerPause => '暂停';

	/// zh: '重播'
	String get videoPlayerReplay => '重播';

	/// zh: '播放进度'
	String get videoPlayerProgress => '播放进度';

	/// zh: '亮度'
	String get videoPlayerBrightness => '亮度';

	/// zh: '音量'
	String get videoPlayerVolume => '音量';

	/// zh: '{speed: String}× 倍速播放中'
	String videoPlayerSpeedBoost({required String speed}) => '${speed}× 倍速播放中';

	/// zh: '(other) {{count} 篇}'
	String diaryTimelineMonthCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		other: '${count} 篇',
	);

	/// zh: '导入与导出'
	String get exportPageTitle => '导入与导出';

	/// zh: '导出'
	String get exportSectionExport => '导出';

	/// zh: '备份'
	String get exportSectionBackup => '备份';

	/// zh: 'DOCX'
	String get exportFormatDocx => 'DOCX';

	/// zh: '导出备份'
	String get exportBackupExport => '导出备份';

	/// zh: '打包全部日记与媒体'
	String get exportBackupExportSubtitle => '打包全部日记与媒体';

	/// zh: '从备份恢复'
	String get exportRestoreFromBackup => '从备份恢复';

	/// zh: '按修改时间合并'
	String get exportBackupRestoreSubtitle => '按修改时间合并';

	/// zh: '备份与本地数据按最后修改时间合并，较新的条目覆盖较旧的。'
	String get exportRestoreConfirmMessage => '备份与本地数据按最后修改时间合并，较新的条目覆盖较旧的。';

	/// zh: '恢复'
	String get exportRestoreConfirmLabel => '恢复';

	/// zh: '正在恢复…'
	String get exportRestoring => '正在恢复…';

	/// zh: '恢复完成：{summary}'
	String exportRestoreDone({required Object summary}) => '恢复完成：${summary}';

	/// zh: '恢复失败：{error}'
	String exportRestoreFailed({required Object error}) => '恢复失败：${error}';

	/// zh: '正在打包备份…'
	String get exportPackingBackup => '正在打包备份…';

	/// zh: '备份已生成'
	String get exportBackupReady => '备份已生成';

	/// zh: '导出失败：{error}'
	String exportFailed({required Object error}) => '导出失败：${error}';

	/// zh: '产物不见了，请重试'
	String get exportArtifactMissing => '产物不见了，请重试';

	/// zh: '已生成'
	String get exportGenerated => '已生成';

	/// zh: '导出为 Markdown'
	String get exportTitleMarkdown => '导出为 Markdown';

	/// zh: '导出为 DOCX'
	String get exportTitleDocx => '导出为 DOCX';

	/// zh: '导出为 PDF'
	String get exportTitlePdf => '导出为 PDF';

	/// zh: '范围'
	String get exportSectionScope => '范围';

	/// zh: '选择日记'
	String get exportSelectDiaries => '选择日记';

	/// zh: '统计中…'
	String get exportCounting => '统计中…';

	/// zh: '{count} 篇'
	String exportEntryCount({required Object count}) => '${count} 篇';

	/// zh: '合并成一个文件'
	String get exportMergeIntoOneFile => '合并成一个文件';

	/// zh: '关闭后每篇一个文件'
	String get exportMergeSubtitle => '关闭后每篇一个文件';

	/// zh: '文件名'
	String get exportFileName => '文件名';

	/// zh: '文件名模板'
	String get exportFileNameTemplate => '文件名模板';

	/// zh: '可用占位符：{date} 日期、{title} 标题、{id} 日记 id'
	String exportFileNameTemplateHint({required Object date, required Object title, required Object id}) => '可用占位符：${date} 日期、${title} 标题、${id} 日记 id';

	/// zh: '模板不能为空'
	String get exportTemplateEmpty => '模板不能为空';

	/// zh: '内容'
	String get exportSectionContent => '内容';

	/// zh: '标题'
	String get exportIncludeTitle => '标题';

	/// zh: '日期、天气与位置'
	String get exportIncludeMeta => '日期、天气与位置';

	/// zh: '媒体'
	String get exportMedia => '媒体';

	/// zh: '内嵌图片'
	String get exportMediaEmbed => '内嵌图片';

	/// zh: '只写占位文字'
	String get exportMediaPlaceholder => '只写占位文字';

	/// zh: '不含媒体'
	String get exportMediaNone => '不含媒体';

	/// zh: 'GitHub 风味'
	String get exportMarkdownGfm => 'GitHub 风味';

	/// zh: '支持表格与任务清单'
	String get exportMarkdownGfmSubtitle => '支持表格与任务清单';

	/// zh: '写入 Front Matter'
	String get exportMarkdownFrontMatter => '写入 Front Matter';

	/// zh: '在文件开头记录日期、分类等信息'
	String get exportMarkdownFrontMatterSubtitle => '在文件开头记录日期、分类等信息';

	/// zh: '排版'
	String get exportSectionLayout => '排版';

	/// zh: '字体'
	String get exportFont => '字体';

	/// zh: '中文字体'
	String get exportEastAsiaFont => '中文字体';

	/// zh: '西文字体'
	String get exportAsciiFont => '西文字体';

	/// zh: '还没有选择字体'
	String get exportNoFontSelected => '还没有选择字体';

	/// zh: '字号'
	String get exportFontSize => '字号';

	/// zh: '{size} pt'
	String exportFontSizeValue({required Object size}) => '${size} pt';

	/// zh: '行距'
	String get exportLineSpacing => '行距';

	/// zh: '{value} 倍'
	String exportLineSpacingValue({required Object value}) => '${value} 倍';

	/// zh: '首行缩进两字符'
	String get exportFirstLineIndent => '首行缩进两字符';

	/// zh: '纸张'
	String get exportPaper => '纸张';

	/// zh: '填写字体名，如「宋体」「Georgia」。'
	String get exportFontNameHint => '填写字体名，如「宋体」「Georgia」。';

	/// zh: '字体名不能为空'
	String get exportFontNameEmpty => '字体名不能为空';

	/// zh: '这个范围里没有日记'
	String get exportScopeEmpty => '这个范围里没有日记';

	/// zh: '已取消导出'
	String get exportCancelled => '已取消导出';

	/// zh: '取消'
	String get exportCancel => '取消';

	/// zh: '请先选择一个字体'
	String get exportPickFontFirst => '请先选择一个字体';

	/// zh: '导出 {count} 篇'
	String exportRunButton({required Object count}) => '导出 ${count} 篇';

	/// zh: '导出完成，但有几处没带上'
	String get exportPartialTitle => '导出完成，但有几处没带上';

	/// zh: '{count} 个媒体文件找不到，已跳过'
	String exportSkippedMedia({required Object count}) => '${count} 个媒体文件找不到，已跳过';

	/// zh: '有 {count} 种内容这个版本还导不出：{types}'
	String exportUnsupportedNodes({required Object count, required Object types}) => '有 ${count} 种内容这个版本还导不出：${types}';

	/// zh: '全部日记'
	String get exportScopeAll => '全部日记';

	/// zh: '按分类'
	String get exportScopeByCategory => '按分类';

	/// zh: '按时间'
	String get exportScopeByDate => '按时间';

	/// zh: '手动挑选'
	String get exportScopePicked => '手动挑选';

	/// zh: '{count} 篇'
	String exportScopeAllHint({required Object count}) => '${count} 篇';

	/// zh: '已选 {count} 篇'
	String exportScopePickedLabel({required Object count}) => '已选 ${count} 篇';

	/// zh: '时间区间'
	String get exportDateRange => '时间区间';

	/// zh: '点击选择'
	String get exportTapToPick => '点击选择';

	/// zh: '{from} 至 {to}'
	String exportDateRangeValue({required Object from, required Object to}) => '${from} 至 ${to}';

	/// zh: '全选'
	String get exportSelectAll => '全选';

	/// zh: '还没有选择'
	String get exportNothingSelected => '还没有选择';

	/// zh: '确定'
	String get exportConfirm => '确定';

	/// zh: '未分类'
	String get exportUncategorized => '未分类';

	/// zh: '已删除分类'
	String get exportDeletedCategory => '已删除分类';

	/// zh: '{count} 个分类'
	String exportCategoryCount({required Object count}) => '${count} 个分类';

	/// zh: '无标题'
	String get exportUntitled => '无标题';

	/// zh: 'PDF 字体'
	String get exportPdfFontPageTitle => 'PDF 字体';

	/// zh: '已导入的字体'
	String get exportImportedFonts => '已导入的字体';

	/// zh: '导入字体'
	String get exportImportFont => '导入字体';

	/// zh: '正在导入…'
	String get exportImportingFont => '正在导入…';

	/// zh: '导入失败：{error}'
	String exportImportFailed({required Object error}) => '导入失败：${error}';

	/// zh: '读不出字体名，文件可能已损坏'
	String get exportFontNameUnreadable => '读不出字体名，文件可能已损坏';

	/// zh: '还没有可用于 PDF 的字体'
	String get exportNoPdfFontTitle => '还没有可用于 PDF 的字体';

	/// zh: '导入一个 .ttf 字体后可在此选择。'
	String get exportNoPdfFontMessage => '导入一个 .ttf 字体后可在此选择。';

	/// zh: '视频'
	String get exportMediaKindVideo => '视频';

	/// zh: '音频'
	String get exportMediaKindAudio => '音频';

	/// zh: '正在转换 {done}/{total}'
	String exportProgressConverting({required Object done, required Object total}) => '正在转换 ${done}/${total}';

	/// zh: '正在排版…'
	String get exportProgressWriting => '正在排版…';

	/// zh: '正在排版 {done}/{total}'
	String exportProgressWritingCount({required Object done, required Object total}) => '正在排版 ${done}/${total}';

	/// zh: '正在生成文件…'
	String get exportProgressSerializing => '正在生成文件…';
}
