import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';

import 'local_send_client_logic.dart';
import 'local_send_client_state.dart';

class LocalSendClientComponent extends StatelessWidget {
  const LocalSendClientComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final LocalSendClientLogic logic = Get.put(LocalSendClientLogic());
    final LocalSendClientState state = Bind.find<LocalSendClientLogic>().state;

    return GetBuilder<LocalSendClientLogic>(
      assignId: true,
      builder: (_) {
        if (state.isFindingServer) {
          return const ListTile(
            title: Text('查找服务器'),
            subtitle: LinearProgressIndicator(),
          );
        } else if (state.serverIp == null) {
          return ListTile(
            title: const Text('未找到服务器'),
            leading: const FaIcon(FontAwesomeIcons.triangleExclamation),
            trailing: FilledButton(
                onPressed: () {
                  logic.restartFindServer();
                },
                child: const FaIcon(FontAwesomeIcons.repeat)),
          );
        } else {
          return ListTile(
            title: Text(state.serverIp!),
            subtitle: Obx(() {
              return Text(
                  '${Utils().fileUtil.bytesToUnits(state.speed.value.toInt())['size']}${Utils().fileUtil.bytesToUnits(state.speed.value.toInt())['unit']}/s ${state.progress.value * 100}%');
            }),
            leading: const FaIcon(FontAwesomeIcons.server),
            trailing: FilledButton(
              onPressed: () async {
                await logic
                    .sendData((await Utils().isarUtil.getDiaryByID(fastHash('01931742-bd6c-738a-a482-cc8a398b5c0c')))!);
              },
              child: const FaIcon(FontAwesomeIcons.solidPaperPlane),
            ),
          );
        }
      },
    );
  }
}
