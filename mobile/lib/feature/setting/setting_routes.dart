import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'package:moodiary/feature/setting/presentation/about_page.dart';
import 'package:moodiary/feature/setting/presentation/agreement_page.dart';
import 'package:moodiary/feature/setting/presentation/diary_setting_page.dart';
import 'package:moodiary/feature/setting/presentation/editor_migration_page.dart';
import 'package:moodiary/feature/setting/presentation/font_page.dart';
import 'package:moodiary/feature/setting/presentation/privacy_page.dart';
import 'package:moodiary/feature/setting/presentation/services_page.dart';
import 'package:moodiary/feature/setting/presentation/sponsor_page.dart';

List<RouteBase> settingRoutes() => [
  GoRoute(
    path: DiarySettingRoute.path,
    builder: (_, _) => const DiarySettingPage(),
  ),
  GoRoute(
    path: EditorMigrationRoute.path,
    builder: (_, _) => const EditorMigrationPage(),
  ),
  GoRoute(path: FontRoute.path, builder: (_, _) => const FontPage()),
  GoRoute(path: ServicesRoute.path, builder: (_, _) => const ServicesPage()),
  GoRoute(path: AboutRoute.path, builder: (_, _) => const AboutPage()),
  GoRoute(path: PrivacyRoute.path, builder: (_, _) => const PrivacyPage()),
  GoRoute(path: AgreementRoute.path, builder: (_, _) => const AgreementPage()),
  GoRoute(path: SponsorRoute.path, builder: (_, _) => const SponsorPage()),
];
