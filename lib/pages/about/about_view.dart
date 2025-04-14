import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/base/expand_tap_area.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/components/base/tile/setting_tile.dart';
import 'package:moodiary/gen/assets.gen.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/utils/update_util.dart';

import 'about_logic.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AboutLogic>();
    final state = Bind.find<AboutLogic>().state;

    Widget buildLogoTitle() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            context.isDarkMode
                ? Assets.icon.dark.darkForeground.path
                : Assets.icon.light.lightForeground.path,
            color: context.theme.colorScheme.onSurface,
            height: 160.0,
            width: 160.0,
          ),
          Column(
            spacing: 16.0,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: logic.playConfetti,
                child: AnimatedBuilder(
                  animation: logic.animation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: logic.animation.value,
                      child: child,
                    );
                  },
                  child: Obx(() {
                    return AnimatedText(
                      state.appName,
                      style: context.textTheme.titleLarge?.copyWith(
                        color: context.theme.colorScheme.onSurface,
                      ),
                      isFetching: state.isFetching.value,
                    );
                  }),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(() {
                    return AnimatedText(
                      state.appVersion,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.theme.colorScheme.primary,
                      ),
                      isFetching: state.isFetching.value,
                    );
                  }),
                  const SizedBox(
                    height: 10,
                    child: VerticalDivider(thickness: 2),
                  ),
                  Obx(() {
                    return AnimatedText(
                      state.systemVersion,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.theme.colorScheme.onSurface,
                      ),
                      isFetching: state.isFetching.value,
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      );
    }

    Widget buildInfo() {
      return Column(
        spacing: 16.0,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4.0,
            children: [
              const FaIcon(
                FontAwesomeIcons.flutter,
                size: 16,
                color: Colors.lightBlue,
              ),
              const SizedBox(height: 12, child: VerticalDivider(thickness: 2)),
              FaIcon(
                FontAwesomeIcons.dartLang,
                size: 16,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
              const SizedBox(height: 12, child: VerticalDivider(thickness: 2)),
              FaIcon(
                FontAwesomeIcons.rust,
                size: 16,
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.8,
                ),
              ),
              const SizedBox(height: 12, child: VerticalDivider(thickness: 2)),
              const FaIcon(
                FontAwesomeIcons.solidHeart,
                size: 16,
                color: Colors.pinkAccent,
              ),
            ],
          ),
          ExpandTapWidget(
            tapPadding: const EdgeInsets.all(4.0),
            onTap: logic.toIcp,
            child: Text(
              '赣ICP备2022010939号-4A',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.aboutTitle),
            leading: const PageBackButton(),
          ),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                spacing: 32.0,
                children: [
                  buildLogoTitle(),
                  Card.outlined(
                    color: context.theme.colorScheme.surfaceContainerLow,
                    child: Column(
                      children: [
                        AdaptiveListTile(
                          leading: const Icon(Icons.update_rounded),
                          title: Text(context.l10n.aboutUpdate),
                          isFirst: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await UpdateUtil.checkShouldUpdate(
                              state.appVersion,
                              handle: true,
                            );
                          },
                        ),
                        AdaptiveListTile(
                          leading: const Icon(Icons.source_rounded),
                          title: Text(context.l10n.aboutSource),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await logic.toSource();
                          },
                        ),
                        AdaptiveListTile(
                          leading: const Icon(Icons.file_copy_rounded),
                          title: Text(context.l10n.aboutUserAgreement),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            logic.toAgreement();
                          },
                        ),
                        AdaptiveListTile(
                          leading: const Icon(Icons.privacy_tip_rounded),
                          title: Text(context.l10n.aboutPrivacyPolicy),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            logic.toPrivacy();
                          },
                        ),
                        AdaptiveListTile(
                          leading: const Icon(Icons.bug_report_rounded),
                          title: Text(context.l10n.aboutBugReport),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await logic.toReportPage();
                          },
                        ),
                        AdaptiveListTile(
                          leading: const Icon(Icons.attach_money_rounded),
                          title: Text(context.l10n.aboutDonate),
                          isLast: true,
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: logic.toSponsor,
                        ),
                      ],
                    ),
                  ),
                  buildInfo(),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: logic.confettiController,
            blastDirectionality: BlastDirectionality.directional,
            blastDirection: pi / 2,
            emissionFrequency: 0.1,
            colors: const [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.cyan,
              Colors.blue,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}
