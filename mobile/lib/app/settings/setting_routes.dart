import 'package:moodiary/app/settings/presentation/about_page.dart';
import 'package:moodiary/app/settings/presentation/accent_page.dart';
import 'package:moodiary/app/settings/presentation/agreement_page.dart';
import 'package:moodiary/app/settings/presentation/diary_setting_page.dart';
import 'package:moodiary/app/settings/presentation/font_page.dart';
import 'package:moodiary/app/settings/presentation/privacy_page.dart';
import 'package:moodiary/app/settings/presentation/services_page.dart';
import 'package:moodiary/app/settings/presentation/setting_page.dart';
import 'package:moodiary/app/settings/presentation/sponsor_page.dart';
import 'package:moodiary_router/moodiary_router.dart';

// ── app 私有路由契约：只有 mobile 在读，不进 moodiary_router 的跨包表。
// （SettingRoute/Privacy/Agreement 有跨包读者——分类抽屉、lock 的引导页——仍在包里。）

class FontRoute extends MoodiaryRouteBase {
  static const String path = '/setting/font';
  const FontRoute();
  @override
  String get location => path;
}

/// 自定义强调色取色页。灰度 / 壁纸两档在弹窗里一步选完，只有自定义才进这一层。
class AccentRoute extends MoodiaryRouteBase {
  static const String path = '/setting/accent';
  const AccentRoute();
  @override
  String get location => path;
}

class ServicesRoute extends MoodiaryRouteBase {
  static const String path = '/setting/services';
  const ServicesRoute();
  @override
  String get location => path;
}

class AboutRoute extends MoodiaryRouteBase {
  static const String path = '/setting/about';
  const AboutRoute();
  @override
  String get location => path;
}

class DiarySettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/diary_setting';
  const DiarySettingRoute();
  @override
  String get location => path;
}

class SponsorRoute extends MoodiaryRouteBase {
  static const String path = '/setting/sponsor';
  const SponsorRoute();
  @override
  String get location => path;
}

List<RouteBase> settingRoutes() => [
  GoRoute(
    path: SettingRoute.path,
    builder: (_, _) => const SettingListPageMobile(),
  ),
  GoRoute(
    path: DiarySettingRoute.path,
    builder: (_, _) => const DiarySettingPage(),
  ),
  GoRoute(path: FontRoute.path, builder: (_, _) => const FontPage()),
  GoRoute(path: AccentRoute.path, builder: (_, _) => const AccentPage()),
  GoRoute(path: ServicesRoute.path, builder: (_, _) => const ServicesPage()),
  GoRoute(path: AboutRoute.path, builder: (_, _) => const AboutPage()),
  GoRoute(path: PrivacyRoute.path, builder: (_, _) => const PrivacyPage()),
  GoRoute(path: AgreementRoute.path, builder: (_, _) => const AgreementPage()),
  GoRoute(path: SponsorRoute.path, builder: (_, _) => const SponsorPage()),
];
