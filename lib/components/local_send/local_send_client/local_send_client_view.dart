import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mood_diary/components/tile/setting_tile.dart';
import 'package:mood_diary/main.dart';
import 'package:refreshed/refreshed.dart';

import '../../../utils/file_util.dart';
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
        return AdaptiveListTile(
          title: l10n.lanTransferFindingServer,
          subtitle: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(2.0),
          ),
        );
      } else if (state.serverIp == null) {
        return AdaptiveListTile(
          title: l10n.lanTransferCantFindServer,
          leading: const FaIcon(FontAwesomeIcons.triangleExclamation),
          trailing: FilledButton(
              onPressed: () {
                logic.restartFindServer();
              },
              child: const FaIcon(FontAwesomeIcons.repeat)),
        );
      } else {
        return AdaptiveListTile(
          title: state.serverName!,
          subtitle: state.serverIp!,
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
                      return Text(
                          '${state.sendCount.value} / ${state.diaryToSend.length}');
                    }),
                    Obx(() {
                      var speed =
                          FileUtil.bytesToUnits(state.speed.value.toInt());
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
        return AdaptiveListTile(
          title: l10n.lanTransferSelectDiary,
          subtitle: Text(
              '${l10n.lanTransferHasSelected} ${state.diaryToSend.length}'),
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
                                await logic.setDiary(
                                    const Duration(days: 1), context);
                              },
                            ),
                            ActionChip(
                              label: const Text('一周内'),
                              onPressed: () async {
                                await logic.setDiary(
                                    const Duration(days: 7), context);
                              },
                            ),
                            ActionChip(
                              label: const Text('一个月内'),
                              onPressed: () async {
                                await logic.setDiary(
                                    const Duration(days: 31), context);
                              },
                            ),
                            ActionChip(
                              label: const Text('三个月'),
                              onPressed: () async {
                                await logic.setDiary(
                                    const Duration(days: 31), context);
                              },
                            ),
                            ActionChip(
                              label: const Text('全部'),
                              onPressed: () async {
                                await logic.setAllDiary(context);
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
