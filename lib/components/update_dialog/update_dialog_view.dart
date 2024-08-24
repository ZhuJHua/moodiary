import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/shiply.dart';
import 'package:mood_diary/utils/channel.dart';

class UpdateDialogComponent extends StatelessWidget {
  const UpdateDialogComponent({super.key, required this.shiplyResponse});

  final ShiplyResponse shiplyResponse;

  @override
  Widget build(BuildContext context) {
    // final logic = Get.put(UpdateDialogLogic());
    // final state = Bind.find<UpdateDialogLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Wrap(
        spacing: 8.0,
        children: [
          Text(shiplyResponse.clientInfo!.title!),
          Chip(
            label: Text(
              'V${shiplyResponse.apkBasicInfo!.version!}',
              style: TextStyle(color: colorScheme.onTertiaryContainer),
            ),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide.none,
            backgroundColor: colorScheme.tertiaryContainer,
          ),
        ],
      ),
      content: Text(shiplyResponse.clientInfo!.description!),
      actions: [
        TextButton(
            onPressed: () {
              Get.backLegacy();
            },
            child: Text(i18n.cancel)),
        FilledButton(
          onPressed: () async {
            Get.backLegacy();
            await ShiplyChannel.startDownload();
          },
          child: const Text('立即更新'),
        ),
      ],
    );
  }
}
