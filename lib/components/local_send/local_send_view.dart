import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:moodiary/components/local_send/local_send_client/local_send_client_view.dart';
import 'package:moodiary/components/local_send/local_send_server/local_send_server_view.dart';
import 'package:moodiary/main.dart';
import 'package:refreshed/refreshed.dart';

import 'local_send_logic.dart';
import 'local_send_state.dart';

class LocalSendComponent extends StatelessWidget {
  final bool isDashboard;

  const LocalSendComponent({super.key, this.isDashboard = false});

  @override
  Widget build(BuildContext context) {
    final LocalSendLogic logic = Get.put(LocalSendLogic());
    final LocalSendState state = Bind.find<LocalSendLogic>().state;

    Widget buildWifiInfo() {
      return GetBuilder<LocalSendLogic>(
          id: 'WifiInfo',
          builder: (_) {
            return Wrap(
              spacing: 8.0,
              children: [
                ActionChip(
                  onPressed: () {
                    logic.getWifiInfo();
                  },
                  label: Text('IP: ${state.deviceIpAddress}'),
                ),
                ActionChip(
                  onPressed: () async {
                    final res = await showTextInputDialog(
                        context: context,
                        title: l10n.lanTransferChangeScanPort,
                        message: l10n.lanTransferChangePortDes,
                        textFields: [
                          DialogTextField(
                            hintText: l10n.scanPort,
                            initialText: state.scanPort.value.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            validator: (value) {
                              if (value != null) {
                                final port = int.tryParse(value);
                                if (port != null &&
                                    port >= 49152 &&
                                    port <= 65535) {
                                  return null;
                                }
                                return l10n.lanTransferChangePortError1;
                              }
                              return l10n.lanTransferChangePortError2;
                            },
                          ),
                        ]);
                    if (res != null) {
                      logic.changeScanPort(int.parse(res.first));
                    }
                  },
                  label: Obx(() {
                    return Text('${l10n.scanPort}: ${state.scanPort.value}');
                  }),
                ),
                ActionChip(
                  onPressed: () async {
                    final res = await showTextInputDialog(
                        context: context,
                        title: l10n.lanTransferChangeTransferPort,
                        message: l10n.lanTransferChangePortDes,
                        textFields: [
                          DialogTextField(
                            hintText: l10n.transferPort,
                            initialText: state.transferPort.value.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            validator: (value) {
                              if (value != null) {
                                final port = int.tryParse(value);
                                if (port != null &&
                                    port >= 49152 &&
                                    port <= 65535) {
                                  return null;
                                }
                                return l10n.lanTransferChangePortError1;
                              }
                              return l10n.lanTransferChangePortError2;
                            },
                          ),
                        ]);
                    if (res != null) {
                      logic.changeTransferPort(int.parse(res.first));
                    }
                  },
                  label: Obx(() {
                    return Text(
                        '${l10n.transferPort}: ${state.transferPort.value}');
                  }),
                ),
              ],
            );
          });
    }

    Widget buildOption() {
      return Row(
        spacing: 8.0,
        children: [
          Expanded(
            child: GetBuilder<LocalSendLogic>(
                id: 'SegmentButton',
                builder: (_) {
                  return SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'send',
                        icon: const Icon(Icons.send_rounded),
                        label: Text(l10n.lanTransferSend),
                      ),
                      ButtonSegment(
                        value: 'receive',
                        icon: const Icon(Icons.move_to_inbox_rounded),
                        label: Text(l10n.lanTransferReceive),
                      ),
                    ],
                    selectedIcon: const Icon(Icons.check_circle_rounded),
                    selected: {state.type},
                    onSelectionChanged: (newSelection) {
                      logic.changeType(newSelection.first);
                    },
                  );
                }),
          ),
          TextButton.icon(
            onPressed: logic.showInfo,
            icon: const Icon(Icons.info),
            label: Text(l10n.more),
          ),
        ],
      );
    }

    Widget buildDashboard() {
      return GetBuilder<LocalSendLogic>(
        assignId: true,
        builder: (_) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              buildOption(),
              GetBuilder<LocalSendLogic>(
                  id: 'Info',
                  builder: (_) {
                    return Visibility(
                      visible: state.showInfo,
                      child: buildWifiInfo(),
                    );
                  }),
              GetBuilder<LocalSendLogic>(
                  id: 'Panel',
                  builder: (_) {
                    return state.type == 'send'
                        ? const LocalSendClientComponent()
                        : const LocalSendServerComponent();
                  }),
            ],
          );
        },
      );
    }

    Widget buildCommon() {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 8.0,
          children: [
            buildOption(),
            GetBuilder<LocalSendLogic>(
                id: 'Info',
                builder: (_) {
                  return Visibility(
                    visible: state.showInfo,
                    child: buildWifiInfo(),
                  );
                }),
            GetBuilder<LocalSendLogic>(
                id: 'Panel',
                builder: (_) {
                  return state.type == 'send'
                      ? const LocalSendClientComponent()
                      : const LocalSendServerComponent();
                }),
          ],
        ),
      );
    }

    return isDashboard
        ? buildDashboard()
        : ExpansionTile(
            leading: const Icon(Icons.wifi_tethering_rounded),
            title: Text(l10n.backupSyncLANTransfer),
            children: [buildCommon()],
          );
  }
}
