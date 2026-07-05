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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
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

  /// No description provided for @homeNewDiaryTiptap.
  ///
  /// In zh, this message translates to:
  /// **'日记'**
  String get homeNewDiaryTiptap;

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

  /// No description provided for @mediaEmpty.
  ///
  /// In zh, this message translates to:
  /// **'这里还没有媒体'**
  String get mediaEmpty;

  /// No description provided for @mediaCleanupScanning.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描无用文件'**
  String get mediaCleanupScanning;

  /// No description provided for @mediaCleanupEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有发现无用文件'**
  String get mediaCleanupEmpty;

  /// No description provided for @mediaCleanupConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理无用文件'**
  String get mediaCleanupConfirmTitle;

  /// No description provided for @mediaCleanupConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'发现 {count} 个未被任何日记引用的文件（{size}），确认清理？此操作不可恢复。'**
  String mediaCleanupConfirmMessage(Object count, Object size);

  /// No description provided for @mediaCleanupDone.
  ///
  /// In zh, this message translates to:
  /// **'已清理 {count} 个文件'**
  String mediaCleanupDone(Object count);

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

  /// No description provided for @categoryColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'颜色'**
  String get categoryColorLabel;

  /// No description provided for @backupSyncWebDAVConnectivity.
  ///
  /// In zh, this message translates to:
  /// **'连通性'**
  String get backupSyncWebDAVConnectivity;

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

  /// No description provided for @diarySearchTime.
  ///
  /// In zh, this message translates to:
  /// **'耗时 {ms}ms'**
  String diarySearchTime(Object ms);

  /// No description provided for @searchRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部时间'**
  String get searchRangeAll;

  /// No description provided for @searchRange7d.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天'**
  String get searchRange7d;

  /// No description provided for @searchRange30d.
  ///
  /// In zh, this message translates to:
  /// **'近 30 天'**
  String get searchRange30d;

  /// No description provided for @searchRangeYear.
  ///
  /// In zh, this message translates to:
  /// **'今年'**
  String get searchRangeYear;

  /// No description provided for @searchRangeCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get searchRangeCustom;

  /// No description provided for @searchCategoryAll.
  ///
  /// In zh, this message translates to:
  /// **'全部分类'**
  String get searchCategoryAll;

  /// No description provided for @searchSortRelevance.
  ///
  /// In zh, this message translates to:
  /// **'相关度'**
  String get searchSortRelevance;

  /// No description provided for @searchSortNewest.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get searchSortNewest;

  /// No description provided for @searchSortOldest.
  ///
  /// In zh, this message translates to:
  /// **'最早'**
  String get searchSortOldest;

  /// No description provided for @searchNoResult.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的日记'**
  String get searchNoResult;

  /// No description provided for @searchHistory.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get searchHistory;

  /// No description provided for @searchHistoryClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get searchHistoryClear;

  /// No description provided for @searchHistoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无搜索历史'**
  String get searchHistoryEmpty;

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

  /// No description provided for @editSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get editSaveFailed;

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

  /// No description provided for @toastSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get toastSuccess;

  /// No description provided for @toastError.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get toastError;

  /// No description provided for @toastLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中'**
  String get toastLoading;

  /// No description provided for @genQrCodeError1.
  ///
  /// In zh, this message translates to:
  /// **'请先配置 {name}'**
  String genQrCodeError1(Object name);

  /// No description provided for @genQrCodeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'生成二维码'**
  String get genQrCodeTooltip;

  /// No description provided for @qrCodeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'二维码无效'**
  String get qrCodeInvalid;

  /// No description provided for @inputTooltip.
  ///
  /// In zh, this message translates to:
  /// **'输入'**
  String get inputTooltip;

  /// No description provided for @inputMethodTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入方式'**
  String get inputMethodTitle;

  /// No description provided for @inputMethodScanQrCode.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get inputMethodScanQrCode;

  /// No description provided for @inputMethodHandelInput.
  ///
  /// In zh, this message translates to:
  /// **'手动输入'**
  String get inputMethodHandelInput;

  /// No description provided for @getKeyFromConsole.
  ///
  /// In zh, this message translates to:
  /// **'请从对应控制台获取密钥'**
  String get getKeyFromConsole;

  /// No description provided for @hasOption.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get hasOption;

  /// No description provided for @noOption.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get noOption;

  /// No description provided for @labQweather.
  ///
  /// In zh, this message translates to:
  /// **'和风天气'**
  String get labQweather;

  /// No description provided for @labTianditu.
  ///
  /// In zh, this message translates to:
  /// **'天地图'**
  String get labTianditu;

  /// No description provided for @labTencentCloud.
  ///
  /// In zh, this message translates to:
  /// **'腾讯云'**
  String get labTencentCloud;

  /// No description provided for @diaryViewModeCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历视图'**
  String get diaryViewModeCalendar;

  /// No description provided for @assistantConfigTooltip.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get assistantConfigTooltip;

  /// No description provided for @assistantWelcome.
  ///
  /// In zh, this message translates to:
  /// **'你好，我是 Moodiary 助手，有什么可以帮你的吗？'**
  String get assistantWelcome;

  /// No description provided for @assistantInputHint.
  ///
  /// In zh, this message translates to:
  /// **'说点什么...'**
  String get assistantInputHint;

  /// No description provided for @assistantNotConfiguredBanner.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置可用的模型供应商，点击前往配置。'**
  String get assistantNotConfiguredBanner;

  /// No description provided for @assistantNeedProvider.
  ///
  /// In zh, this message translates to:
  /// **'请先在「模型供应商」中添加并选择一个可用的供应商。'**
  String get assistantNeedProvider;

  /// No description provided for @assistantNeedApiKey.
  ///
  /// In zh, this message translates to:
  /// **'请先在「模型供应商」中填写 API Key。'**
  String get assistantNeedApiKey;

  /// No description provided for @assistantSettingTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 助手配置'**
  String get assistantSettingTitle;

  /// No description provided for @assistantSettingNote.
  ///
  /// In zh, this message translates to:
  /// **'助手基于 rig 构建。在「模型供应商」里自定义任意数量的服务商（OpenAI / Anthropic 兼容端点），自由切换激活项。API Key 仅保存在本机安全存储。'**
  String get assistantSettingNote;

  /// No description provided for @assistantProviderEntryLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get assistantProviderEntryLoading;

  /// No description provided for @assistantProviderEntryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加供应商，点击去添加'**
  String get assistantProviderEntryEmpty;

  /// No description provided for @assistantCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get assistantCopied;

  /// No description provided for @assistantCopyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get assistantCopyTooltip;

  /// No description provided for @assistantNewChat.
  ///
  /// In zh, this message translates to:
  /// **'新对话'**
  String get assistantNewChat;

  /// No description provided for @assistantHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史会话'**
  String get assistantHistory;

  /// No description provided for @assistantHistoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'历史会话'**
  String get assistantHistoryTitle;

  /// No description provided for @assistantHistoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有历史会话'**
  String get assistantHistoryEmpty;

  /// No description provided for @assistantSessionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get assistantSessionDelete;

  /// No description provided for @assistantStop.
  ///
  /// In zh, this message translates to:
  /// **'停止生成'**
  String get assistantStop;

  /// No description provided for @assistantRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新回答'**
  String get assistantRegenerate;

  /// No description provided for @assistantSectionTool.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get assistantSectionTool;

  /// No description provided for @assistantToolSectionNote.
  ///
  /// In zh, this message translates to:
  /// **'助手会根据对话内容自动调用下列工具，无需手动开启。'**
  String get assistantToolSectionNote;

  /// No description provided for @assistantToolSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'日记检索'**
  String get assistantToolSearchTitle;

  /// No description provided for @assistantToolSearchDes.
  ///
  /// In zh, this message translates to:
  /// **'按关键词检索你的本地日记，用于回答涉及过往经历、情绪记录的问题。'**
  String get assistantToolSearchDes;

  /// No description provided for @assistantToolCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建日记'**
  String get assistantToolCreateTitle;

  /// No description provided for @assistantToolCreateDes.
  ///
  /// In zh, this message translates to:
  /// **'按你的请求把内容保存为一篇新的本地日记。'**
  String get assistantToolCreateDes;

  /// No description provided for @assistantToolUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改日记'**
  String get assistantToolUpdateTitle;

  /// No description provided for @assistantToolUpdateDes.
  ///
  /// In zh, this message translates to:
  /// **'按你的要求修改某篇日记的标题、正文、心情或归类。'**
  String get assistantToolUpdateDes;

  /// No description provided for @assistantToolDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除日记'**
  String get assistantToolDeleteTitle;

  /// No description provided for @assistantToolDeleteDes.
  ///
  /// In zh, this message translates to:
  /// **'把指定日记移入回收站（可在回收站恢复）。'**
  String get assistantToolDeleteDes;

  /// No description provided for @assistantToolListCategoriesTitle.
  ///
  /// In zh, this message translates to:
  /// **'查看分类'**
  String get assistantToolListCategoriesTitle;

  /// No description provided for @assistantToolListCategoriesDes.
  ///
  /// In zh, this message translates to:
  /// **'列出你的全部日记分类。'**
  String get assistantToolListCategoriesDes;

  /// No description provided for @assistantToolCreateCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建分类'**
  String get assistantToolCreateCategoryTitle;

  /// No description provided for @assistantToolCreateCategoryDes.
  ///
  /// In zh, this message translates to:
  /// **'新建一个日记分类。'**
  String get assistantToolCreateCategoryDes;

  /// No description provided for @assistantToolUpdateCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名分类'**
  String get assistantToolUpdateCategoryTitle;

  /// No description provided for @assistantToolUpdateCategoryDes.
  ///
  /// In zh, this message translates to:
  /// **'修改某个分类的名称。'**
  String get assistantToolUpdateCategoryDes;

  /// No description provided for @assistantToolDeleteCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get assistantToolDeleteCategoryTitle;

  /// No description provided for @assistantToolDeleteCategoryDes.
  ///
  /// In zh, this message translates to:
  /// **'删除一个分类（仅当其下没有日记时）。'**
  String get assistantToolDeleteCategoryDes;

  /// No description provided for @assistantToolDangerBadge.
  ///
  /// In zh, this message translates to:
  /// **'危险'**
  String get assistantToolDangerBadge;

  /// No description provided for @assistantToolPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'助手请求执行操作'**
  String get assistantToolPermissionTitle;

  /// No description provided for @assistantToolPermissionDangerNote.
  ///
  /// In zh, this message translates to:
  /// **'这是危险操作，会修改或删除你的数据，请谨慎确认。'**
  String get assistantToolPermissionDangerNote;

  /// No description provided for @assistantToolAllowOnce.
  ///
  /// In zh, this message translates to:
  /// **'允许一次'**
  String get assistantToolAllowOnce;

  /// No description provided for @assistantToolAllowAlways.
  ///
  /// In zh, this message translates to:
  /// **'始终允许'**
  String get assistantToolAllowAlways;

  /// No description provided for @assistantToolDeny.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get assistantToolDeny;

  /// No description provided for @assistantToolAlwaysAllowedHint.
  ///
  /// In zh, this message translates to:
  /// **'已设为始终允许'**
  String get assistantToolAlwaysAllowedHint;

  /// No description provided for @assistantToolStatusAllowedOnce.
  ///
  /// In zh, this message translates to:
  /// **'已允许本次执行'**
  String get assistantToolStatusAllowedOnce;

  /// No description provided for @assistantToolStatusDenied.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝执行'**
  String get assistantToolStatusDenied;

  /// No description provided for @assistantToolStatusCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get assistantToolStatusCanceled;

  /// No description provided for @assistantToolResetGrants.
  ///
  /// In zh, this message translates to:
  /// **'重置已授权的工具'**
  String get assistantToolResetGrants;

  /// No description provided for @assistantToolResetGrantsDone.
  ///
  /// In zh, this message translates to:
  /// **'已重置工具授权'**
  String get assistantToolResetGrantsDone;

  /// No description provided for @assistantDisclaimerTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用前必读'**
  String get assistantDisclaimerTitle;

  /// No description provided for @assistantDisclaimerContent.
  ///
  /// In zh, this message translates to:
  /// **'Moodiary 助手由第三方大语言模型驱动，使用前请知悉：\n\n• AI 生成的内容可能不准确、不完整甚至具有误导性，请勿将其作为医疗、心理、法律、财务等专业建议，或任何重要决策的依据。\n\n• 发送消息后，你输入的内容会被发送给你所配置的模型供应商；当助手调用日记工具时，相关的本地日记摘要也会一并发送以生成回复。是否信任该供应商由你自行判断。\n\n• 你的 API Key 仅保存在本机安全存储，不会上传到 Moodiary 的服务器。\n\n继续使用即代表你已知悉并接受以上风险。'**
  String get assistantDisclaimerContent;

  /// No description provided for @assistantDisclaimerAgree.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get assistantDisclaimerAgree;

  /// No description provided for @assistantDisclaimerDecline.
  ///
  /// In zh, this message translates to:
  /// **'暂不使用'**
  String get assistantDisclaimerDecline;

  /// No description provided for @assistantDisclaimerGateTitle.
  ///
  /// In zh, this message translates to:
  /// **'需先同意免责声明才能使用助手'**
  String get assistantDisclaimerGateTitle;

  /// No description provided for @assistantDisclaimerGateAction.
  ///
  /// In zh, this message translates to:
  /// **'查看免责声明'**
  String get assistantDisclaimerGateAction;

  /// No description provided for @assistantToolPanelTitle.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get assistantToolPanelTitle;

  /// No description provided for @assistantToolSendDiary.
  ///
  /// In zh, this message translates to:
  /// **'发送日记'**
  String get assistantToolSendDiary;

  /// No description provided for @assistantSelectDiaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择日记'**
  String get assistantSelectDiaryTitle;

  /// No description provided for @assistantSelectDiarySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索日记'**
  String get assistantSelectDiarySearchHint;

  /// No description provided for @assistantSelectDiaryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可发送的日记'**
  String get assistantSelectDiaryEmpty;

  /// No description provided for @assistantDiaryUntitled.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get assistantDiaryUntitled;

  /// No description provided for @assistantSendDiaryLead.
  ///
  /// In zh, this message translates to:
  /// **'这是我的一篇日记，请阅读后帮我分析或回应：'**
  String get assistantSendDiaryLead;

  /// No description provided for @modelProviderTitle.
  ///
  /// In zh, this message translates to:
  /// **'模型供应商'**
  String get modelProviderTitle;

  /// No description provided for @modelProviderAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get modelProviderAdd;

  /// No description provided for @modelProviderActive.
  ///
  /// In zh, this message translates to:
  /// **'使用中'**
  String get modelProviderActive;

  /// No description provided for @modelProviderNoKey.
  ///
  /// In zh, this message translates to:
  /// **'缺少 Key'**
  String get modelProviderNoKey;

  /// No description provided for @modelProviderEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有模型供应商'**
  String get modelProviderEmptyTitle;

  /// No description provided for @modelProviderEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角「新增」添加一个服务商'**
  String get modelProviderEmptyHint;

  /// No description provided for @modelProviderDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除供应商'**
  String get modelProviderDeleteTitle;

  /// No description provided for @modelProviderDeleteContent.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？其 API Key 也会一并清除。'**
  String modelProviderDeleteContent(Object name);

  /// No description provided for @modelProviderDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get modelProviderDeleted;

  /// No description provided for @modelProviderEditNew.
  ///
  /// In zh, this message translates to:
  /// **'新增供应商'**
  String get modelProviderEditNew;

  /// No description provided for @modelProviderEditEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑供应商'**
  String get modelProviderEditEdit;

  /// No description provided for @modelProviderName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get modelProviderName;

  /// No description provided for @modelProviderNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 DeepSeek / 本地 Ollama'**
  String get modelProviderNameHint;

  /// No description provided for @modelProviderProtocol.
  ///
  /// In zh, this message translates to:
  /// **'协议类型'**
  String get modelProviderProtocol;

  /// No description provided for @modelProviderBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'baseUrl'**
  String get modelProviderBaseUrl;

  /// No description provided for @modelProviderBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'留空使用该协议官方端点'**
  String get modelProviderBaseUrlHint;

  /// No description provided for @modelProviderApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get modelProviderApiKey;

  /// No description provided for @modelProviderApiKeyHintSet.
  ///
  /// In zh, this message translates to:
  /// **'已配置，留空保持不变'**
  String get modelProviderApiKeyHintSet;

  /// No description provided for @modelProviderApiKeyHintUnset.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 API Key'**
  String get modelProviderApiKeyHintUnset;

  /// No description provided for @modelProviderModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get modelProviderModel;

  /// No description provided for @modelProviderNeedName.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get modelProviderNeedName;

  /// No description provided for @modelProviderNeedModel.
  ///
  /// In zh, this message translates to:
  /// **'请填写模型'**
  String get modelProviderNeedModel;

  /// No description provided for @modelProviderSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get modelProviderSaved;

  /// No description provided for @modelProviderGetApiKey.
  ///
  /// In zh, this message translates to:
  /// **'获取 API Key'**
  String get modelProviderGetApiKey;

  /// No description provided for @llmPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择供应商'**
  String get llmPickerTitle;

  /// No description provided for @llmPickerCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get llmPickerCustom;

  /// No description provided for @llmPickerCustomDes.
  ///
  /// In zh, this message translates to:
  /// **'手动填写供应商配置'**
  String get llmPickerCustomDes;

  /// No description provided for @llmPickerRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get llmPickerRefresh;

  /// No description provided for @llmPickerRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'已更新'**
  String get llmPickerRefreshed;

  /// No description provided for @llmPickerLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get llmPickerLoadFailed;

  /// No description provided for @llmPickerRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get llmPickerRetry;

  /// No description provided for @llmPickerModelCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个模型'**
  String llmPickerModelCount(Object count);

  /// No description provided for @llmPickerUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新于 {time}'**
  String llmPickerUpdatedAt(Object time);

  /// No description provided for @llmPickerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用的预设供应商'**
  String get llmPickerEmpty;

  /// No description provided for @llmPickerDataSource.
  ///
  /// In zh, this message translates to:
  /// **'数据来自 models.dev'**
  String get llmPickerDataSource;

  /// No description provided for @llmPickerSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索供应商'**
  String get llmPickerSearchHint;

  /// No description provided for @modelProviderPickModel.
  ///
  /// In zh, this message translates to:
  /// **'选择模型'**
  String get modelProviderPickModel;

  /// No description provided for @modelProviderShowAll.
  ///
  /// In zh, this message translates to:
  /// **'显示全部'**
  String get modelProviderShowAll;

  /// No description provided for @modelProviderShowToolOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅工具可用'**
  String get modelProviderShowToolOnly;

  /// No description provided for @modelProviderBadgeTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get modelProviderBadgeTools;

  /// No description provided for @modelProviderBadgeReasoning.
  ///
  /// In zh, this message translates to:
  /// **'推理'**
  String get modelProviderBadgeReasoning;

  /// No description provided for @modelProviderSearchModelHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索模型'**
  String get modelProviderSearchModelHint;

  /// No description provided for @modelProviderNoModelMatch.
  ///
  /// In zh, this message translates to:
  /// **'无匹配模型'**
  String get modelProviderNoModelMatch;

  /// No description provided for @diaryLinkNotFound.
  ///
  /// In zh, this message translates to:
  /// **'日记不存在或已删除'**
  String get diaryLinkNotFound;

  /// No description provided for @backlinks.
  ///
  /// In zh, this message translates to:
  /// **'反向链接'**
  String get backlinks;

  /// No description provided for @categorySwitcherCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个分类'**
  String categorySwitcherCount(Object count);

  /// No description provided for @categorySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索分类'**
  String get categorySearchHint;

  /// No description provided for @categoryAllDiary.
  ///
  /// In zh, this message translates to:
  /// **'全部日记'**
  String get categoryAllDiary;

  /// No description provided for @categoryNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的分类'**
  String get categoryNoMatch;

  /// No description provided for @categorySyncingPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'正在同步分类…'**
  String get categorySyncingPlaceholder;

  /// No description provided for @categoryManageEntry.
  ///
  /// In zh, this message translates to:
  /// **'管理分类'**
  String get categoryManageEntry;

  /// No description provided for @diarySortTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get diarySortTitle;

  /// No description provided for @diarySortNewestFirst.
  ///
  /// In zh, this message translates to:
  /// **'最新在前'**
  String get diarySortNewestFirst;

  /// No description provided for @diarySortOldestFirst.
  ///
  /// In zh, this message translates to:
  /// **'最早在前'**
  String get diarySortOldestFirst;

  /// No description provided for @diarySortModifiedFirst.
  ///
  /// In zh, this message translates to:
  /// **'最近修改在前'**
  String get diarySortModifiedFirst;

  /// No description provided for @diarySortCalendarHint.
  ///
  /// In zh, this message translates to:
  /// **'日历按日期组织，不受排序影响'**
  String get diarySortCalendarHint;

  /// No description provided for @categoryDeletedReset.
  ///
  /// In zh, this message translates to:
  /// **'分类已被删除，已切回全部'**
  String get categoryDeletedReset;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
