import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/local_send/local_send_view.dart';

import 'backup_sync_logic.dart';
import 'backup_sync_state.dart';

class BackupSyncPage extends StatelessWidget {
  const BackupSyncPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BackupSyncLogic logic = Get.put(BackupSyncLogic());
    final BackupSyncState state = Bind.find<BackupSyncLogic>().state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与同步'),
      ),
      body: ListView(
        children: const [
          ExpansionTile(
            leading: Icon(Icons.wifi_tethering_rounded),
            title: Text('局域网传输'),
            children: [LocalSendComponent()],
          ),
          ExpansionTile(
            leading: Icon(Icons.backup_rounded),
            title: Text('WebDav'),
            subtitle: Text('即将支持'),
            enabled: false,
            children: [],
          )
        ],
      ),
    );
  }
}
