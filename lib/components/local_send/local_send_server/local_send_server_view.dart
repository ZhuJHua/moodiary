import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/tile/setting_tile.dart';
import 'package:moodiary/l10n/l10n.dart';

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
              AdaptiveListTile(
                leading: const FaIcon(FontAwesomeIcons.solidLightbulb),
                title: context.l10n.lanTransferReceiveDes,
              ),
              AdaptiveListTile(
                leading: const FaIcon(FontAwesomeIcons.server),
                title: logic.serverName,
                subtitle: context.l10n.lanTransferReceiveServerStart,
              ),
              if (logic.receiveCount.value > 0) ...[
                Obx(() {
                  return AdaptiveListTile(
                    title: context.l10n.lanTransferHasReceived,
                    subtitle: logic.receiveCount.value.toString(),
                  );
                }),
              ],
            ],
          );
        });
      },
    );
  }
}
