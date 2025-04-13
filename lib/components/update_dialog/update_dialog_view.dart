import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/common/models/github.dart';
import 'package:moodiary/components/update_dialog/update_dialog_logic.dart';
import 'package:moodiary/l10n/l10n.dart';

class UpdateDialogComponent extends StatelessWidget {
  const UpdateDialogComponent({super.key, required this.githubRelease});

  final GithubRelease githubRelease;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UpdateDialogLogic());

    return GetBuilder<UpdateDialogLogic>(
      assignId: true,
      builder: (_) {
        return AlertDialog(
          title: Wrap(
            spacing: 8.0,
            children: [
              Text(context.l10n.updateFound),
              Chip(
                label: Text(
                  githubRelease.tagName!,
                  style: TextStyle(
                    color: context.theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
                backgroundColor: context.theme.colorScheme.tertiaryContainer,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await logic.toDownload(githubRelease);
              },
              child: Text(context.l10n.updateToGoNow),
            ),
          ],
        );
      },
    );
  }
}
