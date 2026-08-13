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
class TranslationsEn extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver);

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$en app = _Translations$app$en._(_root);
	@override late final _Translations$assistant$en assistant = _Translations$assistant$en._(_root);
	@override late final _Translations$common$en common = _Translations$common$en._(_root);
	@override late final _Translations$diary$en diary = _Translations$diary$en._(_root);
	@override late final _Translations$editor$en editor = _Translations$editor$en._(_root);
	@override late final _Translations$export$en export = _Translations$export$en._(_root);
	@override late final _Translations$media$en media = _Translations$media$en._(_root);
	@override late final _Translations$sync$en sync = _Translations$sync$en._(_root);
	@override late final _Translations$ui$en ui = _Translations$ui$en._(_root);
}

// Path: app
class _Translations$app$en extends Translations$app$zh {
	_Translations$app$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get accentTitle => 'Accent color';
	@override String get accentNeutral => 'Default';
	@override String get accentSystem => 'From wallpaper';
	@override String get accentCustomTitle => 'Custom accent';
	@override String get accentGroupAccent => 'Accent';
	@override String get accentGroupSurface => 'Surface';
	@override String get accentGroupSemantic => 'Semantic';
	@override String get accentSeed => 'Picked';
	@override String get language => 'Language';
	@override String get homeNavigatorDiary => 'Diary';
	@override String get homeNavigatorAssistant => 'Assistant';
	@override String get homePageAddDiaryButton => 'Create a diary';
	@override String get noticeEnablePhotoPermission => 'Please go to settings to enable photo library permissions';
	@override String get noticeEnableCameraPermission => 'Please go to settings to enable camera permissions';
	@override String get pickerRecentAlbum => 'Recent';
	@override String get categoryDeletedReset => 'Category deleted, showing all diaries';
	@override String get homeNavigatorSetting => 'Setting';
	@override String get languageSystem => 'Follow System';
	@override String get languageSimplifiedChinese => '简体中文';
	@override String get languageEnglish => 'English';
}

// Path: assistant
class _Translations$assistant$en extends Translations$assistant$zh {
	_Translations$assistant$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get settingFunctionAIAssistant => 'AI Assistant';
	@override String get diaryEdit => 'Edit';
	@override String get configTooltip => 'Settings';
	@override String get welcome => 'Hi, I\'m the Moodiary assistant. How can I help you?';
	@override String get inputHint => 'Say something...';
	@override String get notConfiguredBanner => 'No model provider configured yet. Tap to set up.';
	@override String get needProvider => 'Please add and select an available provider in Model Providers first.';
	@override String get needApiKey => 'Please set the API Key in Model Providers first.';
	@override String get settingTitle => 'AI Assistant Settings';
	@override String get settingNote => 'The assistant is built on rig. Add any number of providers (OpenAI / Anthropic compatible endpoints) under Model Providers and switch the active one freely. API keys are stored only in local secure storage.';
	@override String get sectionSoul => 'Persona';
	@override String get soulTileTitle => 'Custom persona (SOUL)';
	@override String get soulTileSubtitleDefault => 'Using the default persona';
	@override String get soulTileSubtitleCustom => 'Customized';
	@override String get soulPageTitle => 'Custom persona';
	@override String get soulNote => 'This text only shapes the assistant\'s tone and style. It layers on top of the built-in safety and tool rules and can\'t change what the assistant is allowed to do. Leave it empty to restore the default persona.';
	@override String get soulEditorHint => 'Describe the persona you want in Markdown: tone, voice, what it pays attention to…';
	@override String get soulSaved => 'Persona saved';
	@override String get soulReset => 'Reset to default';
	@override String get soulResetDone => 'Reset to the default persona';
	@override String get providerEntryLoading => 'Loading…';
	@override String get providerEntryEmpty => 'No provider yet, tap to add one';
	@override String get copied => 'Copied';
	@override String get copyTooltip => 'Copy';
	@override String get newChat => 'New chat';
	@override String get historyEmpty => 'No chat history yet';
	@override String get stop => 'Stop generating';
	@override String get regenerate => 'Regenerate';
	@override String get thinkingToggle => 'Thinking';
	@override String get thinking => 'Thinking…';
	@override String thoughtFor({required Object duration}) => 'Thought for ${duration}s';
	@override String get tool => 'Tools';
	@override String get toolSectionNote => 'The assistant uses the tools below automatically based on the conversation. Read-only tools run right away; tools that write or delete ask for your confirmation first.';
	@override String get toolQueryTitle => 'Query diaries';
	@override String get toolQueryDes => 'Finds your local diaries by keyword, date range, or category to answer questions about past experiences and moods.';
	@override String get toolGetTitle => 'Read full diary';
	@override String get toolGetDes => 'Reads the full content of a diary by its id.';
	@override String get toolOverviewTitle => 'Diary overview';
	@override String get toolOverviewDes => 'Counts your diaries in total and per category, and their date span.';
	@override String get toolCreateTitle => 'Create diary';
	@override String get toolCreateDes => 'Saves content as a new local diary entry when you ask.';
	@override String get toolUpdateTitle => 'Edit diary';
	@override String get toolUpdateDes => 'Edits a diary\'s title, body, mood, or category on request.';
	@override String get toolDeleteTitle => 'Delete diary';
	@override String get toolDeleteDes => 'Moves a diary to the recycle bin (recoverable).';
	@override String get toolListCategoriesTitle => 'View categories';
	@override String get toolListCategoriesDes => 'Lists all of your diary categories.';
	@override String get toolCreateCategoryTitle => 'Create category';
	@override String get toolCreateCategoryDes => 'Creates a new diary category.';
	@override String get toolUpdateCategoryTitle => 'Rename category';
	@override String get toolUpdateCategoryDes => 'Renames an existing category.';
	@override String get toolDeleteCategoryTitle => 'Delete category';
	@override String get toolDeleteCategoryDes => 'Deletes a category (only when it has no diaries).';
	@override String get toolListMemoriesTitle => 'View memories';
	@override String get toolListMemoriesDes => 'List the long-term facts the assistant has saved about you (preferences, themes, goals).';
	@override String get toolRememberTitle => 'Remember a fact';
	@override String get toolRememberDes => 'Save one long-term fact about you — a stable preference, a recurring theme, or an ongoing goal — to recall in later conversations.';
	@override String get toolUpdateMemoryTitle => 'Update a memory';
	@override String get toolUpdateMemoryDes => 'Revise the content of a saved memory.';
	@override String get toolForgetTitle => 'Forget a memory';
	@override String get toolForgetDes => 'Delete a saved memory.';
	@override String get compactionNotice => 'Earlier messages summarized to save context';
	@override String get compactionSheetTitle => 'Context summary';
	@override String get compactionSheetNote => 'To save context, earlier messages are folded into the summary below before being sent to the model. The full messages are kept in this conversation and you can still scroll back to them.';
	@override String get compactionRestore => 'Send full history again';
	@override String get compactNow => 'Compact context now';
	@override String get compactionDone => 'Earlier messages compacted';
	@override String get compactionNothing => 'Nothing to compact yet';
	@override String get contextUsageLabel => 'Context used';
	@override String get toolDangerBadge => 'Risky';
	@override String get toolReadOnlyBadge => 'Read-only';
	@override String get toolPermissionTitle => 'Tool permission requested';
	@override String get toolPermissionDangerNote => 'This is a risky action that will modify or delete your data. Please confirm carefully.';
	@override String get toolAllowOnce => 'Allow once';
	@override String get toolAllowAlways => 'Always allow';
	@override String get toolDeny => 'Deny';
	@override String get toolAlwaysAllowedHint => 'Set to always allow';
	@override String get toolStatusAllowedOnce => 'Allowed once';
	@override String get toolStatusDenied => 'Denied';
	@override String get toolStatusCanceled => 'Canceled';
	@override String get toolResetGrants => 'Reset approved tools';
	@override String get toolResetGrantsDone => 'Tool approvals reset';
	@override String get disclaimerTitle => 'Before you start';
	@override String get disclaimerContent => 'The Moodiary assistant is powered by third-party large language models. Please be aware:\n\n• AI-generated content may be inaccurate, incomplete, or even misleading. Do not rely on it as professional (medical, psychological, legal, or financial) advice, or as the basis for any important decision.\n\n• When you send a message, your input is sent to the model provider you configured. When the assistant uses the diary tools, relevant local diary excerpts are sent as well in order to generate a reply. It is up to you to decide whether to trust that provider.\n\n• Your API key is stored only in local secure storage and is never uploaded to Moodiary\'s servers.\n\nBy continuing, you acknowledge and accept the risks above.';
	@override String get disclaimerAgree => 'Agree & continue';
	@override String get disclaimerDecline => 'Not now';
	@override String get disclaimerGateTitle => 'Accept the disclaimer to use the assistant';
	@override String get disclaimerGateAction => 'View disclaimer';
	@override String get toolSendDiary => 'Send a diary';
	@override String get toolSendImage => 'Send an image';
	@override String get imageMessageLabel => '[Image]';
	@override String get sendDiaryLead => 'Here is one of my diary entries. Please read it and respond:';
	@override String get modelProviderTitle => 'Model Providers';
	@override String get modelProviderAdd => 'Add';
	@override String get modelProviderNoKey => 'No key';
	@override String get modelProviderEmptyTitle => 'No model providers yet';
	@override String get modelProviderEmptyHint => 'Tap Add at the bottom right to create one';
	@override String get modelProviderDeleteTitle => 'Delete provider';
	@override String modelProviderDeleteContent({required Object name}) => 'Delete "${name}"? Its API Key will be removed too.';
	@override String get modelProviderDeleted => 'Deleted';
	@override String get modelProviderEditNew => 'Add provider';
	@override String get modelProviderEditEdit => 'Edit provider';
	@override String get modelProviderNameHint => 'e.g. DeepSeek / local Ollama';
	@override String get modelProviderBaseUrl => 'baseUrl';
	@override String get modelProviderBaseUrlHint => 'Leave empty to use the official endpoint';
	@override String get modelProviderApiKey => 'API Key';
	@override String get modelProviderApiKeyHintSet => 'Configured, leave empty to keep unchanged';
	@override String get modelProviderApiKeyHintUnset => 'Paste API Key';
	@override String get modelProviderModel => 'Model';
	@override String get modelProviderNeedName => 'Please enter a name';
	@override String get modelProviderNeedModel => 'Please enter a model';
	@override String get modelProviderSaved => 'Saved';
	@override String get modelProviderGetApiKey => 'Get API Key';
	@override String get llmPickerTitle => 'Choose provider';
	@override String get llmPickerCustomDes => 'Configure a provider manually';
	@override String get llmPickerRefresh => 'Refresh';
	@override String get llmPickerRefreshed => 'Updated';
	@override String get llmPickerLoadFailed => 'Failed to load';
	@override String llmPickerModelCount({required Object count}) => '${count} models';
	@override String llmPickerUpdatedAt({required Object time}) => 'Updated ${time}';
	@override String get llmPickerEmpty => 'No preset providers available';
	@override String get llmPickerDataSource => 'Data from models.dev';
	@override String get llmPickerSearchHint => 'Search providers';
	@override String get modelProviderPickModel => 'Choose a model';
	@override String get modelProviderShowAll => 'Show all';
	@override String get modelProviderShowToolOnly => 'Tool-capable only';
	@override String get modelProviderBadgeReasoning => 'Reasoning';
	@override String get modelProviderBadgeVision => 'Vision';
	@override String get modelProviderCapabilities => 'Model capabilities';
	@override String get modelProviderCapabilitiesHint => 'Enable what this model supports — controls tools, thinking, and image sending.';
	@override String get modelProviderSearchModelHint => 'Search models';
	@override String get modelProviderNoModelMatch => 'No matching models';
}

// Path: common
class _Translations$common$en extends Translations$common$zh {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get ok => 'OK';
	@override String get cancel => 'Cancel';
	@override String get more => 'More';
	@override String get custom => 'Custom';
	@override String get save => 'Save';
	@override String get media => 'Media';
	@override String get audio => 'Audio';
	@override String get video => 'Video';
	@override String get category => 'Category';
	@override String get name => 'Name';
	@override String get delete => 'Delete';
	@override String get untitled => 'Untitled';
	@override String get retry => 'Retry';
	@override String categoryCount({required Object count}) => '${count} categories';
	@override String get fileName => 'File name';
	@override String get close => 'Close';
	@override String get appName => 'Moodiary';
}

// Path: diary
class _Translations$diary$en extends Translations$diary$zh {
	_Translations$diary$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get tabViewEmpty => 'Nothing here yet';
	@override String get pageViewModeButton => 'View mode';
	@override String get categoryNoCategory => 'No category';
	@override String get allCategories => 'All categories';
	@override String get categoryAll => 'All';
	@override String get categoryColorLabel => 'Color';
	@override String get search => 'Search';
	@override String searchResult({required Object count}) => 'Total ${count} diaries';
	@override String searchTime({required Object ms}) => '${ms}ms';
	@override String get rangeAll => 'All time';
	@override String get rangeLast30 => 'Last 30 days';
	@override String get rangeThisYear => 'This year';
	@override String get searchSortRelevance => 'Relevance';
	@override String get searchSortNewest => 'Newest';
	@override String get searchSortOldest => 'Oldest';
	@override String get searchNoResult => 'No matching diaries';
	@override String get searchHistory => 'Search history';
	@override String get searchHistoryClear => 'Clear';
	@override String get searchHistoryEmpty => 'No search history yet';
	@override String get viewModeTimeline => 'Timeline';
	@override String get viewModeFeed => 'Feed';
	@override String get assistantSelectDiaryTitle => 'Select a diary';
	@override String get assistantSelectDiarySearchHint => 'Search diaries';
	@override String get assistantSelectDiaryEmpty => 'No diaries to send';
	@override String get linkNotFound => 'Diary not found or deleted';
	@override String get knowledgeGraph => 'Knowledge Graph';
	@override String graphCount({required Object nodes, required Object edges}) => '${nodes} notes · ${edges} links';
	@override String get graphTimeLast365 => 'Last 12 months';
	@override String get graphOpenDiary => 'Open diary';
	@override String get graphStyle => 'Layout style';
	@override String get graphStyleSparse => 'Sparse';
	@override String get graphStyleNormal => 'Standard';
	@override String get graphStyleDense => 'Dense';
	@override String get graphView => 'View';
	@override String get graphColorBy => 'Color by';
	@override String get graphColorByTime => 'Time';
	@override String get graphColorByPlain => 'Plain';
	@override String get graphShowLabels => 'Show titles';
	@override String get graphResetCamera => 'Fit to view';
	@override String get graphEmptyTitle => 'No links yet';
	@override String get graphEmptyDesc => 'Type [[ in a diary to reference another one, and they\'ll show up here';
	@override String get graphEmptyAction => 'Write a diary';
	@override String get graphFilterEmpty => 'No links match these filters';
	@override String get graphClearFilter => 'Clear filters';
	@override String get graphLocal => 'Local graph';
	@override String get graphOutgoing => 'Outgoing';
	@override String get graphIncoming => 'Incoming';
	@override String graphOutgoingCount({required Object count}) => '${count} outgoing';
	@override String graphIncomingCount({required Object count}) => '${count} incoming';
	@override String get graphSetAsCenter => 'Center on this';
	@override String get graphBackToCenter => 'Recenter';
	@override String get graphLinks => 'Links';
	@override String get graphNoLocalLinks => 'This diary has no links yet';
	@override String get categorySearchHint => 'Search categories';
	@override String get categoryAllDiary => 'All diaries';
	@override String get categoryNoMatch => 'No matching categories';
	@override String get categorySyncingPlaceholder => 'Syncing category…';
	@override String get categoryManageEntry => 'Manage categories';
	@override String get sortTitle => 'Sort';
	@override String get sortNewestFirst => 'Newest first';
	@override String get sortOldestFirst => 'Oldest first';
	@override String get sortModifiedFirst => 'Recently edited first';
	@override String timelineMonthCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '1 entry',
		other: '${count} entries',
	);
	@override String get rangeLast7 => 'Last 7 days';
}

// Path: editor
class _Translations$editor$en extends Translations$editor$zh {
	_Translations$editor$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get noticeEnableLocation => 'Please enable location permission';
	@override String get noticeEnableLocation2 => 'Please go to settings to enable location permissions';
	@override String get pickFromGallery => 'Album';
	@override String get audioFileError => 'Audio file error';
	@override String get pickImage => 'Select image';
	@override String get pickImageFromCamera => 'Taking photos';
	@override String get pickVideo => 'Select video';
	@override String get pickVideoFromCamera => 'Video';
	@override String get pickAudio => 'Select audio';
	@override String get pickAudioFromRecord => 'Recording';
	@override String get pickAudioFromFile => 'File Audio';
	@override String get content => 'Text';
}

// Path: export
class _Translations$export$en extends Translations$export$zh {
	_Translations$export$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get pageTitle => 'Import & export';
	@override String get sectionExport => 'Export';
	@override String get sectionBackup => 'Backup';
	@override String get formatDocx => 'DOCX';
	@override String get backupExport => 'Export backup';
	@override String get backupExportSubtitle => 'Packs all entries and media';
	@override String get restoreFromBackup => 'Restore from backup';
	@override String get backupRestoreSubtitle => 'Merged by modification time';
	@override String get restoreConfirmMessage => 'The backup and your local data are merged by last modified time; newer entries win.';
	@override String get restoreConfirmLabel => 'Restore';
	@override String get restoring => 'Restoring…';
	@override String restoreDone({required Object summary}) => 'Restored: ${summary}';
	@override String restoreFailed({required Object error}) => 'Restore failed: ${error}';
	@override String get packingBackup => 'Packing backup…';
	@override String get backupReady => 'Backup created';
	@override String failed({required Object error}) => 'Export failed: ${error}';
	@override String get artifactMissing => 'The exported file is gone. Please try again.';
	@override String get generated => 'Exported';
	@override String get titleMarkdown => 'Export to Markdown';
	@override String get titleDocx => 'Export to DOCX';
	@override String get titlePdf => 'Export to PDF';
	@override String get sectionScope => 'Scope';
	@override String get selectDiaries => 'Select entries';
	@override String get counting => 'Counting…';
	@override String entryCount({required Object count}) => '${count} entries';
	@override String get mergeIntoOneFile => 'Merge into one file';
	@override String get mergeSubtitle => 'When off, one file per entry';
	@override String get fileNameTemplate => 'File name template';
	@override String fileNameTemplateHint({required Object date, required Object title, required Object id}) => 'Available placeholders: ${date} date, ${title} title, ${id} entry id';
	@override String get templateEmpty => 'Template can\'t be empty';
	@override String get sectionContent => 'Content';
	@override String get includeTitle => 'Title';
	@override String get includeMeta => 'Date, weather and location';
	@override String get mediaEmbed => 'Embed images';
	@override String get mediaPlaceholder => 'Placeholder text only';
	@override String get mediaNone => 'No media';
	@override String get markdownGfm => 'GitHub Flavored';
	@override String get markdownGfmSubtitle => 'Supports tables and task lists';
	@override String get markdownFrontMatter => 'Write front matter';
	@override String get markdownFrontMatterSubtitle => 'Records date, category and more at the top of the file';
	@override String get sectionLayout => 'Layout';
	@override String get font => 'Font';
	@override String get eastAsiaFont => 'Chinese font';
	@override String get asciiFont => 'Latin font';
	@override String get noFontSelected => 'No font selected yet';
	@override String get fontSize => 'Font size';
	@override String fontSizeValue({required Object size}) => '${size} pt';
	@override String get lineSpacing => 'Line spacing';
	@override String lineSpacingValue({required Object value}) => '${value}×';
	@override String get firstLineIndent => 'Indent first line by two characters';
	@override String get paper => 'Paper size';
	@override String get fontNameHint => 'Enter a font name, e.g. "SimSun" or "Georgia".';
	@override String get fontNameEmpty => 'Font name can\'t be empty';
	@override String get scopeEmpty => 'No entries in this scope';
	@override String get cancelled => 'Export cancelled';
	@override String get pickFontFirst => 'Pick a font first';
	@override String runButton({required Object count}) => 'Export ${count} entries';
	@override String get partialTitle => 'Exported, but a few things were left out';
	@override String skippedMedia({required Object count}) => '${count} media files were missing and were skipped';
	@override String unsupportedNodes({required Object count, required Object types}) => '${count} kinds of content can\'t be exported in this version yet: ${types}';
	@override String get scopeAll => 'All entries';
	@override String get scopeByCategory => 'By category';
	@override String get scopeByDate => 'By date';
	@override String get scopePicked => 'Pick manually';
	@override String scopePickedLabel({required Object count}) => '${count} selected';
	@override String get dateRange => 'Date range';
	@override String get tapToPick => 'Tap to choose';
	@override String dateRangeValue({required Object from, required Object to}) => '${from} – ${to}';
	@override String get selectAll => 'Select all';
	@override String get nothingSelected => 'Nothing selected';
	@override String get confirm => 'Done';
	@override String get uncategorized => 'Uncategorized';
	@override String get deletedCategory => 'Deleted category';
	@override String get pdfFontPageTitle => 'PDF font';
	@override String get importedFonts => 'Imported fonts';
	@override String get importFont => 'Import font';
	@override String get importingFont => 'Importing…';
	@override String importFailed({required Object error}) => 'Import failed: ${error}';
	@override String get fontNameUnreadable => 'Can\'t read the font name; the file may be damaged';
	@override String get noPdfFontTitle => 'No fonts available for PDF yet';
	@override String get noPdfFontMessage => 'Import a .ttf font to pick it here.';
	@override String progressConverting({required Object done, required Object total}) => 'Converting ${done}/${total}';
	@override String get progressWriting => 'Laying out…';
	@override String progressWritingCount({required Object done, required Object total}) => 'Laying out ${done}/${total}';
	@override String get progressSerializing => 'Writing file…';
}

// Path: media
class _Translations$media$en extends Translations$media$zh {
	_Translations$media$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Media';
	@override String get typeImage => 'Image';
	@override String get deleteUseLessFile => 'Delete useless file';
	@override String get empty => 'No media yet';
	@override String get cleanupScanning => 'Scanning for unused files';
	@override String get cleanupEmpty => 'No unused files found';
	@override String get cleanupConfirmTitle => 'Clean up unused files';
	@override String cleanupConfirmMessage({required Object count, required Object size}) => 'Found ${count} files not referenced by any diary (${size}). Clean them up? This cannot be undone.';
	@override String cleanupDone({required Object count}) => 'Cleaned up ${count} files';
	@override String get rename => 'Rename';
	@override String imageCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Photo',
		other: '${count} Photos',
	);
	@override String audioCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Audio',
		other: '${count} Audios',
	);
	@override String videoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(count,
		one: '${count} Video',
		other: '${count} Videos',
	);
}

// Path: sync
class _Translations$sync$en extends Translations$sync$zh {
	_Translations$sync$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get backupSyncWebdav => 'WebDAV';
	@override String get backupSyncWebdavNoOption => 'Not Configured';
	@override String get backupSyncWebdavOption => 'Configured';
	@override String get webdavOptionServer => 'Server address';
	@override String get webdavOptionUsername => 'Username';
	@override String get webdavOptionPassword => 'Password';
	@override String get backupSyncS3 => 'S3 / MinIO';
	@override String get s3OptionEndpoint => 'Endpoint';
	@override String get s3OptionRegion => 'Region';
	@override String get s3OptionBucket => 'Bucket';
	@override String get s3OptionAccessKey => 'Access Key';
	@override String get s3OptionSecretKey => 'Secret Key';
	@override String get s3OptionUseSsl => 'Use HTTPS';
	@override String get sectionConnection => 'Connection';
	@override String get sectionCredentials => 'Credentials';
	@override String get sectionOptions => 'Options';
	@override String get configClear => 'Clear settings';
	@override String get configClearConfirmTitle => 'Clear settings?';
	@override String get configClearConfirmMessage => 'Syncing with this backend stops. Diaries on this device are untouched.';
	@override String get configCleared => 'Settings cleared';
	@override String fieldRequired({required String field}) => '${field} is required';
	@override String get fieldOptional => 'Optional';
	@override String get fieldInvalidUrl => 'That address doesn\'t look right';
}

// Path: ui
class _Translations$ui$en extends Translations$ui$zh {
	_Translations$ui$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get imageBrowserSave => 'Save to gallery';
	@override String get imageBrowserSaved => 'Saved to gallery';
	@override String get imageBrowserSaveFailed => 'Save failed';
	@override String get imageBrowserInfo => 'Image info';
	@override String get imageBrowserInfoUrl => 'URL';
	@override String get imageBrowserInfoResolution => 'Resolution';
	@override String get imageBrowserInfoSize => 'Size';
	@override String get imageBrowserInfoFormat => 'Format';
	@override String get imageBrowserInfoModified => 'Modified';
	@override String get videoPlayerLoadFailed => 'Couldn\'t load this video';
	@override String get play => 'Play';
	@override String get pause => 'Pause';
	@override String get playbackProgress => 'Playback progress';
	@override String get videoPlayerReplay => 'Replay';
	@override String get videoPlayerBrightness => 'Brightness';
	@override String get videoPlayerVolume => 'Volume';
	@override String videoPlayerSpeedBoost({required Object speed}) => 'Playing at ${speed}×';
}
