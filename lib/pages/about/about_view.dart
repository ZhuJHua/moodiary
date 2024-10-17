import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';

import 'about_logic.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AboutLogic>();
    final state = Bind.find<AboutLogic>().state;

    final colorScheme = Theme.of(context).colorScheme;
    final i18n = AppLocalizations.of(context)!;

    Widget buildLogoTitle() {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16.0,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(40.0)),
              child: Image.asset(
                'assets/icon/icon.png',
                height: 80.0,
                width: 80.0,
              ),
            ),
            Column(
              spacing: 4.0,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  return Text(state.appName.value);
                }),
                Obx(() {
                  return Text('Version: ${state.appVersion.value}');
                })
              ],
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
          buildLogoTitle(),
          Card.filled(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: ListTile.divideTiles(tiles: [
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
              ], context: context)
                  .toList(),
            ),
          )
        ],
      ),
    );
  }
}
