import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:mood_diary/components/local_send/local_send_client/local_send_client_view.dart';
import 'package:mood_diary/components/local_send/local_send_server/local_send_server_view.dart';
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
                  label: Text('IP : ${state.deviceIpAddress}'),
                ),
                ActionChip(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                        context: context,
                        title: '修改扫描端口',
                        message: '请确保两台设备端口一致',
                        textFields: [
                          DialogTextField(
                            hintText: '端口号',
                            initialText: state.scanPort.value.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            validator: (value) {
                              if (value != null) {
                                var port = int.tryParse(value);
                                if (port != null &&
                                    port >= 49152 &&
                                    port <= 65535) {
                                  return null;
                                }
                                return '请输入临时端口号(49152-65535)';
                              }
                              return '请输入端口号';
                            },
                          ),
                        ]);
                    if (res != null) {
                      logic.changeScanPort(int.parse(res.first));
                    }
                  },
                  label: Obx(() {
                    return Text('扫描端口: ${state.scanPort.value}');
                  }),
                ),
                ActionChip(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                        context: context,
                        title: '修改传输端口',
                        message: '请确保两台设备端口一致',
                        textFields: [
                          DialogTextField(
                            hintText: '端口号',
                            initialText: state.transferPort.value.toString(),
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                            validator: (value) {
                              if (value != null) {
                                var port = int.tryParse(value);
                                if (port != null &&
                                    port >= 49152 &&
                                    port <= 65535) {
                                  return null;
                                }
                                return '请输入临时端口号(49152-65535)';
                              }
                              return '请输入端口号';
                            },
                          ),
                        ]);
                    if (res != null) {
                      logic.changeTransferPort(int.parse(res.first));
                    }
                  },
                  label: Obx(() {
                    return Text('传输端口: ${state.transferPort.value}');
                  }),
                ),
              ],
            );
          });
    }

    // Widget buildPortInfo() {
    //   return Column(
    //     spacing: 8.0,
    //     children: [
    //       Text(
    //         '如果您不知道这是什么，请不要修改',
    //         style: textStyle.titleSmall,
    //       ),
    //       Wrap(
    //         spacing: 8.0,
    //         children: [
    //           ActionChip(
    //             onPressed: () {},
    //             label: Text('扫描端口: ${state.scanPort}'),
    //           ),
    //           ActionChip(
    //             onPressed: () {},
    //             label: Text('传输端口: ${state.transferPort}'),
    //           ),
    //         ],
    //       ),
    //     ],
    //   );
    // }

    Widget buildOption() {
      return Row(
        spacing: 8.0,
        children: [
          Expanded(
            child: GetBuilder<LocalSendLogic>(
                id: 'SegmentButton',
                builder: (_) {
                  return SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'send',
                        icon: Icon(Icons.send_rounded),
                        label: Text('发送'),
                      ),
                      ButtonSegment(
                        value: 'receive',
                        icon: Icon(Icons.move_to_inbox_rounded),
                        label: Text('接收'),
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
            label: const Text('更多'),
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
            title: const Text('局域网传输'),
            children: [buildCommon()],
          );
  }
}
