import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/components/local_send/local_send_client/local_send_client_view.dart';
import 'package:mood_diary/components/local_send/local_send_server/local_send_server_view.dart';

import 'local_send_logic.dart';
import 'local_send_state.dart';

class LocalSendComponent extends StatelessWidget {
  const LocalSendComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final LocalSendLogic logic = Get.put(LocalSendLogic());
    final LocalSendState state = Bind.find<LocalSendLogic>().state;

    final textStyle = Theme.of(context).textTheme;

    Widget buildWifiInfo() {
      return Column(
        spacing: 8.0,
        children: [
          Text(
            '请检查以下信息，确保两台设备在同一局域网下',
            style: textStyle.titleSmall,
          ),
          GetBuilder<LocalSendLogic>(
              id: 'WifiInfo',
              builder: (_) {
                return Wrap(
                  spacing: 8.0,
                  children: [
                    ActionChip(
                      onPressed: () {
                        logic.getWifiInfo();
                      },
                      label: Text('SSID : ${state.wifiSSID}'),
                    ),
                    ActionChip(
                      onPressed: () {
                        logic.getWifiInfo();
                      },
                      label: Text('IP : ${state.deviceIpAddress}'),
                    ),
                  ],
                );
              }),
        ],
      );
    }

    Widget buildPortInfo() {
      return Column(
        spacing: 8.0,
        children: [
          Text(
            '如果您不知道这是什么，请不要修改',
            style: textStyle.titleSmall,
          ),
          Wrap(
            spacing: 8.0,
            children: [
              ActionChip(
                onPressed: () {},
                label: Text('扫描端口: ${state.scanPort}'),
              ),
              ActionChip(
                onPressed: () {},
                label: Text('传输端口: ${state.transferPort}'),
              ),
            ],
          ),
        ],
      );
    }

    return GetBuilder<LocalSendLogic>(
      assignId: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 8.0,
            children: [
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.spaceEvenly,
                children: [buildWifiInfo(), buildPortInfo()],
              ),
              GetBuilder<LocalSendLogic>(
                  id: 'SegmentButton',
                  builder: (_) {
                    return SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'send',
                          icon: Icon(Icons.send),
                          label: Text('发送'),
                        ),
                        ButtonSegment(
                          value: 'receive',
                          icon: Icon(Icons.move_to_inbox_rounded),
                          label: Text('接收'),
                        ),
                      ],
                      selected: {state.type},
                      onSelectionChanged: (newSelection) {
                        logic.changeType(newSelection.first);
                      },
                    );
                  }),
              GetBuilder<LocalSendLogic>(
                  id: 'Panel',
                  builder: (_) {
                    return state.type == 'send' ? const LocalSendClientComponent() : const LocalSendServerComponent();
                  }),
            ],
          ),
        );
      },
    );
  }
}
