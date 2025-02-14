import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:moodiary/components/desktop_wrapper/background.dart';
import 'package:moodiary/components/window_buttons/window_buttons.dart';
import 'package:moodiary/pages/about/about_logic.dart';
import 'package:moodiary/pages/about/about_view.dart';
import 'package:moodiary/pages/agreement/agreement_view.dart';
import 'package:moodiary/pages/analyse/analyse_logic.dart';
import 'package:moodiary/pages/analyse/analyse_view.dart';
import 'package:moodiary/pages/assistant/assistant_logic.dart';
import 'package:moodiary/pages/assistant/assistant_view.dart';
import 'package:moodiary/pages/backup_sync/backup_sync_logic.dart';
import 'package:moodiary/pages/backup_sync/backup_sync_view.dart';
import 'package:moodiary/pages/category_manager/category_manager_logic.dart';
import 'package:moodiary/pages/category_manager/category_manager_view.dart';
import 'package:moodiary/pages/diary_details/diary_details_view.dart';
import 'package:moodiary/pages/diary_setting/diary_setting_logic.dart';
import 'package:moodiary/pages/diary_setting/diary_setting_view.dart';
import 'package:moodiary/pages/draw/draw_logic.dart';
import 'package:moodiary/pages/draw/draw_view.dart';
import 'package:moodiary/pages/edit/edit_logic.dart';
import 'package:moodiary/pages/edit/edit_view.dart';
import 'package:moodiary/pages/font/font_logic.dart';
import 'package:moodiary/pages/font/font_view.dart';
import 'package:moodiary/pages/home/home_logic.dart';
import 'package:moodiary/pages/home/home_view.dart';
import 'package:moodiary/pages/image/image_logic.dart';
import 'package:moodiary/pages/image/image_view.dart';
import 'package:moodiary/pages/laboratory/laboratory_logic.dart';
import 'package:moodiary/pages/laboratory/laboratory_view.dart';
import 'package:moodiary/pages/lock/lock_logic.dart';
import 'package:moodiary/pages/lock/lock_view.dart';
import 'package:moodiary/pages/login/login_logic.dart';
import 'package:moodiary/pages/login/login_view.dart';
import 'package:moodiary/pages/map/map_logic.dart';
import 'package:moodiary/pages/map/map_view.dart';
import 'package:moodiary/pages/privacy/privacy_logic.dart';
import 'package:moodiary/pages/privacy/privacy_view.dart';
import 'package:moodiary/pages/recycle/recycle_logic.dart';
import 'package:moodiary/pages/recycle/recycle_view.dart';
import 'package:moodiary/pages/share/share_logic.dart';
import 'package:moodiary/pages/share/share_view.dart';
import 'package:moodiary/pages/sponsor/sponsor_view.dart';
import 'package:moodiary/pages/start/start_logic.dart';
import 'package:moodiary/pages/start/start_view.dart';
import 'package:moodiary/pages/user/user_logic.dart';
import 'package:moodiary/pages/user/user_view.dart';
import 'package:moodiary/pages/video/video_logic.dart';
import 'package:moodiary/pages/video/video_view.dart';
import 'package:page_transition/page_transition.dart';
import 'package:refreshed/refreshed.dart';

import '../pages/sponsor/sponsor_logic.dart';
import '../pages/web_view/web_view_logic.dart';
import '../pages/web_view/web_view_view.dart';
import 'app_routes.dart';

class AppPages {
  static final List<GetPage> routes = [
    //启动页
    MoodiaryGetPage(
      name: AppRoutes.startPage,
      page: () => const StartPage(),
      binds: [Bind.lazyPut(() => StartLogic())],
    ),
    //首页路由
    MoodiaryGetPage(
      name: AppRoutes.homePage,
      page: () => const HomePage(),
      binds: [Bind.lazyPut(() => HomeLogic())],
    ),
    //分析
    MoodiaryGetPage(
      name: AppRoutes.analysePage,
      page: () => const AnalysePage(),
      binds: [Bind.lazyPut(() => AnalyseLogic())],
    ),
    //日记页路由
    MoodiaryGetPage(name: AppRoutes.diaryPage, page: () => DiaryDetailsPage()),
    //图片路由
    MoodiaryGetPage(
      name: AppRoutes.photoPage,
      page: () => const ImagePage(),
      binds: [Bind.lazyPut(() => ImageLogic())],
    ),
    //回收站
    MoodiaryGetPage(
      name: AppRoutes.recyclePage,
      page: () => const RecyclePage(),
      binds: [Bind.lazyPut(() => RecycleLogic())],
    ),
    //登录路由
    MoodiaryGetPage(
      name: AppRoutes.loginPage,
      page: () => const LoginPage(),
      binds: [Bind.lazyPut(() => LoginLogic())],
    ),
    //新增/编辑日记路由
    MoodiaryGetPage(
      name: AppRoutes.editPage,
      page: () => const EditPage(),
      binds: [Bind.lazyPut(() => EditLogic())],
    ),
    //分享页路由
    MoodiaryGetPage(
      name: AppRoutes.sharePage,
      page: () => const SharePage(),
      binds: [Bind.lazyPut(() => ShareLogic())],
    ),
    //字体页路由
    MoodiaryGetPage(
      name: AppRoutes.fontPage,
      page: () => const FontPage(),
      binds: [Bind.lazyPut(() => FontLogic())],
    ),
    //实验室路由
    MoodiaryGetPage(
      name: AppRoutes.laboratoryPage,
      page: () => const LaboratoryPage(),
      binds: [Bind.lazyPut(() => LaboratoryLogic())],
    ),
    //画画路由
    MoodiaryGetPage(
      name: AppRoutes.drawPage,
      page: () => const DrawPage(),
      binds: [Bind.lazyPut(() => DrawLogic())],
    ),
    //隐私政策
    MoodiaryGetPage(
      name: AppRoutes.privacyPage,
      page: () => const PrivacyPage(),
      binds: [Bind.lazyPut(() => PrivacyLogic())],
    ),
    //用户协议
    MoodiaryGetPage(
      name: AppRoutes.agreementPage,
      page: () => const AgreementPage(),
    ),
    //锁
    MoodiaryGetPage(
      name: AppRoutes.lockPage,
      page: () => const LockPage(),
      binds: [Bind.lazyPut(() => LockLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.userPage,
      page: () => const UserPage(),
      binds: [Bind.lazyPut(() => UserLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.categoryManagerPage,
      page: () => const CategoryManagerPage(),
      binds: [Bind.lazyPut(() => CategoryManagerLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.aboutPage,
      page: () => const AboutPage(),
      binds: [Bind.lazyPut(() => AboutLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.videoPage,
      page: () => const VideoPage(),
      binds: [Bind.lazyPut(() => VideoLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.mapPage,
      page: () => const MapPage(),
      binds: [Bind.lazyPut(() => MapLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.diarySettingPage,
      page: () => const DiarySettingPage(),
      binds: [Bind.lazyPut(() => DiarySettingLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.backupSyncPage,
      page: () => const BackupSyncPage(),
      binds: [Bind.lazyPut(() => BackupSyncLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.assistantPage,
      page: () => const AssistantPage(),
      binds: [Bind.lazyPut(() => AssistantLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.sponsorPage,
      page: () => const SponsorPage(),
      binds: [Bind.lazyPut(() => SponsorLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.webViewPage,
      page: () => const WebViewPage(),
      binds: [Bind.lazyPut(() => WebViewLogic())],
    ),
  ];
}

class MoodiaryGetPage extends GetPage {
  MoodiaryGetPage({
    required super.name,
    List<Bind> binds = const <Bind>[],
    required Widget Function() page,
  }) : super(
         curve: Curves.linear,
         page: () {
           final body = PageAdaptiveBackground(
             isHome: name == AppRoutes.homePage,
             child: page(),
           );
           if (Platform.isAndroid || Platform.isIOS) {
             return body;
           } else {
             return Column(
               children: [const WindowsBar(), Expanded(child: body)],
             );
           }
         },
         customTransition: _MoodiaryPageTransition(),
       );
}

class _MoodiaryPageTransition implements CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final pageRoute = ModalRoute.of(context) as PageRoute;
    if (Platform.isAndroid) {
      return const FadeForwardsPageTransitionsBuilder().buildTransitions(
        pageRoute,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    if (Platform.isIOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        pageRoute,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return PageTransition(
      type: PageTransitionType.fade,
      child: child,
    ).buildTransitions(context, animation, secondaryAnimation, child);
  }
}
