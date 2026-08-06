import 'package:moodiary/app/settings/presentation/about_page.dart';
import 'package:moodiary/app/settings/presentation/agreement_page.dart';
import 'package:moodiary/app/settings/presentation/diary_setting_page.dart';
import 'package:moodiary/app/settings/presentation/font_page.dart';
import 'package:moodiary/app/settings/presentation/privacy_page.dart';
import 'package:moodiary/app/settings/presentation/services_page.dart';
import 'package:moodiary/app/settings/presentation/setting_page.dart';
import 'package:moodiary/app/settings/presentation/sponsor_page.dart';
import 'package:moodiary_router/moodiary_router.dart';

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
  GoRoute(path: ServicesRoute.path, builder: (_, _) => const ServicesPage()),
  GoRoute(path: AboutRoute.path, builder: (_, _) => const AboutPage()),
  GoRoute(path: PrivacyRoute.path, builder: (_, _) => const PrivacyPage()),
  GoRoute(path: AgreementRoute.path, builder: (_, _) => const AgreementPage()),
  GoRoute(path: SponsorRoute.path, builder: (_, _) => const SponsorPage()),
];
