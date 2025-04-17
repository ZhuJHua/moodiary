import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/tile/qr_tile.dart';
import 'package:moodiary/l10n/l10n.dart';
import 'package:moodiary/persistence/pref.dart';
import 'package:moodiary/utils/notice_util.dart';

import 'laboratory_logic.dart';

class LaboratoryPage extends StatelessWidget {
  const LaboratoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<LaboratoryLogic>();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingLab)),
      body: GetBuilder<LaboratoryLogic>(
        builder: (_) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            children: [
              QrInputTile(
                title: '${context.l10n.labTencentCloud} ID',
                value: PrefUtil.getValue<String>('tencentId') ?? '',
                prefix: 'tencentId',
                onValue: (value) async {
                  final res = await logic.setTencentID(id: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labTencentCloud} Key',
                value: PrefUtil.getValue<String>('tencentKey') ?? '',
                prefix: 'tencentKey',
                onValue: (value) async {
                  final res = await logic.setTencentKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labQweather} Key',
                value: PrefUtil.getValue<String>('qweatherKey') ?? '',
                prefix: 'qweatherKey',
                onValue: (value) async {
                  final res = await logic.setQweatherKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              QrInputTile(
                title: '${context.l10n.labTianditu} Key',
                value: PrefUtil.getValue<String>('tiandituKey') ?? '',
                prefix: 'tiandituKey',
                onValue: (value) async {
                  final res = await logic.setTiandituKey(key: value);
                  if (res) {
                    toast.success();
                  } else {
                    toast.error();
                  }
                },
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  logic.exportErrorLog();
                },
                title: const Text('导出日志文件'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.aesTest();
                  if (res) {
                    toast.success(message: '加密测试通过');
                  } else {
                    toast.error(message: '加密测试失败');
                  }
                },
                title: const Text('加密测试'),
              ),
              const Gap(12),
              ListTile(
                onTap: () async {
                  final res = await logic.clearImageThumbnail();
                  if (res) {
                    toast.success(message: '清理成功');
                  } else {
                    toast.error(message: '清理失败');
                  }
                },
                title: const Text('清理图片缩略图缓存'),
              ),
            ],
          );
        },
      ),
    );
  }
}
