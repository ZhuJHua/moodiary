import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/update_util.dart';

import 'about_logic.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AboutLogic>();
    final state = Bind.find<AboutLogic>().state;

    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    final textStyle = Theme.of(context).textTheme;

    Widget buildLogoTitle() {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              colorScheme.brightness == Brightness.light
                  ? 'assets/icon/light/light_foreground.png'
                  : 'assets/icon/dark/dark_foreground.png',
              height: 160.0,
              width: 160.0,
            ),
            Column(
              spacing: 4.0,
              mainAxisSize: MainAxisSize.min,
              children: [Text(state.appName), Text('Version: ${state.appVersion}')],
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.aboutTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(4.0),
        children: [
          GetBuilder<AboutLogic>(builder: (_) {
            return buildLogoTitle();
          }),
          Card.outlined(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                GetBuilder<AboutLogic>(builder: (_) {
                  return ListTile(
                    leading: const Icon(Icons.update),
                    title: Text(i18n.aboutUpdate),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await UpdateUtil.checkShouldUpdate(state.appVersion, handle: true);
                    },
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.source_outlined),
                  title: Text(i18n.aboutSource),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await logic.toSource();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_copy_outlined),
                  title: Text(i18n.aboutUserAgreement),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toAgreement();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: Text(i18n.aboutPrivacyPolicy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    logic.toPrivacy();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(i18n.aboutBugReport),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await logic.toReportPage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
