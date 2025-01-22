import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moodiary/main.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:refreshed/refreshed.dart';

import 'laboratory_logic.dart';

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LaboratoryLogic>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingLab),
      ),
      body: GetBuilder<LaboratoryLogic>(builder: (_) {
        return ListView(
          children: [
            ListTile(
              title: const Text('腾讯云密钥'),
              isThreeLine: true,
              subtitle: SelectionArea(
                  child: Text(
                'ID:${PrefUtil.getValue<String>('tencentId') ?? ''}\nKey:${PrefUtil.getValue<String>('tencentKey') ?? ''}',
              )),
              trailing: IconButton(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                      context: context,
                      textFields: [
                        DialogTextField(
                          hintText: 'ID',
                          initialText:
                              PrefUtil.getValue<String>('tencentId') ?? '',
                        ),
                        DialogTextField(
                          hintText: 'KEY',
                          initialText:
                              PrefUtil.getValue<String>('tencentKey') ?? '',
                        ),
                      ],
                      title: '腾讯云密钥',
                      message: '在腾讯云控制台获取密钥',
                      style: AdaptiveStyle.material,
                    );
                    if (res != null) {
                      logic.setTencentID(id: res[0], key: res[1]);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.wrench)),
            ),
            ListTile(
              title: const Text('和风天气密钥'),
              subtitle: SelectionArea(
                  child: Text(PrefUtil.getValue<String>('qweatherKey') ?? '')),
              trailing: IconButton(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                        context: context,
                        style: AdaptiveStyle.material,
                        title: '和风天气密钥',
                        message: '在和风天气控制台获取密钥',
                        textFields: [
                          DialogTextField(
                            hintText: 'KEY',
                            initialText:
                                PrefUtil.getValue<String>('qweatherKey') ?? '',
                          )
                        ]);
                    if (res != null) {
                      logic.setQweatherKey(key: res[0]);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.wrench)),
            ),
            ListTile(
              title: const Text('天地图密钥'),
              subtitle: SelectionArea(
                  child: Text(PrefUtil.getValue<String>('tiandituKey') ?? '')),
              trailing: IconButton(
                  onPressed: () async {
                    var res = await showTextInputDialog(
                        context: context,
                        textFields: [
                          DialogTextField(
                            hintText: 'KEY',
                            initialText:
                                PrefUtil.getValue<String>('tiandituKey') ?? '',
                          )
                        ],
                        title: '天地图密钥',
                        message: '在天地图控制台获取密钥',
                        style: AdaptiveStyle.material);
                    if (res != null) {
                      logic.setTiandituKey(key: res[0]);
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.wrench)),
            ),
            ListTile(
              onTap: () {
                logic.exportErrorLog();
              },
              title: const Text('导出日志文件'),
            ),
          ],
        );
      }),
    );
  }
}
