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
	@override late final _Translations$lock$en lock = _Translations$lock$en._(_root);
	@override late final _Translations$media$en media = _Translations$media$en._(_root);
	@override late final _Translations$onboarding$en onboarding = _Translations$onboarding$en._(_root);
	@override late final _Translations$picker$en picker = _Translations$picker$en._(_root);
	@override late final _Translations$share$en share = _Translations$share$en._(_root);
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
	@override String get categoryDeletedReset => 'Category deleted, showing all diaries';
	@override String get homeNavigatorSetting => 'Setting';
	@override String get languageSystem => 'Follow System';
	@override String get languageSimplifiedChinese => '简体中文';
	@override String get languageEnglish => 'English';
	@override String get settingsTitle => 'Settings';
	@override String get sectionData => 'Data';
	@override String get recycle => 'Recycle bin';
	@override String get syncBackup => 'Sync and backup';
	@override String get categoryManager => 'Categories';
	@override String get mapTitle => 'Trail map';
	@override String get sectionDisplay => 'Display';
	@override String get diarySettings => 'Entry preferences';
	@override String get themeMode => 'Theme';
	@override String get fontStyle => 'Font';
	@override String get sectionPrivacy => 'Privacy';
	@override String get backgroundPrivacy => 'Hide content in the app switcher';
	@override String get backgroundPrivacySubtitle => 'Blur the screen when the app goes to the background';
	@override String get sectionMore => 'More';
	@override String get about => 'About';
	@override String get services => 'Third-party services';
	@override String get themeModeSystem => 'Follow the system';
	@override String get themeModeLight => 'Light';
	@override String get themeModeDark => 'Dark';
	@override String homeSelected({required Object count}) => '${count} selected';
	@override String get homeDeleteTitle => 'Delete the selected entries?';
	@override String homeDeleteMessage({required Object count}) => '${count} entries will be moved to the recycle bin, where you can restore them.';
	@override String get homeNothingToDelete => 'Nothing to delete';
	@override String homeMovedToRecycle({required Object count}) => 'Moved ${count} entries to the recycle bin';
	@override String get aboutCheckUpdate => 'Check for updates';
	@override String get aboutUpToDate => 'You are on the latest version';
	@override String get aboutSource => 'Source code';
	@override String get aboutFeedback => 'Feedback and help';
	@override String get aboutSponsor => 'Sponsor';
	@override String get sponsorThanks => 'Thank you for considering it!';
	@override String get sponsorBody => 'Moodiary is open source, maintained by one developer in their spare time. If you like the app, the link below is a way to support further work on it.';
	@override String get sponsorAfdian => 'Afdian';
	@override String get fontTitle => 'Fonts';
	@override String get fontImportSubtitle => 'Import a ttf / otf font; long-press to remove one';
	@override String get fontPreview => 'Preview';
	@override String get fontPreviewSubtitle => 'Text size follows your system setting — the app no longer has its own';
	@override String get fontSystem => 'System';
	@override String get fontDeleteTitle => 'Remove this font';
	@override String fontDeleteMessage({required Object name}) => 'Remove the font “${name}”?';
	@override String get fontVariable => 'Variable';
	@override String get fontAdd => 'Add';
	@override String get fontPreviewTitle => 'Pangrams';
	@override String get fontPreviewText => 'The quick brown fox jumps over the lazy dog.\nPack my box with five dozen liquor jugs.\nHow vexingly quick daft zebras jump!\nSphinx of black quartz, judge my vow.\nWaltz, bad nymph, for quick jigs vex.\nThe five boxing wizards jump quickly.';
	@override String get diaryPrefsTitle => 'Entry preferences';
	@override String get diaryPrefsEditor => 'Editor';
	@override String get firstLineIndent => 'Indent the first line';
	@override String get showWritingTime => 'Show writing time';
	@override String get showWordCount => 'Show word count';
	@override String get diaryPrefsMedia => 'Media';
	@override String get imageOptimize => 'Optimise images';
	@override String get imageOptimizeSubtitle => 'Shrink and convert to WebP; off keeps the original';
	@override String get diaryPrefsWeather => 'Weather';
	@override String get autoWeather => 'Fetch the weather when saving an entry';
	@override String get servicesIntro => 'Add your own third-party credentials here to enable the AI assistant, weather and maps. Credentials are stored on this device only.';
	@override String get servicesAssistant => 'AI assistant';
	@override String get servicesQweather => 'QWeather';
	@override String get servicesQweatherHostHint => 'devapi.qweather.com, or your own';
	@override String get servicesTianditu => 'Tianditu';
	@override String get servicesSaved => 'Saved';
	@override String get servicesSaveFailed => 'Could not save, please try again';
	@override String get semanticTitle => 'Semantic search';
	@override String get semanticModelTitle => 'Embedding model';
	@override String get semanticStateOff => 'Not enabled';
	@override String semanticDownloading({required Object percent}) => 'Downloading ${percent}%';
	@override String get semanticVerifying => 'Verifying model…';
	@override String get semanticEnableTitle => 'Enable semantic search';
	@override String get semanticEnableConfirm => 'Download & enable';
	@override String get semanticEnabled => 'Enabled — index building in background';
	@override String get semanticEnableFailed => 'Failed to enable';
	@override String get semanticDisableTitle => 'Disable semantic search';
	@override String get semanticDisableMessage => 'Disabling clears the semantic index data. Downloaded model files are kept and can be re-enabled anytime.';
	@override String get semanticDisableConfirm => 'Disable';
	@override String get semanticRebuildTitle => 'Rebuild semantic index';
	@override String get semanticRebuildSubtitle => 'Use when the index looks wrong or outdated';
	@override String semanticRebuildDone({required Object count}) => 'Re-embedded ${count} entries';
	@override String get semanticPickTitle => 'Choose embedding model';
	@override String semanticActivateDownloadMessage({required Object size}) => 'Downloads a ${size} model file and rebuilds the semantic index. All inference and indexing happen on this device; your diaries are never uploaded.';
	@override String get semanticActivateLocalMessage => 'Enabling will rebuild the semantic index.';
	@override String get semanticDeleteTitle => 'Delete model file';
	@override String get semanticDeleteMessage => 'Deletes the downloaded model file. You can download it again later.';
	@override String get semanticDeleteConfirm => 'Delete';
	@override String get semanticDescQwen3 => 'Multilingual, recalls subtle phrasing';
	@override String get moodSuggestTitle => 'Mood suggestion';
	@override String get moodSuggestModelTitle => 'Local model';
	@override String get moodSuggestPickTitle => 'Choose a model';
	@override String get moodSuggestDescQwen3 => 'Small on-device LLM, understands all 16 moods';
	@override String get moodSuggestEnableTitle => 'Enable mood suggestion';
	@override String moodSuggestActivateDownloadMessage({required Object size}) => 'Downloads a ${size} model file. While writing, a mood is suggested on-device; your diary never leaves this phone.';
	@override String get moodSuggestActivateLocalMessage => 'A mood will be suggested on-device while writing.';
	@override String get moodSuggestEnabled => 'Mood suggestion enabled';
	@override String get moodSuggestDisableTitle => 'Disable mood suggestion';
	@override String get moodSuggestDisableMessage => 'Mood will no longer be suggested while writing. Downloaded model files are kept.';
	@override String get dashUseDays => 'Days used';
	@override String get dashWordCount => 'Words';
	@override String get dashCategoryCount => 'Categories';
	@override String get dashTagCount => 'Tags';
	@override String get homeNavigatorMe => 'Me';
	@override String get meTitle => 'Me';
	@override String get meYearLabel => 'Past year';
	@override String meThisMonth({required Object count}) => '${count} this month';
	@override String meStreak({required Object count}) => '${count}-day streak';
	@override String get meHeatmapHint => 'Tap a square to see that day';
	@override String get meHeatmapEmpty => 'Write your first entry to light up a square';
	@override String get meHeatmapSemantics => 'Writing heatmap';
	@override String get meDayNothing => 'Nothing written';
	@override String get meLegendLess => 'Less';
	@override String get meLegendMore => 'More';
	@override String get meSectionRecall => 'Revisit';
	@override String get meSectionManage => 'Manage';
	@override String get meCalendar => 'Calendar';
	@override String get sectionFeature => 'Features';
	@override String get assistantEntry => 'AI assistant';
	@override String get stressTitle => 'Stress-test data (debug)';
	@override String get stressSubtitle => 'Generate or remove randomly linked entries for graph performance tests';
	@override String get stressDialogTitle => 'Stress-test data';
	@override String stressDialogMessage({required Object min, required Object max, required Object prefix}) => 'For pushing the knowledge graph and friends to their limits. Each entry links to ${min}–${max} random others and its title starts with “${prefix}”, so they can all be removed in one go.';
	@override String get stressClear => 'Remove';
	@override String get stressGenerate => 'Generate';
	@override String get stressCountTitle => 'How many';
	@override String stressCountRange({required Object min, required Object max}) => 'Pick a number between ${min} and ${max}';
	@override String get stressGenerating => 'Generating';
	@override String get stressGenerateFailed => 'Could not generate them';
	@override String stressGenerated({required Object count}) => 'Generated ${count} linked entries';
	@override String get stressEmpty => 'No stress-test entries';
	@override String get stressClearing => 'Removing';
	@override String get stressClearFailed => 'Could not remove them';
	@override String stressCleared({required Object count}) => 'Removed ${count} stress-test entries';
	@override String get repairTitle => 'Repair data';
	@override String get repairSubtitle => 'Check and repair derived entry data';
	@override String get repairMessage => 'Scans every entry to regenerate card previews and media references, clear dangling categories and rebuild the search index. Your text is never modified.';
	@override String get repairStart => 'Start';
	@override String get repairRunning => 'Repairing…';
	@override String get repairFailed => 'The repair failed';
	@override String repairScanned({required Object count}) => 'Scanned ${count} entries.';
	@override String get repairAllGood => 'Everything checks out — nothing to repair.';
	@override String repairFixed({required Object count}) => 'Repaired ${count} entries:';
	@override String repairFixedPreview({required Object count}) => '· card preview: ${count}';
	@override String repairFixedMedia({required Object count}) => '· media references: ${count}';
	@override String repairFixedOrphan({required Object count}) => '· dangling categories: ${count}';
	@override String repairReindexed({required Object count}) => 'Search index rebuilt (${count} entries).';
	@override String get repairDoneTitle => 'Repair finished';
	@override String get repairOk => 'Got it';
	@override String get cacheClear => 'Clear the cache';
	@override String get cacheCleared => 'Cache cleared';
	@override String get fontNameFailed => 'Could not read the font name';
	@override String get fontExists => 'That font is already installed';
	@override String get routeErrorTitle => 'Page not found';
	@override String get routeErrorBackHome => 'Back to home';
}

// Path: assistant
class _Translations$assistant$en extends Translations$assistant$zh {
	_Translations$assistant$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get settingFunctionAIAssistant => 'AI Assistant';
	@override String get diaryEdit => 'Edit';
	@override String get inputHint => 'Say something...';
	@override String get scrollToBottom => 'Scroll to bottom';
	@override String get send => 'Send';
	@override String get notConfiguredBanner => 'No model provider configured yet. Tap to set up.';
	@override String get needProvider => 'Please add and select an available provider in Model Providers first.';
	@override String get needApiKey => 'Please set the API Key in Model Providers first.';
	@override String get settingTitle => 'AI Assistant Settings';
	@override String get settingNote => 'The assistant is built on rig. Add any number of providers (OpenAI / Anthropic compatible endpoints) under Model Providers and switch the active one freely. API keys are stored only in local secure storage.';
	@override String get presetSectionTitle => 'Assistant presets';
	@override String get presetTileTitle => 'Assistant presets';
	@override String get presetPageTitle => 'Assistant presets';
	@override String get presetBuiltinName => 'Moodiary Assistant';
	@override String get presetBuiltinDes => 'The factory preset: a warm, grounded diary companion. Read-only — derive a copy to make it yours.';
	@override String get presetBuiltinBadge => 'Built-in';
	@override String get presetDefaultBadge => 'Default';
	@override String get presetSetDefault => 'Set as default';
	@override String get presetDerive => 'Derive a copy';
	@override String presetCopyName({required Object name}) => '${name} copy';
	@override String get presetEditTitle => 'Edit preset';
	@override String get presetNameLabel => 'Name';
	@override String get presetDescriptionLabel => 'Description';
	@override String get presetPersonaLabel => 'Persona';
	@override String get presetSaved => 'Preset saved';
	@override String get presetDeleteTitle => 'Delete preset';
	@override String presetDeleteMessage({required Object name}) => 'Delete "${name}"? Sessions created with it keep their persona (it was frozen into each session).';
	@override String get presetDeleted => 'Deleted preset';
	@override String get presetPickerTitle => 'Choose a preset';
	@override String get presetInfoSubtitle => 'This session\'s setup was frozen at creation';
	@override String get presetCustomTools => 'Custom tool set';
	@override String presetToolCount({required Object count}) => '${count} tools';
	@override String get presetToolsAll => 'All tools';
	@override String get presetToolsNone => 'No tools';
	@override String modelSwitched({required Object model}) => 'Switched to ${model}';
	@override String get providerEntryLoading => 'Loading…';
	@override String get providerEntryEmpty => 'No provider yet, tap to add one';
	@override String get copied => 'Copied';
	@override String get copyTooltip => 'Copy';
	@override String get newChat => 'New chat';
	@override String get historyEmpty => 'No chat history yet';
	@override String get historyToday => 'Today';
	@override String get historyLast7 => 'Last 7 days';
	@override String get historyEarlier => 'Earlier';
	@override String get historyModelUnset => 'Not set';
	@override String get stop => 'Stop generating';
	@override String get regenerate => 'Regenerate';
	@override String get thinking => 'Thinking…';
	@override String get protocolTitle => 'Protocol';
	@override String get protocolOpenAiCompletions => 'OpenAI /chat/completions';
	@override String get protocolOpenAiResponses => 'OpenAI /responses';
	@override String get protocolAnthropicMessages => 'Anthropic /messages';
	@override String get modelListFetch => 'Fetch models from endpoint';
	@override String get modelListNeedKey => 'Enter an API key first';
	@override String modelListFetched({required Object count}) => 'Found ${count} models';
	@override String get modelListFailed => 'Could not fetch models — enter one manually';
	@override String get reasoningEffort => 'Thinking effort';
	@override String get reasoningOff => 'No thinking';
	@override String thoughtFor({required Object duration}) => 'Thought for ${duration}s';
	@override String get tool => 'Tools';
	@override String get toolSectionNote => 'The assistant calls these tools on its own as the conversation needs them — you are not asked each time. Note what deletion does: a diary goes to the recycle bin, a saved fact is gone for good.';
	@override String get toolQueryTitle => 'Query diaries';
	@override String get toolQueryDes => 'Finds your local diaries by keyword, date range, or category to answer questions about past experiences and moods.';
	@override String get toolSemanticTitle => 'Semantic search';
	@override String get toolSemanticDes => 'Finds diaries by meaning rather than exact keywords: describe the entry in a sentence and it recalls it even with different wording. Requires the local semantic index enabled in settings.';
	@override String get toolGetTitle => 'Read full diary';
	@override String get toolGetDes => 'Read the full text of diaries by id, several at a time.';
	@override String get toolOverviewTitle => 'Diary overview';
	@override String get toolOverviewDes => 'Counts your diaries in total and per category, and their date span.';
	@override String get toolCreateTitle => 'Create diary';
	@override String get toolCreateDes => 'Saves content as a new local diary entry when you ask.';
	@override String get toolUpdateTitle => 'Edit diary';
	@override String get toolUpdateDes => 'Change the title, body, mood or category of diaries, several at a time.';
	@override String get toolDeleteTitle => 'Delete diary';
	@override String get toolDeleteDes => 'Move diaries to the recycle bin, where you can restore them.';
	@override String get toolListCategoriesTitle => 'View categories';
	@override String get toolListCategoriesDes => 'Lists all of your diary categories.';
	@override String get toolCreateCategoryTitle => 'Create category';
	@override String get toolCreateCategoryDes => 'Add diary categories.';
	@override String get toolUpdateCategoryTitle => 'Rename category';
	@override String get toolUpdateCategoryDes => 'Rename categories.';
	@override String get toolDeleteCategoryTitle => 'Delete category';
	@override String get toolDeleteCategoryDes => 'Delete categories, only while they hold no diaries.';
	@override String get toolListMemoriesTitle => 'View memories';
	@override String get toolListMemoriesDes => 'List the long-term facts the assistant has saved about you (preferences, themes, goals).';
	@override String get toolRememberTitle => 'Remember a fact';
	@override String get toolRememberDes => 'Save durable facts about you — lasting preferences, recurring themes, ongoing goals — so they can be recalled in later chats.';
	@override String get toolUpdateMemoryTitle => 'Update a memory';
	@override String get toolUpdateMemoryDes => 'Revise saved memories.';
	@override String get toolForgetTitle => 'Forget a memory';
	@override String get toolForgetDes => 'Delete saved memories.';
	@override String get toolJsTitle => 'Run script';
	@override String get toolJsDes => 'Run a short piece of JavaScript in isolation to compute something. No network, no access to your diaries.';
	@override String get toolJsEmpty => 'No value returned';
	@override String get compactionNotice => 'Earlier messages summarized to save context';
	@override String get compactionSheetTitle => 'Context summary';
	@override String get compactionSheetNote => 'To save context, earlier messages are folded into the summary below before being sent to the model. The full messages are kept in this conversation and you can still scroll back to them.';
	@override String get compactionRestore => 'Send full history again';
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
	@override String get modelProviderBadgeReasoning => 'Reasoning';
	@override String get modelProviderBadgeVision => 'Vision';
	@override String get modelProviderCapabilities => 'Model capabilities';
	@override String get modelProviderCapabilitiesHint => 'Enable what this model supports — controls tools, thinking, and image sending.';
	@override String get modelProviderSearchModelHint => 'Search models';
	@override String get modelProviderNoModelMatch => 'No matching models';
	@override String get summaryLoading => 'Loading…';
	@override String get summaryNoProvider => 'No model provider configured';
	@override String get summaryKeySet => 'Key set';
	@override String get summaryKeyUnset => 'No key';
	@override String get summaryTitle => 'AI assistant setup';
	@override String streamError({required Object error}) => '\n(error: ${error})';
	@override String requestFailed({required Object error}) => '(request failed: ${error})';
	@override String get imagePlaceholder => '[image]';
	@override String get modelProviderDefault => 'Default';
	@override String get modelProviderDefaultModel => 'Default model';
	@override String modelListCount({required Object count}) => '${count} models';
	@override String get modelListUpdate => 'Update list';
	@override String get modelListAdd => 'Add manually';
	@override String get modelListEmpty => 'No models available yet';
	@override String get modelDeprecated => 'Retired';
	@override String get composerFullscreen => 'Full-screen editor';
	@override String get toolDone => 'Done';
	@override String get toolFailed => 'Failed';
	@override String get toolNoMatch => 'No matches';
	@override String toolMatched({required Object count}) => '${count} entries';
	@override String toolRead({required Object count}) => '${count} in full';
	@override String toolListed({required Object count}) => '${count} items';
	@override String get toolUntitled => 'Untitled';
	@override String get toolUpdated => 'Updated';
	@override String get toolTrashed => 'Moved to recycle bin';
	@override String toolTrashedCount({required Object count}) => '${count} moved to recycle bin';
	@override String toolBatchDiaries({required Object count}) => '${count} entries';
	@override String toolBatchItems({required Object count}) => '${count} items';
	@override String get toolDeleted => 'Deleted';
}

// Path: common
class _Translations$common$en extends Translations$common$zh {
	_Translations$common$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get ok => 'OK';
	@override String get moodNegative => 'Low';
	@override String get moodNeutral => 'Calm';
	@override String get moodPositive => 'Happy';
	@override String get moodFulfilled => 'Fulfilled';
	@override String get moodAngry => 'Angry';
	@override String get moodAnxious => 'Anxious';
	@override String get moodTired => 'Tired';
	@override String get moodSpeechless => 'Speechless';
	@override String get moodLove => 'In love';
	@override String get moodStudy => 'Studying';
	@override String get moodSlacking => 'Slacking';
	@override String get moodFood => 'Yummy';
	@override String get moodWork => 'Working';
	@override String get moodTravel => 'Traveling';
	@override String get moodSports => 'Workout';
	@override String get moodSick => 'Sick';
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
	@override String get loadFailed => 'Something went wrong';
	@override String get untitled => 'Untitled';
	@override String get retry => 'Retry';
	@override String categoryCount({required Object count}) => '${count} categories';
	@override String get fileName => 'File name';
	@override String get close => 'Close';
	@override String get appName => 'Moodiary';
	@override String get configured => 'Configured';
	@override String get notConfigured => 'Not configured';
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
	@override String get categoryManagerTitle => 'Categories';
	@override String categoryCreated({required Object name}) => 'Created “${name}”';
	@override String get categoryCreateFailed => 'Could not create it';
	@override String categoryRenamed({required Object name}) => 'Renamed to “${name}”';
	@override String get categoryRenameFailed => 'Could not rename it';
	@override String get categoryDeleteTitle => 'Delete this category?';
	@override String categoryDeleteMessage({required Object name}) => '“${name}” cannot be deleted while entries are still filed under it. The entries themselves are not affected.';
	@override String get categoryDeleted => 'Deleted';
	@override String get categoryDeleteBlocked => 'The category still has entries and was not deleted';
	@override String get categoryEmpty => 'No categories yet';
	@override String get categoryNew => 'New category';
	@override String categoryDiaryCount({required Object count}) => '${count} entries';
	@override String get categoryNoDiary => 'No entries';
	@override String get rename => 'Rename';
	@override String get categoryNameHint => 'Category name';
	@override String get categoryNameEmpty => 'The name cannot be empty';
	@override String get recycleTitle => 'Recycle bin';
	@override String get recycleClear => 'Empty the bin';
	@override String get recycleRestored => 'Restored';
	@override String get recycleRestoreFailed => 'Could not restore it';
	@override String get recyclePurgeTitle => 'Delete for good?';
	@override String get recyclePurgeMessage => 'This cannot be undone — the entry is gone for good.';
	@override String get recyclePurgeConfirm => 'Delete for good';
	@override String get recyclePurged => 'Deleted for good';
	@override String get recyclePurgeFailed => 'Could not delete it';
	@override String get recycleClearTitle => 'Empty the recycle bin?';
	@override String recycleClearMessage({required Object count}) => '${count} entries will be deleted for good. This cannot be undone.';
	@override String get recycleClearConfirm => 'Empty';
	@override String recycleCleared({required Object count}) => 'Deleted ${count} entries';
	@override String get recycleEmpty => 'The recycle bin is empty';
	@override String get recycleRestore => 'Restore';
	@override String get managerTitle => 'Manage entries';
	@override String managerSelected({required Object count}) => '${count} selected';
	@override String get managerBatchRecycle => 'Move to the recycle bin';
	@override String get managerEmpty => 'No entries match this filter';
	@override String get managerRecycleTitle => 'Move to the recycle bin?';
	@override String managerRecycleMessage({required Object count}) => '${count} entries will be moved to the recycle bin, where you can restore them.';
	@override String get managerRecycleConfirm => 'Move';
	@override String managerRecycled({required Object done, required Object total}) => 'Moved ${done} / ${total} to the recycle bin';
	@override String get managerAll => 'All';
	@override String get mapTitle => 'Trail';
	@override String get addTag => 'Add a tag';
	@override String get tagNameHint => 'Tag name';
	@override String get add => 'Add';
	@override String get weatherFailed => 'Could not fetch the weather — check the QWeather settings under Lab';
	@override String weatherFetched({required Object weather, required Object temperature}) => 'Weather: ${weather} ${temperature}°C';
	@override String get positionFailed => 'Could not fetch the location — check location permission';
	@override String get home => 'Home';
	@override String get goBack => 'Back';
	@override String get goForward => 'Forward';
	@override String get edit => 'Edit';
	@override String get share => 'Share';
	@override String get outline => 'Outline';
	@override String wordCount({required Object count}) => '${count} characters';
	@override String get saving => 'Saving';
	@override String get saved => 'Saved';
	@override String get unsaved => 'Unsaved';
	@override String get saveFailed => 'Could not save';
	@override String get unknownCategory => 'Unknown category';
	@override String get loading => 'Loading…';
	@override String get searchReindexHint => 'Rebuild the index after upgrading so older entries become searchable';
	@override String get searchReindex => 'Rebuild';
	@override String get autoSaved => 'Autosaved';
	@override String get calendarTitle => 'Calendar';
	@override String get calendarBackToToday => 'Today';
	@override String get calendarEmptyDay => 'Nothing written that day';
}

// Path: editor
class _Translations$editor$en extends Translations$editor$zh {
	_Translations$editor$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get noticeEnableLocation => 'Please enable location permission';
	@override String get noticeEnableLocation2 => 'Please go to settings to enable location permissions';
	@override String get audioFileError => 'Audio file error';
	@override String get pickAudio => 'Select audio';
	@override String get pickAudioFromRecord => 'Recording';
	@override String get pickAudioFromFile => 'File Audio';
	@override String get content => 'Text';
	@override String get unsupportedPlatform => 'The editor is not supported on this platform';
	@override String loadFailed({required Object error}) => 'Failed to load the editor\n${error}';
	@override String get pickCategory => 'Pick a category';
	@override String get noCategory => 'No category';
	@override String get migrationTitle => 'Upgrade data migration';
	@override String get migrationIntro => 'Version 2.8.0 uses a new data engine and editor. A one-time migration is required before you can continue.';
	@override String get migrationStepEngine => 'Database engine upgrade';
	@override String get migrationStepEngineDesc => 'Moves diaries, categories, fonts and all other data into the new database';
	@override String get migrationStepEditor => 'Diary format conversion';
	@override String get migrationStepEditorDesc => 'Converts old-format content to the new editor format; originals are backed up first';
	@override String get migrationStart => 'Start migration';
	@override String get migrationExit => 'Exit app';
	@override String get migrationLandingNote => 'Do not exit the app during migration. No old data is deleted until migration succeeds.';
	@override String get migrationRunningTitle => 'Migrating data';
	@override String get migrationRunningSubtitle => 'Keep the app in the foreground and do not close it';
	@override String get migrationStageDone => 'Done';
	@override String get migrationStagePending => 'Not started';
	@override String get migrationStageFailed => 'Failed';
	@override String migrationStageFailedCount({required Object count}) => '${count} failed';
	@override String get migrationDataSafeNote => 'No old data is deleted until migration succeeds';
	@override String get migrationFailedTitle => 'Some entries failed to migrate';
	@override String migrationFailedSubtitle({required Object count}) => '${count} entries failed to migrate; the rest are done. Originals are backed up — retrying loses nothing.';
	@override String get migrationErrorTitle => 'Migration hit an error';
	@override String get migrationErrorSubtitle => 'An error occurred during migration. Originals are backed up — retrying loses nothing.';
	@override String get migrationRetry => 'Retry';
	@override String get migrationShareLog => 'Share failure log';
	@override String get migrationFailedNote => 'The log contains only error details, never diary content. No old data is deleted until migration succeeds.';
	@override String get migrationDoneTitle => 'Migration complete';
	@override String get migrationDoneSubtitle => 'All data has been moved to the new engine; old data is kept as a backup';
	@override String get migrationSummaryDiaries => 'Diaries';
	@override String migrationSummaryDiariesCount({required Object count}) => '${count}';
	@override String get migrationSummaryCategories => 'Categories';
	@override String migrationSummaryCategoriesCount({required Object count}) => '${count}';
	@override String get migrationSummaryMedia => 'Media & fonts';
	@override String get migrationSummaryMigrated => 'Migrated';
	@override String get migrationEnter => 'Get started';
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
	@override String restoreSummary({required Object diary, required Object category, required Object media}) => '${diary} diaries / ${category} categories / ${media} media entries';
	@override String restoreSummaryFailed({required Object base, required Object failed}) => '${base}, ${failed} failed';
	@override String restorePartial({required Object summary}) => 'Restore did not fully succeed: ${summary}. Check storage space and connection, then retry — don\'t delete the old device\'s data yet';
	@override String restoreStopped({required Object summary}) => 'Restore stopped (incomplete): ${summary}';
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
	@override String get mediaVideo => 'Video';
	@override String get mediaAudio => 'Audio';
}

// Path: lock
class _Translations$lock$en extends Translations$lock$zh {
	_Translations$lock$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'App lock';
	@override String get enabled => 'On';
	@override String get disabled => 'Off';
	@override String get turnOnMessage => 'The app will ask for your password every time it starts.';
	@override String get turnOffMessage => 'Starting the app will no longer ask for a password.';
	@override String get turnOnAction => 'Set up';
	@override String get turnOffAction => 'Turn off';
	@override String get changePassword => 'Change password';
	@override String get lockNow => 'Lock now';
	@override String get lockNowSubtitle => 'Require unlocking again after leaving the app';
	@override String get biometric => 'Biometric unlock';
	@override String get biometricSubtitle => 'Unlock with a fingerprint or your face';
	@override String get turnedOn => 'App lock is on';
	@override String get turnedOff => 'App lock is off';
	@override String get passwordChanged => 'Password changed';
	@override String get setPassword => 'Set a password';
	@override String get confirmPassword => 'Confirm the password';
	@override String get mismatch => 'The two entries do not match, please start over';
	@override String get saveFailed => 'Could not save the password, please try again';
	@override String get wrongPassword => 'Wrong password';
	@override String get enterToTurnOff => 'Enter your password to turn it off';
	@override String get verifyCurrent => 'Enter your current password';
	@override String get enterNew => 'Set a new password';
	@override String get confirmNew => 'Confirm the new password';
	@override String get prompt => 'Enter your password';
	@override String attemptsLeft({required Object count}) => 'Wrong password, ${count} attempts left';
	@override String cooldown({required Object seconds}) => 'Too many attempts, wait ${seconds}s';
	@override String get biometricReason => 'Verify it is you';
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

// Path: onboarding
class _Translations$onboarding$en extends Translations$onboarding$zh {
	_Translations$onboarding$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Welcome to Moodiary';
	@override String get welcomeBody => 'An offline-first private journal. Your entries stay on your device by default.';
	@override String get moodTitle => 'Capture every mood';
	@override String get moodBody => 'Organise with moods, categories and tags; writing time and word count update as you type.';
	@override String get ownershipTitle => 'Your data stays yours';
	@override String get ownershipBody => 'Export a JSON backup in one tap, or turn on WebDAV / S3 sync with optional end-to-end encryption.';
	@override String get skip => 'Skip';
	@override String get next => 'Next';
	@override String get start => 'Start writing';
	@override String get userAgreement => 'Terms of use';
	@override String get privacyPolicy => 'Privacy policy';
}

// Path: picker
class _Translations$picker$en extends Translations$picker$zh {
	_Translations$picker$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get recentAlbum => 'Recent';
	@override String get done => 'Done';
	@override String doneCount({required Object count, required Object max}) => 'Done ${count}/${max}';
	@override String get limitedTip => 'The app can only access selected photos';
	@override String get limitedManage => 'Manage';
	@override String get permissionDenied => 'Grant photo library access in Settings';
	@override String get a11ySelect => 'Select';
	@override String get a11yUnselect => 'Deselect';
	@override String get capture => 'Camera';
	@override String get record => 'Record';
	@override String get captureFailed => 'Capture failed';
}

// Path: share
class _Translations$share$en extends Translations$share$zh {
	_Translations$share$en._(TranslationsEn root) : this._root = root, super.internal(root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Share';
	@override String get empty => 'Nothing to share';
	@override String get copyText => 'Copy text';
	@override String get exportImage => 'Export image';
	@override String get copied => 'Copied to clipboard';
	@override String get subject => 'Shared from Moodiary';
	@override String imageSaved({required Object path}) => 'Image saved to ${path} (path copied)';
	@override String get templateMinimal => 'Minimal';
	@override String get templateNote => 'Note';
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
	@override String get pageTitle => 'Backup and sync';
	@override String get cloudSection => 'Cloud sync';
	@override String get method => 'Backend';
	@override String methodConfig({required Object name}) => '${name} settings';
	@override String get notConfiguredTap => 'Not configured — tap to set up';
	@override String get testConnection => 'Test the connection';
	@override String get testing => 'Testing the connection…';
	@override String get connectOk => 'Connected';
	@override String connectFailed({required Object error}) => 'Could not connect: ${error}';
	@override String get configureFirst => 'Finish the configuration first';
	@override String doneToast({required Object message}) => 'Done: ${message}';
	@override String failedToast({required Object message}) => 'Failed: ${message}';
	@override String get stopping => 'Stopping…';
	@override String get stop => 'Stop syncing';
	@override String get stoppingSubtitle => 'Finishing the current item first';
	@override String get stopSubtitle => 'Syncing in the background — tap to stop';
	@override String get willStop => 'Will stop once the current item finishes';
	@override String get syncNow => 'Sync now';
	@override String lastSync({required Object time}) => 'Last synced: ${time}';
	@override String get neverSynced => 'Never synced';
	@override String get logEntry => 'Sync log';
	@override String get logEntrySubtitle => 'Browse sync events by date';
	@override String get lanSection => 'Local network';
	@override String get lanSend => 'Send';
	@override String get lanSendSubtitle => 'Send entries to a device on the same Wi-Fi';
	@override String get lanReceive => 'Receive';
	@override String get lanReceiveSubtitle => 'Wait for another device to send to this one';
	@override String get encryptionSection => 'Encryption';
	@override String get autoSection => 'Automatic sync';
	@override String get autoSync => 'Sync automatically';
	@override String get autoSyncSubtitle => 'Push after an entry changes, and pull other devices\' changes on a timer';
	@override String get pollInterval => 'Polling interval';
	@override String get pollIntervalSubtitle => 'How often to pull other devices\' changes in the background';
	@override String get pollIntervalNote => 'How often a full two-way sync runs in the background. A shorter interval picks up other devices\' changes sooner, but every poll takes the remote lock, reads the manifest and makes network requests — too short and you pay for it in traffic and battery, and may hit WebDAV / S3 rate limits or a temporary ban. 30 seconds is a sensible floor.';
	@override String get networkSection => 'Network';
	@override String get concurrency => 'Concurrent requests';
	@override String get concurrencySubtitle => 'Upper bound on parallel network requests while syncing; lower it on a weak connection or against a rate-limited server';
	@override String get concurrencyNote => '8 by default. Higher is faster, but may trip WebDAV / S3 rate limits or get connections refused.';
	@override String seconds({required Object count}) => '${count}s';
	@override String minutes({required Object count}) => '${count} min';
	@override String minutesSeconds({required Object minutes, required Object seconds}) => '${minutes} min ${seconds}s';
	@override String get logTitle => 'Sync log';
	@override String get logPickDate => 'Pick a date';
	@override String get logFilterByDate => 'Filter by date';
	@override String get logToday => 'Today';
	@override String get logTodaySuffix => ' (today)';
	@override String get logClear => 'Clear the log';
	@override String get logClearMessage => 'This deletes the in-memory event stream and every daily jsonl file. It cannot be undone.';
	@override String logEventCount({required Object count}) => '${count} events';
	@override String get logEmpty => 'No sync events on this date';
	@override String logGroupCount({required Object kind, required Object count}) => '${kind} · ${count}';
	@override String get logDetail => 'Event details';
	@override String get logCopy => 'Copy';
	@override String get kindSyncStart => 'Sync started';
	@override String get kindSyncEnd => 'Sync finished';
	@override String get kindManifestRead => 'Manifest read';
	@override String get kindManifestWrite => 'Manifest written';
	@override String get kindDiaryUpload => 'Entry uploaded';
	@override String get kindDiaryDownload => 'Entry downloaded';
	@override String get kindDiarySkip => 'Entry skipped';
	@override String get kindDiaryTombstonePush => 'Entry deletion pushed';
	@override String get kindDiaryTombstonePull => 'Entry deletion pulled';
	@override String get kindCategoryUpload => 'Category uploaded';
	@override String get kindCategoryDownload => 'Category downloaded';
	@override String get kindCategorySkip => 'Category skipped';
	@override String get kindCategoryTombstonePush => 'Category deletion pushed';
	@override String get kindCategoryTombstonePull => 'Category deletion pulled';
	@override String get kindMediaUpload => 'Media uploaded';
	@override String get kindMediaDownload => 'Media downloaded';
	@override String get kindMediaSkip => 'Media skipped';
	@override String get kindMediaDelete => 'Media deleted';
	@override String get kindLockAcquire => 'Lock acquired';
	@override String get kindLockRelease => 'Lock released';
	@override String get kindError => 'Error';
	@override String get statusTitle => 'Sync status';
	@override String statusSubtitle({required Object backend, required Object encryption}) => '${backend} · ${encryption}';
	@override String get encrypted => 'encrypted';
	@override String get notEncrypted => 'not encrypted';
	@override String get viewLog => 'Open the log';
	@override String get overview => 'Overview';
	@override String get overviewRefresh => 'Refresh the overview';
	@override String pendingPull({required Object count}) => '${count} entries waiting to be pulled';
	@override String get statusDone => 'Sync finished';
	@override String get statusFailed => 'Sync failed';
	@override String get statusNoBackend => 'No sync backend configured';
	@override String get statusNoBackendDetail => 'Set one up under Backup and sync';
	@override String get statusSynced => 'Synced';
	@override String get statusLastSync => 'Last synced ';
	@override String get statusNever => 'Never synced';
	@override String get columnLocal => 'Local';
	@override String get columnRemote => 'Remote';
	@override String get rowDiary => 'Entries';
	@override String get rowCategory => 'Categories';
	@override String get rowMedia => 'Media';
	@override String get statusRunning => 'Syncing';
	@override String get lanSendTitle => 'Send over the local network';
	@override String get lanSendIntro => 'Only what the other device is missing gets sent. Changes merge by last-modified time, so sending twice never duplicates anything.';
	@override String get lanNearbyDevices => 'Nearby devices';
	@override String get lanReceiverAddress => 'Receiver address';
	@override String get lanAddressHint => 'Filled in when you pick a device above';
	@override String get lanPin => 'Pairing code';
	@override String get lanPinHint => 'The 6 digits shown on the receiving device';
	@override String get lanSendAction => 'Send';
	@override String get lanPickDevice => 'Pick a device to send to first';
	@override String get lanNeedPin => 'Enter the 6-digit pairing code';
	@override String get lanBadAddress => 'That address is not valid';
	@override String get lanSearching => 'Searching — open the Receive page on the other device';
	@override String get lanConnecting => 'Connecting…';
	@override String get lanPacking => 'Preparing the data…';
	@override String get lanUploading => 'Sending';
	@override String get lanApplying => 'Waiting for the other device to save…';
	@override String get lanReceiveTitle => 'Receive over the local network';
	@override String lanStartFailed({required Object error}) => 'Could not start receiving: ${error}';
	@override String get lanPinCopied => 'Pairing code copied';
	@override String get lanPinHelp => 'Enter it on the sending device · tap to copy';
	@override String get lanAddressCopied => 'Address copied';
	@override String get lanUpToDate => 'Already up to date — nothing changed';
	@override String lanReceived({required Object diary, required Object category}) => '${diary} entries · ${category} categories';
	@override String lanReceivedFailed({required Object base, required Object failed}) => '${base} (${failed} failed)';
	@override String get lanWaiting => 'Waiting for the sender to connect…';
	@override String get lanReceiving => 'Receiving';
	@override String get lanSaving => 'Saving…';
	@override String get lanDone => 'Received';
	@override String get lanDoneHint => 'You can keep receiving — the pairing code stays the same';
	@override String get lanFailed => 'Receiving failed';
	@override String get lanFailedHint => 'The pairing code is unchanged, so the sender can just retry';
	@override String get lanLocalAddress => 'This device';
	@override String get lanNoWifi => 'Not on Wi-Fi — this device has no address to show';
	@override String get keyGuardMissing => 'The remote data is encrypted but its key file (keys.json) is missing, so it cannot be decrypted. Clear the remote data and upload again.';
	@override String get keyGuardTitle => 'The remote backup is encrypted';
	@override String get keyGuardMessageMismatch => 'This device\'s key cannot decrypt the remote data. Enter the same encryption password as the original device; syncing starts once it checks out.';
	@override String get keyGuardMessage => 'The remote data is encrypted. Enter the same encryption password as the original device; syncing starts once it checks out.';
	@override String get keyGuardHint => 'Encryption password';
	@override String get keyGuardConfirm => 'Verify and save';
	@override String get keyNeedPassword => 'Enter a password';
	@override String get keyGuardWrong => 'Wrong password — the remote data cannot be decrypted';
	@override String get keyConfigured => 'Key saved';
	@override String get e2eTitle => 'End-to-end encryption';
	@override String get e2eOn => 'On';
	@override String get e2eOff => 'Off';
	@override String get e2eManage => 'Manage encryption';
	@override String get keyWrong => 'Wrong password';
	@override String get keyVerified => 'Verified';
	@override String get keyVerifyFirst => 'Verify the current password first';
	@override String get keyMismatch => 'The two passwords do not match';
	@override String get keyManageTitle => 'Encryption';
	@override String get keyCurrent => 'Current password';
	@override String get keyVerify => 'Verify';
	@override String get keyNew => 'New password';
	@override String get keyPassword => 'Encryption password';
	@override String get keyConfirm => 'Confirm the password';
	@override String get keyTurnOff => 'Turn encryption off';
	@override String get keyChanged => 'Password changed — the data key is unchanged, so nothing needs re-encrypting';
	@override String get keyEncryptCloudTitle => 'Encrypt the data already in the cloud';
	@override String get keyEncryptCloudMessage => 'This backend already holds data. Confirming generates a random data key and encrypts the remote entries, categories and media files. The key itself is wrapped with your password and stored remotely.';
	@override String get keyContinue => 'Continue';
	@override String keyWriteFailed({required Object error}) => 'Could not write the key file to the cloud, cancelled: ${error}';
	@override String keyCloudEncrypted({required Object report}) => 'Remote data encrypted: ${report}';
	@override String get keyEncryptionOn => 'Encryption is on';
	@override String get keyDecryptTitle => 'Decrypt the remote data';
	@override String get keyDecryptMessage => 'Turning encryption off decrypts the remote entries, categories and media files back to plain text and deletes the key file. Continue?';
	@override String keyDecryptPartial({required Object failed}) => '${failed} object(s) could not be decrypted, so encryption stays on and the remote key file was kept. Check your connection and try turning it off again.';
	@override String keyEncryptPartial({required Object failed}) => '${failed} object(s) could not be encrypted and are still plaintext on the remote. Check your connection and turn encryption on again to finish them.';
	@override String get keyEncryptionOff => 'Encryption is off';
	@override String keyReCipherFailed({required Object error}) => 'Re-encryption failed: ${error}';
	@override String get keyRemoteEmpty => 'The remote is empty — only the local key was saved';
	@override String get keyProcessing => 'Working on the remote data';
	@override String get keyPreparing => 'Preparing';
	@override String get keyUnlocked => 'Unlocked the remote key with that password';
	@override String get keyChangedLocalOnly => 'Password updated on this device. The remote is encrypted with a different key — unlock it and the new password syncs automatically.';
	@override String keyRemoteProbeFailed({required Object error}) => 'Could not read the remote key file, so nothing was changed: ${error}';
	@override String get keyRemoteMismatchTitle => 'That password does not open the remote key';
	@override String get keyRemoteMismatchMessage => 'The remote data was encrypted with a different password. Go back and try the original one. You can also discard the encrypted remote data and re-upload this device\'s data with a new password.';
	@override String get keyDiscardRemote => 'Discard remote data';
	@override String get keyDiscardTitle => 'Discard the encrypted remote data';
	@override String get keyDiscardMessage => 'The diaries, categories and media currently on the remote can never be decrypted again, and this cannot be undone. Data on this device is untouched and will be re-uploaded with the new password on the next sync. Continue?';
	@override String get keyDiscardConfirm => 'Discard';
	@override String keyDiscardFailed({required Object error}) => 'Could not remove the remote key file, so nothing was changed: ${error}';
	@override String get keyConflictTitle => 'Unlock the remote key';
	@override String get keyConflictSubtitle => 'The remote is encrypted with a different key and sync is paused. Tap to enter the password.';
	@override String get errKeyConflict => 'The remote is encrypted with a different key that this device cannot open. Sync stopped so the remote key file is not overwritten.';
	@override String get lanReceiveHint => 'The sender usually finds this device on its own; the address above can also be typed in by hand. Keep this page open while receiving.';
	@override String get errKeyfileCorrupt => 'The remote key file is corrupt (not a JSON object)';
	@override String get errKeyfileKdfMissing => 'The remote key file is corrupt (KDF parameters missing)';
	@override String get errKeyfileKdfRange => 'The remote key file\'s KDF parameters are out of the allowed range';
	@override String errKeyfileParse({required Object error}) => 'Could not parse the remote key file: ${error}';
	@override String get errKeyfileFields => 'The remote key file is corrupt (fields missing)';
	@override String errKeyfileVersion({required Object version, required Object supported}) => 'The remote key file is too new (v${version}; this build supports up to v${supported}). Update the app.';
	@override String errManifestVersion({required Object remote, required Object local}) => 'Backup format version mismatch: the data is v${remote}, this device supports v${local}. Open it with a matching version rather than letting this one overwrite it';
	@override String get errManifestEntriesCorrupt => 'The backup manifest\'s entries field is corrupt (not an object); stopped to avoid losing entries';
	@override String get errDecryptFailed => 'Could not decrypt the file — the key may not match';
	@override String get errManifestCorrupt => 'The remote manifest is corrupt (not a JSON object). Sync was stopped so remote entries are not lost.';
	@override String get errManifestReCipher => 'The remote manifest is malformed and cannot be re-encrypted';
	@override String get errManifestRace => 'Another device overwrote the manifest while it was being written; re-encryption was stopped';
	@override String get errNotBackup => 'Not a Moodiary backup file';
	@override String get errLegacyBackup => 'This backup was created by a version older than 2.8.0 and cannot be imported. Restore it in the old version first, then upgrade.';
	@override String errBackupParse({required Object error}) => 'Could not parse the backup file: ${error}';
	@override String get errNotReceiver => 'That host is not a Moodiary receiver';
	@override String get errVersionMismatch => 'Version mismatch — update Moodiary on both devices to the same version';
	@override String get errReceiverOffline => 'The other device is not receiving. Make sure its Receive page is open.';
	@override String get errS3Config => 'Finish the S3 configuration first';
	@override String get errWebdavConfig => 'Finish the WebDAV configuration first';
	@override String get errWrongKeyPassword => 'Wrong password — the key file could not be unlocked';
	@override String errKdf({required Object error}) => 'Key derivation failed: ${error}';
	@override String get errLocked => 'Another device is syncing right now — try again shortly';
	@override String get errMediaUpload => 'Some media files failed to upload, so this entry was skipped';
	@override String get errNoUserKey => 'The remote files are encrypted but no user key is configured';
	@override String errReadRemote({required Object key, required Object error}) => 'Could not read the remote object (${key}): ${error}';
	@override String errCreateRemote({required Object key, required Object error}) => 'Could not create the remote object (${key}): ${error}';
	@override String get errNoBackend => 'No sync backend configured';
	@override String get errManifestBroken => 'The remote manifest is malformed';
	@override String uploading({required Object backend}) => 'Uploading / exporting: ${backend}';
	@override String downloading({required Object backend}) => 'Downloading / importing: ${backend}';
	@override String syncing({required Object backend}) => 'Syncing: ${backend}';
	@override String pendingSummary({required Object parts}) => 'Syncing from the cloud: ${parts}';
	@override String pendingNew({required Object count}) => '${count} to download';
	@override String pendingUpdate({required Object count}) => '${count} to update';
	@override String get warnRemoteEmpty => 'The remote is empty — nothing has been uploaded yet';
	@override String warnFailedSkipped({required Object count}) => '${count} items failed and were skipped';
	@override String get warnStopped => 'Stopped by you — the rest will continue on the next sync';
	@override String warnFailedCount({required Object count}) => '${count} failed';
	@override String reCipherSummary({required Object diary, required Object category, required Object mediaInfo, required Object media, required Object ms}) => '${diary} entries + ${category} categories + ${mediaInfo} media records + ${media} files (${ms}ms)';
	@override String reCipherFailedSuffix({required Object base, required Object failed}) => '${base}\n${failed} objects failed and were skipped';
	@override String get stepPrepare => 'Preparing';
	@override String stepDiary({required Object id}) => 'Entry ${id}';
	@override String stepCategory({required Object id}) => 'Category ${id}';
	@override String stepMediaInfo({required Object id}) => 'Media record ${id}';
	@override String stepMedia({required Object ref}) => 'Media ${ref}';
	@override String get stepManifest => 'Writing the manifest';
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
