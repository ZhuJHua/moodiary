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

List<RouteBase> settingRoutes() => [
  MoodiaryGoRoute(
    path: SettingRoute.path,
    builder: (_, _) => const SettingListPageMobile(),
  ),
  MoodiaryGoRoute(
    path: DiarySettingRoute.path,
    builder: (_, _) => const DiarySettingPage(),
  ),
  MoodiaryGoRoute(path: FontRoute.path, builder: (_, _) => const FontPage()),
  MoodiaryGoRoute(path: AccentRoute.path, builder: (_, _) => const AccentPage()),
  MoodiaryGoRoute(path: ServicesRoute.path, builder: (_, _) => const ServicesPage()),
  MoodiaryGoRoute(path: AboutRoute.path, builder: (_, _) => const AboutPage()),
  MoodiaryGoRoute(path: PrivacyRoute.path, builder: (_, _) => const PrivacyPage()),
  MoodiaryGoRoute(path: AgreementRoute.path, builder: (_, _) => const AgreementPage()),
  MoodiaryGoRoute(path: SponsorRoute.path, builder: (_, _) => const SponsorPage()),
];
