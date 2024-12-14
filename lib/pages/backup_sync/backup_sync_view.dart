import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/local_send/local_send_view.dart';
import 'package:mood_diary/components/web_dav/web_dav_view.dart';

import '../../main.dart';
import 'backup_sync_logic.dart';

class BackupSyncPage extends StatelessWidget {
  const BackupSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final BackupSyncLogic logic = Get.put(BackupSyncLogic());

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与同步'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.settingExport),
            onTap: () {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(l10n.settingExportDialogTitle),
                      content: Text(l10n.settingExportDialogContent),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Get.backLegacy();
                            },
                            child: Text(l10n.cancel)),
                        TextButton(
                            onPressed: () async {
                              await logic.exportFile();
                            },
                            child: Text(l10n.ok))
                      ],
                    );
                  });
            },
            trailing: const Icon(Icons.chevron_right),
            leading: const Icon(Icons.file_upload_outlined),
          ),
          ListTile(
            title: Text(l10n.settingImport),
            subtitle: Text(l10n.settingImportDes),
            onTap: () async {
              showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(l10n.settingImportDialogTitle),
                      content: Text(l10n.settingImportDialogContent),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Get.backLegacy();
                            },
                            child: Text(l10n.cancel)),
                        TextButton(
                            onPressed: () async {
                              logic.import();
                            },
                            child: Text(l10n.settingImportSelectFile))
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
