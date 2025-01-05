import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/update_util.dart';

import '../../main.dart';
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
              RichText(
                text: TextSpan(
                  style: textStyle.labelMedium
                      ?.copyWith(color: colorScheme.onSurface),
                  children: [
                    TextSpan(
                      text: 'Version: ',
                      style: textStyle.labelSmall
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                    TextSpan(text: state.appVersion),
                    const WidgetSpan(
                        child: SizedBox(
                          height: 12,
                          child: VerticalDivider(
                            thickness: 2,
                          ),
                        ),
                        alignment: PlaceholderAlignment.middle),
                    TextSpan(
                      text: 'System: ',
                      style: textStyle.labelSmall
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                    TextSpan(text: state.systemVersion),
                  ],
                ),
              )
            ],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
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
                  GetBuilder<AboutLogic>(builder: (_) {
                    return ListTile(
                      leading: const Icon(Icons.update_rounded),
                      title: Text(l10n.aboutUpdate),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await UpdateUtil.checkShouldUpdate(state.appVersion,
                            handle: true);
                      },
                    );
                  }),
                  ListTile(
                    leading: const Icon(Icons.source_rounded),
                    title: Text(l10n.aboutSource),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await logic.toSource();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_copy_rounded),
                    title: Text(l10n.aboutUserAgreement),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      logic.toAgreement();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.security_rounded),
                    title: Text(l10n.aboutPrivacyPolicy),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      logic.toPrivacy();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report_rounded),
                    title: Text(l10n.aboutBugReport),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      await logic.toReportPage();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money_rounded),
                    title: Text(l10n.aboutDonate),
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
