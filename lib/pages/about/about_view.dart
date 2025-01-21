import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary/components/base/button.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/utils/update_util.dart';
import 'package:refreshed/refreshed.dart';

import 'about_logic.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AboutLogic>();
    final state = Bind.find<AboutLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    Widget buildLogoTitle() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            colorScheme.brightness == Brightness.light
                ? 'assets/icon/light/light_foreground.png'
                : 'assets/icon/dark/dark_foreground.png',
            color: colorScheme.onSurface,
            height: 160.0,
            width: 160.0,
          ),
          Column(
            spacing: 16.0,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.appName,
                style: textStyle.titleLarge
                    ?.copyWith(color: colorScheme.onSurface),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.appVersion,
                    style: textStyle.labelSmall
                        ?.copyWith(color: colorScheme.primary),
                  ),
                  const SizedBox(
                    height: 10,
                    child: VerticalDivider(
                      thickness: 2,
                    ),
                  ),
                  Text(
                    state.systemVersion,
                    style: textStyle.labelSmall
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        leading: const PageBackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(4.0),
          children: [
            GetBuilder<AboutLogic>(builder: (_) {
              return buildLogoTitle();
            }),
            const SizedBox(height: 16.0),
            Card.outlined(
              color: colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  AdaptiveListTile(
                    leading: const Icon(Icons.update_rounded),
                    title: Text(l10n.aboutUpdate),
                    isFirst: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await UpdateUtil.checkShouldUpdate(state.appVersion,
                          handle: true);
                    },
                  ),
                  AdaptiveListTile(
                    leading: const Icon(Icons.source_rounded),
                    title: Text(l10n.aboutSource),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await logic.toSource();
                    },
                  ),
                  AdaptiveListTile(
                    leading: const Icon(Icons.file_copy_rounded),
                    title: Text(l10n.aboutUserAgreement),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      logic.toAgreement();
                    },
                  ),
                  AdaptiveListTile(
                    leading: const Icon(Icons.privacy_tip_rounded),
                    title: Text(l10n.aboutPrivacyPolicy),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      logic.toPrivacy();
                    },
                  ),
                  AdaptiveListTile(
                    leading: const Icon(Icons.bug_report_rounded),
                    title: Text(l10n.aboutBugReport),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await logic.toReportPage();
                    },
                  ),
                  AdaptiveListTile(
                    leading: const Icon(Icons.attach_money_rounded),
                    title: Text(l10n.aboutDonate),
                    isLast: true,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: logic.toSponsor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4.0,
              children: [
                const FaIcon(
                  FontAwesomeIcons.flutter,
                  size: 16,
                  color: Colors.lightBlue,
                ),
                const SizedBox(
                  height: 12,
                  child: VerticalDivider(
                    thickness: 2,
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.dartLang,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                const SizedBox(
                  height: 12,
                  child: VerticalDivider(
                    thickness: 2,
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.rust,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                const SizedBox(
                  height: 12,
                  child: VerticalDivider(
                    thickness: 2,
                  ),
                ),
                const FaIcon(
                  FontAwesomeIcons.solidHeart,
                  size: 16,
                  color: Colors.pinkAccent,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
