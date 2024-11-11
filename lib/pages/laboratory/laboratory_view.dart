import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/utils.dart';

import 'laboratory_logic.dart';

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LaboratoryLogic>();
    // final state = Bind.find<LaboratoryLogic>().state;
    final i18n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('实验室'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('腾讯云密钥'),
            isThreeLine: true,
            subtitle: SelectionArea(
                child: Text(
                    'ID:${Utils().prefUtil.getValue<String>('tencentId') ?? ''}\nKey:${Utils().prefUtil.getValue<String>('tencentKey') ?? ''}')),
            trailing: IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                maxLines: 1,
                                controller: logic.idTextEditingController,
                                decoration: const InputDecoration(
                                  labelText: 'ID',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(
                                height: 8.0,
                              ),
                              TextField(
                                maxLines: 1,
                                controller: logic.keyTextEditingController,
                                decoration: const InputDecoration(
                                  labelText: 'KEY',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  Get.backLegacy();
                                },
                                child: Text(i18n.cancel)),
                            TextButton(
                                onPressed: () {
                                  logic.setTencentID();
                                },
                                child: Text(i18n.ok))
                          ],
                        );
                      });
                },
                icon: const FaIcon(FontAwesomeIcons.wrench)),
          ),
          ListTile(
            title: const Text('和风天气密钥'),
            subtitle: SelectionArea(child: Text(Utils().prefUtil.getValue<String>('qweatherKey') ?? '')),
            trailing: IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          content: TextField(
                            maxLines: 1,
                            controller: logic.qweatherTextEditingController,
                            decoration: const InputDecoration(
                              labelText: 'Key',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  Get.backLegacy();
                                },
                                child: Text(i18n.cancel)),
                            TextButton(
                                onPressed: () {
                                  logic.setQweatherKey();
                                },
                                child: Text(i18n.ok))
                          ],
                        );
                      });
                },
                icon: const FaIcon(FontAwesomeIcons.wrench)),
          ),
          ListTile(
            title: const Text('天地图密钥'),
            subtitle: SelectionArea(child: Text(Utils().prefUtil.getValue<String>('tiandituKey') ?? '')),
            trailing: IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          content: TextField(
                            maxLines: 1,
                            controller: logic.tiandituTextEditingController,
                            decoration: const InputDecoration(
                              labelText: 'Key',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  Get.backLegacy();
                                },
                                child: Text(i18n.cancel)),
                            TextButton(
                                onPressed: () {
                                  logic.setTiandituKey();
                                },
                                child: Text(i18n.ok))
                          ],
                        );
                      });
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
      ),
    );
  }
}
