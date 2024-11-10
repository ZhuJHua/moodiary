import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'local_send_server_logic.dart';
import 'local_send_server_state.dart';

class LocalSendServerComponent extends StatelessWidget {
  const LocalSendServerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final LocalSendServerLogic logic = Get.put(LocalSendServerLogic());
    final LocalSendServerState state = Bind.find<LocalSendServerLogic>().state;

    return GetBuilder<LocalSendServerLogic>(
      assignId: true,
      builder: (_) {
        return ListTile(
          title: const Text('服务器已启动在'),
          subtitle: Text('${state.serverIp}:${state.transferPort}'),
        );
      },
    );
  }
}
