import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/local_send/local_send_view.dart';
import 'package:mood_diary/components/web_dav/web_dav_view.dart';

import 'backup_sync_logic.dart';
import 'backup_sync_state.dart';

class BackupSyncPage extends StatelessWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final BackupSyncLogic logic = Get.put(BackupSyncLogic());
    final BackupSyncState state = Bind.find<BackupSyncLogic>().state;
    final i18n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与同步'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(i18n.settingExport),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(i18n.settingExportDialogTitle),
                      content: Text(i18n.settingExportDialogContent),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Get.backLegacy();
                            },
                            child: Text(i18n.cancel)),
                        TextButton(
                            onPressed: () async {
                              await logic.exportFile();
                            },
                            child: Text(i18n.ok))
                      ],
                    );
                  });
            },
            trailing: const Icon(Icons.chevron_right),
            leading: const Icon(Icons.file_upload_outlined),
          ),
          ListTile(
            title: Text(i18n.settingImport),
            subtitle: Text(i18n.settingImportDes),
            onTap: () async {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(i18n.settingImportDialogTitle),
                      content: Text(i18n.settingImportDialogContent),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Get.backLegacy();
                            },
                            child: Text(i18n.cancel)),
                        TextButton(
                            onPressed: () async {
                              logic.import();
                            },
                            child: Text(i18n.settingImportSelectFile))
                      ],
                    );
                  });
            },
            trailing: const Icon(Icons.chevron_right),
            leading: const Icon(Icons.file_download_outlined),
          ),
          const LocalSendComponent(),
          const WebDavComponent()
        ],
      ),
    );
  }
}
