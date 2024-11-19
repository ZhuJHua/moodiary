import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'local_send_client_logic.dart';
import 'local_send_client_state.dart';

class LocalSendClientComponent extends StatelessWidget {
  const LocalSendClientComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final LocalSendClientLogic logic = Get.put(LocalSendClientLogic());
    final LocalSendClientState state = Bind.find<LocalSendClientLogic>().state;

    Widget buildSend() {
      if (state.isFindingServer) {
        return ListTile(
          title: const Text('查找服务器'),
          subtitle: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(2.0),
          ),
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
          title: Text(state.serverName!),
          subtitle: Text(state.serverIp!),
          trailing: FilledButton(
            onPressed: () async {
              await logic.sendDiaryList();
            },
            child: const FaIcon(FontAwesomeIcons.solidPaperPlane),
          ),
        );
      }
    }

    Widget buildProgress() {
      return Obx(() {
        return state.isSending.value
            ? ListTile(
                title: Obx(() {
                  return LinearProgressIndicator(
                    value: state.progress.value,
                    borderRadius: BorderRadius.circular(2.0),
                  );
                }),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(() {
                      return Text('${state.sendCount.value} / ${state.diaryToSend.length}');
                    }),
                    Obx(() {
                      var speed = Utils().fileUtil.bytesToUnits(state.speed.value.toInt());
                      return Text('${speed['size']}${speed['unit']}/s');
                    }),
                  ],
                ),
              )
            : const SizedBox.shrink();
      });
    }

    Widget buildSelect() {
      return Obx(() {
        return ListTile(
          title: const Text('选择你要传输的日记'),
          subtitle: Text('已选择 ${state.diaryToSend.length}'),
          trailing: FilledButton(
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    useSafeArea: true,
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Wrap(
                          spacing: 8.0,
                          children: [
                            ActionChip(
                              label: const Text('一天内'),
                              onPressed: () async {
                                await logic.setDiary(const Duration(days: 1));
                              },
                            ),
                            ActionChip(
                              label: const Text('一周内'),
                              onPressed: () async {
                                await logic.setDiary(const Duration(days: 7));
                              },
                            ),
                            ActionChip(
                              label: const Text('一个月内'),
                              onPressed: () async {
                                await logic.setDiary(const Duration(days: 31));
                              },
                            ),
                            ActionChip(
                              label: const Text('三个月'),
                              onPressed: () async {
                                await logic.setDiary(const Duration(days: 31));
                              },
                            ),
                            ActionChip(
                              label: const Text('全部'),
                              onPressed: () async {
                                await logic.setAllDiary();
                              },
                            ),
                          ],
                        ),
                      );
                    });
              },
              child: const FaIcon(FontAwesomeIcons.fileCirclePlus)),
        );
      });
    }

    return GetBuilder<LocalSendClientLogic>(
      assignId: true,
      builder: (_) {
        return Column(
          children: [buildSelect(), buildSend(), buildProgress()],
        );
      },
    );
  }
}
