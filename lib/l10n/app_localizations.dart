import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @hint.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get hint;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @hopeYouHappyToday.
  ///
  /// In zh, this message translates to:
  /// **'祝你今天愉快'**
  String get hopeYouHappyToday;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Moodiary'**
  String get appName;

  /// No description provided for @startTitle1.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用'**
  String get startTitle1;

  /// No description provided for @startTitle2.
  ///
  /// In zh, this message translates to:
  /// **'Moodiary'**
  String get startTitle2;

  /// No description provided for @startTitle3.
  ///
  /// In zh, this message translates to:
  /// **'无广告、无社交的私密日记本'**
  String get startTitle3;

  /// No description provided for @welcome1.
  ///
  /// In zh, this message translates to:
  /// **'感谢下载本产品！在正式使用前，希望您能阅读并理解我们的'**
  String get welcome1;

  /// No description provided for @welcome2.
  ///
  /// In zh, this message translates to:
  /// **'《隐私政策》'**
  String get welcome2;

  /// No description provided for @welcome3.
  ///
  /// In zh, this message translates to:
  /// **'和'**
  String get welcome3;

  /// No description provided for @welcome4.
  ///
  /// In zh, this message translates to:
  /// **'《用户协议》'**
  String get welcome4;

  /// No description provided for @welcome5.
  ///
  /// In zh, this message translates to:
  /// **'。我们一向尊重并会严格保护您在使用本产品时的合法权益不受到任何侵犯。用户开始使用本产品将视为已经接受本协议，如果您不能接受本协议中的全部条款，请勿开始使用本产品。'**
  String get welcome5;

  /// No description provided for @startChoice1.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get startChoice1;

  /// No description provided for @startChoice2.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get startChoice2;

  /// No description provided for @permission1.
  ///
  /// In zh, this message translates to:
  /// **'权限授予'**
  String get permission1;

  /// No description provided for @permission2.
  ///
  /// In zh, this message translates to:
  /// **'为了更好的使用体验，我们需要以下权限'**
  String get permission2;

  /// No description provided for @permission3.
  ///
  /// In zh, this message translates to:
  /// **'• 定位权限（用于获取天气）'**
  String get permission3;

  /// No description provided for @shareTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get shareTitle;

  /// No description provided for @shareName.
  ///
  /// In zh, this message translates to:
  /// **'© Moodiary'**
  String get shareName;

  /// No description provided for @settingFunction.
  ///
  /// In zh, this message translates to:
  /// **'功能'**
  String get settingFunction;

  /// No description provided for @settingFunctionCategoryManage.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get settingFunctionCategoryManage;

  /// No description provided for @settingFunctionAnalysis.
  ///
  /// In zh, this message translates to:
  /// **'分析统计'**
  String get settingFunctionAnalysis;

  /// No description provided for @settingFunctionTrailMap.
  ///
  /// In zh, this message translates to:
  /// **'足迹地图'**
  String get settingFunctionTrailMap;

  /// No description provided for @settingFunctionAIAssistant.
  ///
  /// In zh, this message translates to:
  /// **'智能助手'**
  String get settingFunctionAIAssistant;

  /// No description provided for @settingDataSyncAndBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份与同步'**
  String get settingDataSyncAndBackup;

  /// No description provided for @settingDashboard.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘'**
  String get settingDashboard;

  /// No description provided for @settingData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingData;

  /// No description provided for @settingRecycle.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get settingRecycle;

  /// No description provided for @settingExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get settingExport;

  /// No description provided for @settingExportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据导出'**
  String get settingExportDialogTitle;

  /// No description provided for @settingExportDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'确认后会将当前应用的数据导出为 ZIP 文件，文件可用于应用内导入使用。'**
  String get settingExportDialogContent;

  /// No description provided for @settingImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get settingImport;

  /// No description provided for @settingImportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据导入'**
  String get settingImportDialogTitle;

  /// No description provided for @settingImportDialogContent.
  ///
  /// In zh, this message translates to:
  /// **'导入数据会覆盖当前已经有的数据，且原有数据无法恢复！请确认备份好原有数据。'**
  String get settingImportDialogContent;

  /// No description provided for @settingImportSelectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get settingImportSelectFile;

  /// No description provided for @settingImportDes.
  ///
  /// In zh, this message translates to:
  /// **'仅支持本应用导出的文件'**
  String get settingImportDes;

  /// No description provided for @settingClean.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get settingClean;

  /// No description provided for @settingDisplay.
  ///
  /// In zh, this message translates to:
  /// **'显示与个性'**
  String get settingDisplay;

  /// No description provided for @settingDiary.
  ///
  /// In zh, this message translates to:
  /// **'日记设置'**
  String get settingDiary;

  /// No description provided for @settingThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingThemeMode;

  /// No description provided for @settingColor.
  ///
  /// In zh, this message translates to:
  /// **'配色方案'**
  String get settingColor;

  /// No description provided for @settingAutoPlay.
  ///
  /// In zh, this message translates to:
  /// **'首页卡片自动轮播'**
  String get settingAutoPlay;

  /// No description provided for @settingDynamicColor.
  ///
  /// In zh, this message translates to:
  /// **'首页卡片动态配色'**
  String get settingDynamicColor;

  /// No description provided for @settingImageQuality.
  ///
  /// In zh, this message translates to:
  /// **'图片质量'**
  String get settingImageQuality;

  /// No description provided for @settingImageQualityDes.
  ///
  /// In zh, this message translates to:
  /// **'只对修改后的图片生效'**
  String get settingImageQualityDes;

  /// No description provided for @settingFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get settingFontSize;

  /// No description provided for @settingFontStyle.
  ///
  /// In zh, this message translates to:
  /// **'字体样式'**
  String get settingFontStyle;

  /// No description provided for @settingWeather.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏显示天气'**
  String get settingWeather;

  /// No description provided for @settingPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私与安全'**
  String get settingPrivacy;

  /// No description provided for @settingLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地化'**
  String get settingLocal;

  /// No description provided for @settingLocalDes.
  ///
  /// In zh, this message translates to:
  /// **'开启后关闭所有云端功能'**
  String get settingLocalDes;

  /// No description provided for @settingLock.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get settingLock;

  /// No description provided for @settingLockTypeNumber.
  ///
  /// In zh, this message translates to:
  /// **'数字'**
  String get settingLockTypeNumber;

  /// No description provided for @settingLockClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get settingLockClose;

  /// No description provided for @settingLockSupportBiometricsDes.
  ///
  /// In zh, this message translates to:
  /// **'系统支持生物识别'**
  String get settingLockSupportBiometricsDes;

  /// No description provided for @settingLockNotSupportBiometricsDes.
  ///
  /// In zh, this message translates to:
  /// **'系统不支持生物识别'**
  String get settingLockNotSupportBiometricsDes;

  /// No description provided for @settingLockOpen.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get settingLockOpen;

  /// No description provided for @settingLockNotOpen.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get settingLockNotOpen;

  /// No description provided for @settingLockNow.
  ///
  /// In zh, this message translates to:
  /// **'立即锁定'**
  String get settingLockNow;

  /// No description provided for @settingLockNowDes.
  ///
  /// In zh, this message translates to:
  /// **'离开应用时立即锁定应用'**
  String get settingLockNowDes;

  /// No description provided for @settingLockChooseLockType.
  ///
  /// In zh, this message translates to:
  /// **'请选择密码类型'**
  String get settingLockChooseLockType;

  /// No description provided for @settingLockResetLock.
  ///
  /// In zh, this message translates to:
  /// **'已经开启密码，重新设置请先关闭'**
  String get settingLockResetLock;

  /// No description provided for @settingBackendPrivacyProtection.
  ///
  /// In zh, this message translates to:
  /// **'后台隐私保护'**
  String get settingBackendPrivacyProtection;

  /// No description provided for @settingBackendPrivacyProtectionDes.
  ///
  /// In zh, this message translates to:
  /// **'应用处于后台时，隐藏应用内容'**
  String get settingBackendPrivacyProtectionDes;

  /// No description provided for @settingUserKey.
  ///
  /// In zh, this message translates to:
  /// **'私有密钥'**
  String get settingUserKey;

  /// No description provided for @settingUserKeyDes.
  ///
  /// In zh, this message translates to:
  /// **'可用于数据加密'**
  String get settingUserKeyDes;

  /// No description provided for @settingUserKeySet.
  ///
  /// In zh, this message translates to:
  /// **'设置密钥'**
  String get settingUserKeySet;

  /// No description provided for @settingUserKeySetDes.
  ///
  /// In zh, this message translates to:
  /// **'⚠️ 密钥设置后无法获取，请妥善保管，如果您需要在其他设备上使用加密数据，请确保使用相同的密钥。'**
  String get settingUserKeySetDes;

  /// No description provided for @settingUserKeyReset.
  ///
  /// In zh, this message translates to:
  /// **'重置密钥'**
  String get settingUserKeyReset;

  /// No description provided for @settingUserKeyResetDes.
  ///
  /// In zh, this message translates to:
  /// **'确定要重置密钥吗？'**
  String get settingUserKeyResetDes;

  /// No description provided for @settingUserKeyHasSet.
  ///
  /// In zh, this message translates to:
  /// **'已设置'**
  String get settingUserKeyHasSet;

  /// No description provided for @settingUserKeyNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get settingUserKeyNotSet;

  /// No description provided for @settingMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get settingMore;

  /// No description provided for @settingLab.
  ///
  /// In zh, this message translates to:
  /// **'实验室'**
  String get settingLab;

  /// No description provided for @settingAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingAbout;

  /// No description provided for @settingLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingLanguage;

  /// No description provided for @settingLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingLanguageSystem;

  /// No description provided for @settingLanguageSimpleChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingLanguageSimpleChinese;

  /// No description provided for @settingLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingLanguageEnglish;

  /// No description provided for @settingHomepageName.
  ///
  /// In zh, this message translates to:
  /// **'首页标题名称'**
  String get settingHomepageName;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get themeModeDark;

  /// No description provided for @colorNameSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get colorNameSystem;

  /// No description provided for @colorNameQunQin.
  ///
  /// In zh, this message translates to:
  /// **'群青'**
  String get colorNameQunQin;

  /// No description provided for @colorNameJiHe.
  ///
  /// In zh, this message translates to:
  /// **'芰荷'**
  String get colorNameJiHe;

  /// No description provided for @colorNameQinDai.
  ///
  /// In zh, this message translates to:
  /// **'青黛'**
  String get colorNameQinDai;

  /// No description provided for @colorNameXiangYe.
  ///
  /// In zh, this message translates to:
  /// **'缃叶'**
  String get colorNameXiangYe;

  /// No description provided for @colorNameBaiCaoShuang.
  ///
  /// In zh, this message translates to:
  /// **'百草霜'**
  String get colorNameBaiCaoShuang;

  /// No description provided for @colorNameShuiZhuHua.
  ///
  /// In zh, this message translates to:
  /// **'水朱华'**
  String get colorNameShuiZhuHua;

  /// No description provided for @colorCommon.
  ///
  /// In zh, this message translates to:
  /// **'普通配色'**
  String get colorCommon;

  /// No description provided for @specialColorNameMochaMousse.
  ///
  /// In zh, this message translates to:
  /// **'摩卡慕斯'**
  String get specialColorNameMochaMousse;

  /// No description provided for @fontNameDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get fontNameDefault;

  /// No description provided for @qualityLow.
  ///
  /// In zh, this message translates to:
  /// **'低(720p)'**
  String get qualityLow;

  /// No description provided for @qualityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中(1080p)'**
  String get qualityMedium;

  /// No description provided for @qualityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高(1440p)'**
  String get qualityHigh;

  /// No description provided for @qualityOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原图'**
  String get qualityOriginal;

  /// No description provided for @lockEnterPassword.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get lockEnterPassword;

  /// No description provided for @lockSetPassword.
  ///
  /// In zh, this message translates to:
  /// **'请设置密码'**
  String get lockSetPassword;

  /// No description provided for @lockConfirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'请确认密码'**
  String get lockConfirmPassword;

  /// No description provided for @sidebarUpdateLog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get sidebarUpdateLog;

  /// No description provided for @sidebarAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于应用'**
  String get sidebarAbout;

  /// No description provided for @sidebarPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get sidebarPrivacy;

  /// No description provided for @sidebarBug.
  ///
  /// In zh, this message translates to:
  /// **'BUG反馈'**
  String get sidebarBug;

  /// No description provided for @sidebarCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get sidebarCheckUpdate;

  /// No description provided for @homeNavigatorDiary.
  ///
  /// In zh, this message translates to:
  /// **'日记'**
  String get homeNavigatorDiary;

  /// No description provided for @homeNavigatorCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get homeNavigatorCalendar;

  /// No description provided for @homeNavigatorMedia.
  ///
  /// In zh, this message translates to:
  /// **'媒体'**
  String get homeNavigatorMedia;

  /// No description provided for @homeNavigatorSetting.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeNavigatorSetting;

  /// No description provided for @homeNavigatorAssistant.
  ///
  /// In zh, this message translates to:
  /// **'助手'**
  String get homeNavigatorAssistant;

  /// No description provided for @homePageAddDiaryButton.
  ///
  /// In zh, this message translates to:
  /// **'新建日记'**
  String get homePageAddDiaryButton;

  /// No description provided for @homeNewDiaryRichText.
  ///
  /// In zh, this message translates to:
  /// **'富文本'**
  String get homeNewDiaryRichText;

  /// No description provided for @homeNewDiaryMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'Markdown'**
  String get homeNewDiaryMarkdown;

  /// No description provided for @homeNewDiaryPlainText.
  ///
  /// In zh, this message translates to:
  /// **'纯文本'**
  String get homeNewDiaryPlainText;

  /// No description provided for @diaryViewModeList.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get diaryViewModeList;

  /// No description provided for @diaryViewModeGrid.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get diaryViewModeGrid;

  /// No description provided for @diaryTabViewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这里一片荒芜'**
  String get diaryTabViewEmpty;

  /// No description provided for @diaryPageSearchButton.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get diaryPageSearchButton;

  /// No description provided for @diaryPageViewModeButton.
  ///
  /// In zh, this message translates to:
  /// **'视图模式'**
  String get diaryPageViewModeButton;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutUpdate;

  /// No description provided for @aboutSource.
  ///
  /// In zh, this message translates to:
  /// **'查看源码'**
  String get aboutSource;

  /// No description provided for @aboutUserAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get aboutUserAgreement;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutBugReport.
  ///
  /// In zh, this message translates to:
  /// **'BUG 反馈'**
  String get aboutBugReport;

  /// No description provided for @aboutDonate.
  ///
  /// In zh, this message translates to:
  /// **'捐助我们'**
  String get aboutDonate;

  /// No description provided for @mediaTypeImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get mediaTypeImage;

  /// No description provided for @mediaTypeAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get mediaTypeAudio;

  /// No description provided for @mediaTypeVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get mediaTypeVideo;

  /// No description provided for @mediaDeleteUseLessFile.
  ///
  /// In zh, this message translates to:
  /// **'清理无用文件'**
  String get mediaDeleteUseLessFile;

  /// No description provided for @backupSyncTitle.
  ///
  /// In zh, this message translates to:
  /// **'备份与同步'**
  String get backupSyncTitle;

  /// No description provided for @backupSyncLocal.
  ///
  /// In zh, this message translates to:
  /// **'局域网传输'**
  String get backupSyncLocal;

  /// No description provided for @backupSyncWebdav.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV'**
  String get backupSyncWebdav;

  /// No description provided for @backupSyncWebdavNoOption.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get backupSyncWebdavNoOption;

  /// No description provided for @backupSyncWebdavOption.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get backupSyncWebdavOption;

  /// No description provided for @layoutErrorToast.
  ///
  /// In zh, this message translates to:
  /// **'布局异常'**
  String get layoutErrorToast;

  /// No description provided for @errorToast.
  ///
  /// In zh, this message translates to:
  /// **'出错了，请联系开发者'**
  String get errorToast;

  /// No description provided for @dashboardUseDays.
  ///
  /// In zh, this message translates to:
  /// **'使用天数'**
  String get dashboardUseDays;

  /// No description provided for @dashboardTotalDiary.
  ///
  /// In zh, this message translates to:
  /// **'日记数'**
  String get dashboardTotalDiary;

  /// No description provided for @dashboardTotalMedia.
  ///
  /// In zh, this message translates to:
  /// **'媒体数'**
  String get dashboardTotalMedia;

  /// No description provided for @dashboardTotalText.
  ///
  /// In zh, this message translates to:
  /// **'总字数'**
  String get dashboardTotalText;

  /// No description provided for @dashboardTotalCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类数'**
  String get dashboardTotalCategory;

  /// No description provided for @categoryManageAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加分类'**
  String get categoryManageAdd;

  /// No description provided for @categoryManageEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get categoryManageEdit;

  /// No description provided for @categoryManageName.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryManageName;

  /// No description provided for @categoryNoCategory.
  ///
  /// In zh, this message translates to:
  /// **'无分类'**
  String get categoryNoCategory;

  /// No description provided for @categoryAllCategory.
  ///
  /// In zh, this message translates to:
  /// **'全部分类'**
  String get categoryAllCategory;

  /// No description provided for @categoryAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get categoryAll;

  /// No description provided for @backupSyncLANTransfer.
  ///
  /// In zh, this message translates to:
  /// **'局域网传输'**
  String get backupSyncLANTransfer;

  /// No description provided for @backupSyncWebDAVConnectivity.
  ///
  /// In zh, this message translates to:
  /// **'连通性'**
  String get backupSyncWebDAVConnectivity;

  /// No description provided for @lanTransferSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get lanTransferSend;

  /// No description provided for @lanTransferReceive.
  ///
  /// In zh, this message translates to:
  /// **'接收'**
  String get lanTransferReceive;

  /// No description provided for @scanPort.
  ///
  /// In zh, this message translates to:
  /// **'扫描端口'**
  String get scanPort;

  /// No description provided for @transferPort.
  ///
  /// In zh, this message translates to:
  /// **'传输端口'**
  String get transferPort;

  /// No description provided for @lanTransferSelectDiary.
  ///
  /// In zh, this message translates to:
  /// **'选择你需要传输的日记'**
  String get lanTransferSelectDiary;

  /// No description provided for @lanTransferHasSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选择'**
  String get lanTransferHasSelected;

  /// No description provided for @lanTransferFindingServer.
  ///
  /// In zh, this message translates to:
  /// **'正在寻找服务器'**
  String get lanTransferFindingServer;

  /// No description provided for @lanTransferCantFindServer.
  ///
  /// In zh, this message translates to:
  /// **'未找到服务器'**
  String get lanTransferCantFindServer;

  /// No description provided for @lanTransferChangeScanPort.
  ///
  /// In zh, this message translates to:
  /// **'更改扫描端口'**
  String get lanTransferChangeScanPort;

  /// No description provided for @lanTransferChangeTransferPort.
  ///
  /// In zh, this message translates to:
  /// **'更改传输端口'**
  String get lanTransferChangeTransferPort;

  /// No description provided for @lanTransferChangePortDes.
  ///
  /// In zh, this message translates to:
  /// **'请确保两台设备端口一致，更改后需要重新扫描'**
  String get lanTransferChangePortDes;

  /// No description provided for @lanTransferChangePortError1.
  ///
  /// In zh, this message translates to:
  /// **'请输入临时端口号(49152-65535)'**
  String get lanTransferChangePortError1;

  /// No description provided for @lanTransferChangePortError2.
  ///
  /// In zh, this message translates to:
  /// **'请输入端口号'**
  String get lanTransferChangePortError2;

  /// No description provided for @lanTransferReceiveDes.
  ///
  /// In zh, this message translates to:
  /// **'接收过程中请勿关闭应用'**
  String get lanTransferReceiveDes;

  /// No description provided for @lanTransferReceiveServerStart.
  ///
  /// In zh, this message translates to:
  /// **'服务器已启动'**
  String get lanTransferReceiveServerStart;

  /// No description provided for @lanTransferHasReceived.
  ///
  /// In zh, this message translates to:
  /// **'已接收'**
  String get lanTransferHasReceived;

  /// No description provided for @webdavSyncWhenStartUp.
  ///
  /// In zh, this message translates to:
  /// **'启动时同步'**
  String get webdavSyncWhenStartUp;

  /// No description provided for @webdavSyncWhenStartUpDes.
  ///
  /// In zh, this message translates to:
  /// **'启动应用时自动同步'**
  String get webdavSyncWhenStartUpDes;

  /// No description provided for @webdavSyncAfterChange.
  ///
  /// In zh, this message translates to:
  /// **'更改后同步'**
  String get webdavSyncAfterChange;

  /// No description provided for @webdavSyncAfterChangeDes.
  ///
  /// In zh, this message translates to:
  /// **'更改数据后自动同步'**
  String get webdavSyncAfterChangeDes;

  /// No description provided for @webdavSyncEncryption.
  ///
  /// In zh, this message translates to:
  /// **'加密'**
  String get webdavSyncEncryption;

  /// No description provided for @webdavSyncEncryptionDes.
  ///
  /// In zh, this message translates to:
  /// **'加密同步数据，需要设置私有密钥'**
  String get webdavSyncEncryptionDes;

  /// No description provided for @webdavOptionServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get webdavOptionServer;

  /// No description provided for @webdavOptionServerDes.
  ///
  /// In zh, this message translates to:
  /// **'请填写服务器地址'**
  String get webdavOptionServerDes;

  /// No description provided for @webdavOptionUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get webdavOptionUsername;

  /// No description provided for @webdavOptionUsernameDes.
  ///
  /// In zh, this message translates to:
  /// **'请填写用户名'**
  String get webdavOptionUsernameDes;

  /// No description provided for @webdavOptionPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get webdavOptionPassword;

  /// No description provided for @webdavOptionPasswordDes.
  ///
  /// In zh, this message translates to:
  /// **'请填写密码'**
  String get webdavOptionPasswordDes;

  /// No description provided for @webdavOptionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除配置'**
  String get webdavOptionDelete;

  /// No description provided for @webdavOptionUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新配置'**
  String get webdavOptionUpdate;

  /// No description provided for @webdavOptionSave.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get webdavOptionSave;

  /// No description provided for @diarySettingRichText.
  ///
  /// In zh, this message translates to:
  /// **'富文本'**
  String get diarySettingRichText;

  /// No description provided for @diarySettingRichTextDes.
  ///
  /// In zh, this message translates to:
  /// **'支持更多样式及附件，让内容呈现更丰富'**
  String get diarySettingRichTextDes;

  /// No description provided for @diarySettingShowHeaderImage.
  ///
  /// In zh, this message translates to:
  /// **'日记页显示头图'**
  String get diarySettingShowHeaderImage;

  /// No description provided for @diarySettingPlainText.
  ///
  /// In zh, this message translates to:
  /// **'纯文本'**
  String get diarySettingPlainText;

  /// No description provided for @diarySettingPlainTextDes.
  ///
  /// In zh, this message translates to:
  /// **'去除多余样式，享受更纯粹的写作体验'**
  String get diarySettingPlainTextDes;

  /// No description provided for @diarySettingFirstLineIndent.
  ///
  /// In zh, this message translates to:
  /// **'自动首行缩进'**
  String get diarySettingFirstLineIndent;

  /// No description provided for @diarySettingCommon.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get diarySettingCommon;

  /// No description provided for @diarySettingCommonDes.
  ///
  /// In zh, this message translates to:
  /// **'日记的基本设置'**
  String get diarySettingCommonDes;

  /// No description provided for @diarySettingAutoGetWeather.
  ///
  /// In zh, this message translates to:
  /// **'自动获取天气'**
  String get diarySettingAutoGetWeather;

  /// No description provided for @diarySettingAutoSetCategory.
  ///
  /// In zh, this message translates to:
  /// **'自动设置分类'**
  String get diarySettingAutoSetCategory;

  /// No description provided for @diarySettingShowWritingTime.
  ///
  /// In zh, this message translates to:
  /// **'显示写作时间'**
  String get diarySettingShowWritingTime;

  /// No description provided for @diarySettingShowWriteCount.
  ///
  /// In zh, this message translates to:
  /// **'显示字数统计'**
  String get diarySettingShowWriteCount;

  /// No description provided for @diarySettingDynamicColor.
  ///
  /// In zh, this message translates to:
  /// **'日记页动态配色'**
  String get diarySettingDynamicColor;

  /// No description provided for @diarySettingDynamicColorDes.
  ///
  /// In zh, this message translates to:
  /// **'使用基于封面的配色'**
  String get diarySettingDynamicColorDes;

  /// No description provided for @fontStyleSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统字体'**
  String get fontStyleSystem;

  /// No description provided for @fontStyleSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontStyleSize;

  /// No description provided for @fontSizeSuperSmall.
  ///
  /// In zh, this message translates to:
  /// **'超小'**
  String get fontSizeSuperSmall;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get fontSizeStandard;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontSizeLarge;

  /// No description provided for @fontSizeSuperLarge.
  ///
  /// In zh, this message translates to:
  /// **'超大'**
  String get fontSizeSuperLarge;

  /// No description provided for @fontDeleteDes.
  ///
  /// In zh, this message translates to:
  /// **'删除字体 {fontName} 后，将无法恢复，确定删除吗？'**
  String fontDeleteDes(Object fontName);

  /// No description provided for @noticeEnableLocation.
  ///
  /// In zh, this message translates to:
  /// **'请开启定位权限'**
  String get noticeEnableLocation;

  /// No description provided for @noticeEnableLocation2.
  ///
  /// In zh, this message translates to:
  /// **'请前往设置中开启定位权限'**
  String get noticeEnableLocation2;

  /// No description provided for @diarySearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get diarySearch;

  /// No description provided for @diarySearchResult.
  ///
  /// In zh, this message translates to:
  /// **'共有 {count} 篇'**
  String diarySearchResult(Object count);

  /// No description provided for @webdavDashboardSetting.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 设置'**
  String get webdavDashboardSetting;

  /// No description provided for @webdavDashboardLocalDiaryCount.
  ///
  /// In zh, this message translates to:
  /// **'本地日记数'**
  String get webdavDashboardLocalDiaryCount;

  /// No description provided for @webdavDashboardRemoteDiaryCount.
  ///
  /// In zh, this message translates to:
  /// **'远程日记数'**
  String get webdavDashboardRemoteDiaryCount;

  /// No description provided for @webdavDashboardWaitingForUpload.
  ///
  /// In zh, this message translates to:
  /// **'待上传'**
  String get webdavDashboardWaitingForUpload;

  /// No description provided for @webdavDashboardWaitingForDownload.
  ///
  /// In zh, this message translates to:
  /// **'待下载'**
  String get webdavDashboardWaitingForDownload;

  /// No description provided for @webdavDashboardUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get webdavDashboardUpload;

  /// No description provided for @webdavDashboardDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get webdavDashboardDownload;

  /// No description provided for @webdavDashboardCurrentTaskQueue.
  ///
  /// In zh, this message translates to:
  /// **'当前任务队列'**
  String get webdavDashboardCurrentTaskQueue;

  /// No description provided for @webdavDashboardTaskEmpty.
  ///
  /// In zh, this message translates to:
  /// **'空闲'**
  String get webdavDashboardTaskEmpty;

  /// No description provided for @webdavDashboardTaskSync.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get webdavDashboardTaskSync;

  /// No description provided for @webdavDashboardConnectionError.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get webdavDashboardConnectionError;

  /// No description provided for @webdavSyncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get webdavSyncSuccess;

  /// No description provided for @webdavSyncGetConfigError.
  ///
  /// In zh, this message translates to:
  /// **'获取配置失败'**
  String get webdavSyncGetConfigError;

  /// No description provided for @updateFound.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateFound;

  /// No description provided for @updateToGoNow.
  ///
  /// In zh, this message translates to:
  /// **'前往更新'**
  String get updateToGoNow;

  /// No description provided for @editPickImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get editPickImage;

  /// No description provided for @editPickImageFromCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get editPickImageFromCamera;

  /// No description provided for @editPickImageFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get editPickImageFromGallery;

  /// No description provided for @editPickImageFromWeb.
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get editPickImageFromWeb;

  /// No description provided for @editPickImageFromDraw.
  ///
  /// In zh, this message translates to:
  /// **'涂鸦'**
  String get editPickImageFromDraw;

  /// No description provided for @editPickVideo.
  ///
  /// In zh, this message translates to:
  /// **'选择视频'**
  String get editPickVideo;

  /// No description provided for @editPickVideoFromCamera.
  ///
  /// In zh, this message translates to:
  /// **'录像'**
  String get editPickVideoFromCamera;

  /// No description provided for @editPickVideoFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get editPickVideoFromGallery;

  /// No description provided for @editPickAudio.
  ///
  /// In zh, this message translates to:
  /// **'选择音频'**
  String get editPickAudio;

  /// No description provided for @editPickAudioFromRecord.
  ///
  /// In zh, this message translates to:
  /// **'录音'**
  String get editPickAudioFromRecord;

  /// No description provided for @editPickAudioFromFile.
  ///
  /// In zh, this message translates to:
  /// **'音频文件'**
  String get editPickAudioFromFile;

  /// No description provided for @editDateAndTime.
  ///
  /// In zh, this message translates to:
  /// **'日期和时间'**
  String get editDateAndTime;

  /// No description provided for @editWeather.
  ///
  /// In zh, this message translates to:
  /// **'天气'**
  String get editWeather;

  /// No description provided for @editCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get editCategory;

  /// No description provided for @editTag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get editTag;

  /// No description provided for @editAddTag.
  ///
  /// In zh, this message translates to:
  /// **'添加标签'**
  String get editAddTag;

  /// No description provided for @editAddTagAlreadyExist.
  ///
  /// In zh, this message translates to:
  /// **'标签已存在'**
  String get editAddTagAlreadyExist;

  /// No description provided for @editAddTagCannotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'标签不能为空'**
  String get editAddTagCannotEmpty;

  /// No description provided for @editMood.
  ///
  /// In zh, this message translates to:
  /// **'心情'**
  String get editMood;

  /// No description provided for @editTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get editTime;

  /// No description provided for @editCount.
  ///
  /// In zh, this message translates to:
  /// **'字数'**
  String get editCount;

  /// No description provided for @editTitle.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get editTitle;

  /// No description provided for @editContent.
  ///
  /// In zh, this message translates to:
  /// **'正文'**
  String get editContent;

  /// No description provided for @editIndent.
  ///
  /// In zh, this message translates to:
  /// **'缩进'**
  String get editIndent;

  /// No description provided for @backAgainToExit.
  ///
  /// In zh, this message translates to:
  /// **'再按一次退出'**
  String get backAgainToExit;

  /// No description provided for @cancelSelect.
  ///
  /// In zh, this message translates to:
  /// **'取消选择'**
  String get cancelSelect;

  /// No description provided for @imageFetchError.
  ///
  /// In zh, this message translates to:
  /// **'图片获取失败'**
  String get imageFetchError;

  /// No description provided for @imageFetching.
  ///
  /// In zh, this message translates to:
  /// **'图片获取中'**
  String get imageFetching;

  /// No description provided for @editSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'保存成功'**
  String get editSaveSuccess;

  /// No description provided for @editChangeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'修改成功'**
  String get editChangeSuccess;

  /// No description provided for @locationError.
  ///
  /// In zh, this message translates to:
  /// **'定位失败'**
  String get locationError;

  /// No description provided for @weatherError.
  ///
  /// In zh, this message translates to:
  /// **'天气获取失败'**
  String get weatherError;

  /// No description provided for @weatherFetching.
  ///
  /// In zh, this message translates to:
  /// **'天气获取中'**
  String get weatherFetching;

  /// No description provided for @weatherSuccess.
  ///
  /// In zh, this message translates to:
  /// **'天气获取成功'**
  String get weatherSuccess;

  /// No description provided for @sureToSave.
  ///
  /// In zh, this message translates to:
  /// **'确定保存吗'**
  String get sureToSave;

  /// No description provided for @drawPickColor.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色'**
  String get drawPickColor;

  /// No description provided for @audioFileError.
  ///
  /// In zh, this message translates to:
  /// **'音频文件错误'**
  String get audioFileError;

  /// No description provided for @diaryDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get diaryDelete;

  /// No description provided for @diaryEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get diaryEdit;

  /// No description provided for @diaryShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get diaryShare;

  /// No description provided for @diaryCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String diaryCount(Object count);

  /// No description provided for @dataSync.
  ///
  /// In zh, this message translates to:
  /// **'数据同步'**
  String get dataSync;

  /// No description provided for @diaryType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get diaryType;

  /// No description provided for @mediaImageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 张照片'**
  String mediaImageCount(num count);

  /// No description provided for @mediaAudioCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段音频'**
  String mediaAudioCount(num count);

  /// No description provided for @mediaVideoCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段视频'**
  String mediaVideoCount(num count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
