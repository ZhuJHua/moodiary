import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:refreshed/refreshed.dart';

import 'local_send_server_logic.dart';

class LocalSendServerComponent extends StatelessWidget {
  const LocalSendServerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final LocalSendServerLogic logic = Get.put(LocalSendServerLogic());

    return GetBuilder<LocalSendServerLogic>(
      assignId: true,
      builder: (_) {
        return Obx(() {
          return Column(
            children: [
              const ListTile(
                leading: FaIcon(FontAwesomeIcons.solidLightbulb),
                title: Text('接收过程中不要操作'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.server),
                title: Text(logic.serverName),
                subtitle: const Text('服务器已启动'),
              ),
              if (logic.receiveCount.value > 0) ...[
                ListTile(
                  title: const Text('已接收'),
                  subtitle: Obx(() {
                    return Text(
                      logic.receiveCount.value.toString(),
                    );
                  }),
                )
              ]
            ],
          );
        });
      },
    );
  }
}
