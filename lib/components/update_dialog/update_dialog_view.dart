import 'package:flutter/material.dart';
import 'package:mood_diary/common/models/github.dart';
import 'package:mood_diary/components/update_dialog/update_dialog_logic.dart';
import 'package:refreshed/refreshed.dart';

import '../../main.dart';

class UpdateDialogComponent extends StatelessWidget {
  const UpdateDialogComponent({super.key, required this.githubRelease});

  final GithubRelease githubRelease;

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UpdateDialogLogic());

    final colorScheme = Theme.of(context).colorScheme;
    return GetBuilder<UpdateDialogLogic>(
      assignId: true,
      builder: (_) {
        return AlertDialog(
          title: Wrap(
            spacing: 8.0,
            children: [
              Text(l10n.updateFound),
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
                  Navigator.pop(context);
                },
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await logic.toDownload(githubRelease);
              },
              child: Text(l10n.updateToGoNow),
            ),
          ],
        );
      },
    );
  }
}
