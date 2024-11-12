import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/github.dart';
import 'package:mood_diary/components/update_dialog/update_dialog_logic.dart';

class UpdateDialogComponent extends StatelessWidget {
  const UpdateDialogComponent({super.key, required this.githubRelease});

  final GithubRelease githubRelease;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UpdateDialogLogic());
    // final state = Bind.find<UpdateDialogLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<UpdateDialogLogic>(
      assignId: true,
      builder: (_) {
        return AlertDialog(
          title: Wrap(
            spacing: 8.0,
            children: [
              const Text('发现新版本'),
              Chip(
                label: Text(
                  githubRelease.tagName!,
                  style: TextStyle(color: colorScheme.onTertiaryContainer),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
                backgroundColor: colorScheme.tertiaryContainer,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Get.backLegacy();
                },
                child: Text(i18n.cancel)),
            FilledButton(
              onPressed: () async {
                Get.backLegacy();
                await logic.toDownload(githubRelease);
              },
              child: const Text('前往更新'),
            ),
          ],
        );
      },
    );
  }
}
