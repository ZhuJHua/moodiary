import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import 'local_send_server_logic.dart';
import 'local_send_server_state.dart';

class LocalSendServerComponent extends StatelessWidget {
  const LocalSendServerComponent({super.key});

  @override
  Widget build(BuildContext context) {
    //final LocalSendServerLogic logic = Get.put(LocalSendServerLogic());
    final LocalSendServerState state = Bind.find<LocalSendServerLogic>().state;

    return GetBuilder<LocalSendServerLogic>(
      assignId: true,
      builder: (_) {
        return Obx(() {
          return Column(
            children: [
              const ListTile(
                leading: FaIcon(FontAwesomeIcons.solidLightbulb),
                title: Text('在接收完成后请手动重启应用'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.server),
                title: Text(state.serverName),
                subtitle: const Text('服务器已启动'),
              ),
              if (state.receiveCount.value > 0) ...[
                ListTile(
                  title: const Text('已接收'),
                  subtitle: Obx(() {
                    return Text(
                      state.receiveCount.value.toString(),
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
