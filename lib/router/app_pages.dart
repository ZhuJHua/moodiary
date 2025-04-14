import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
import 'package:page_transition/page_transition.dart';

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
      binds: [Bind.lazyPut(fenix: true, () => StartLogic())],
    ),
    //首页路由
    MoodiaryGetPage(
      name: AppRoutes.homePage,
      page: () => const HomePage(),
      binds: [Bind.lazyPut(fenix: true, () => HomeLogic())],
    ),
    //分析
    MoodiaryGetPage(
      name: AppRoutes.analysePage,
      page: () => const AnalysePage(),
      binds: [Bind.lazyPut(fenix: true, () => AnalyseLogic())],
    ),
    //日记页路由
    MoodiaryGetPage(name: AppRoutes.diaryPage, page: () => DiaryDetailsPage()),
    //回收站
    MoodiaryGetPage(
      name: AppRoutes.recyclePage,
      page: () => const RecyclePage(),
      binds: [Bind.lazyPut(fenix: true, () => RecycleLogic())],
    ),
    //登录路由
    MoodiaryGetPage(
      name: AppRoutes.loginPage,
      page: () => const LoginPage(),
      binds: [Bind.lazyPut(fenix: true, () => LoginLogic())],
    ),
    //新增/编辑日记路由
    MoodiaryGetPage(
      name: AppRoutes.editPage,
      page: () => const EditPage(),
      binds: [Bind.lazyPut(fenix: true, () => EditLogic())],
    ),
    //分享页路由
    MoodiaryGetPage(
      name: AppRoutes.sharePage,
      page: () => const SharePage(),
      binds: [Bind.lazyPut(fenix: true, () => ShareLogic())],
    ),
    //字体页路由
    MoodiaryGetPage(
      name: AppRoutes.fontPage,
      page: () => const FontPage(),
      binds: [Bind.lazyPut(fenix: true, () => FontLogic())],
    ),
    //实验室路由
    MoodiaryGetPage(
      name: AppRoutes.laboratoryPage,
      page: () => const LaboratoryPage(),
      binds: [Bind.lazyPut(fenix: true, () => LaboratoryLogic())],
    ),
    //画画路由
    MoodiaryGetPage(
      name: AppRoutes.drawPage,
      page: () => const DrawPage(),
      binds: [Bind.lazyPut(fenix: true, () => DrawLogic())],
    ),
    //隐私政策
    MoodiaryGetPage(
      name: AppRoutes.privacyPage,
      page: () => const PrivacyPage(),
      binds: [Bind.lazyPut(fenix: true, () => PrivacyLogic())],
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
      binds: [Bind.lazyPut(fenix: true, () => LockLogic())],
      useFade: true,
    ),
    MoodiaryGetPage(
      name: AppRoutes.userPage,
      page: () => const UserPage(),
      binds: [Bind.lazyPut(fenix: true, () => UserLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.categoryManagerPage,
      page: () => const CategoryManagerPage(),
      binds: [Bind.lazyPut(fenix: true, () => CategoryManagerLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.aboutPage,
      page: () => const AboutPage(),
      binds: [Bind.lazyPut(fenix: true, () => AboutLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.mapPage,
      page: () => const MapPage(),
      binds: [Bind.lazyPut(fenix: true, () => MapLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.diarySettingPage,
      page: () => const DiarySettingPage(),
      binds: [Bind.lazyPut(fenix: true, () => DiarySettingLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.backupSyncPage,
      page: () => const BackupSyncPage(),
      binds: [Bind.lazyPut(fenix: true, () => BackupSyncLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.assistantPage,
      page: () => const AssistantPage(),
      binds: [Bind.lazyPut(fenix: true, () => AssistantLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.sponsorPage,
      page: () => const SponsorPage(),
      binds: [Bind.lazyPut(fenix: true, () => SponsorLogic())],
    ),
    MoodiaryGetPage(
      name: AppRoutes.webViewPage,
      page: () => const WebViewPage(),
      binds: [Bind.lazyPut(fenix: true, () => WebViewLogic())],
    ),
  ];
}

class MoodiaryGetPage extends GetPage {
  MoodiaryGetPage({
    required super.name,
    List<Bind> binds = const <Bind>[],
    required Widget Function() page,
    bool? useFade = false,
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
         customTransition: _MoodiaryPageTransition(useFade: useFade),
       );
}

class MoodiaryFadeInPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  MoodiaryFadeInPageRoute({
    required this.builder,
    super.settings,
    super.requestFocus,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  }) {
    assert(opaque);
  }

  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) {
    final body = PageAdaptiveBackground(
      isHome: settings.name == AppRoutes.homePage,
      child: builder(context),
    );
    if (Platform.isAndroid || Platform.isIOS) {
      return body;
    } else {
      return Column(children: [const WindowsBar(), Expanded(child: body)]);
    }
  }

  @override
  final bool maintainState;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}

class _MoodiaryPageTransition implements CustomTransition {
  final bool? useFade;

  _MoodiaryPageTransition({required this.useFade});

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    late final pageRoute = ModalRoute.of(context) as PageRoute;
    if (useFade == true) {
      return PageTransition(
        type: PageTransitionType.fade,
        child: child,
      ).buildTransitions(context, animation, secondaryAnimation, child);
    }
    if (Platform.isAndroid) {
      if (pageRoute.popGestureInProgress) {
        return const PredictiveBackPageTransitionsBuilder().buildTransitions(
          pageRoute,
          context,
          animation,
          secondaryAnimation,
          child,
        );
      }
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
