import 'package:flutter/material.dart';

class AgreementPage extends StatelessWidget {
  const AgreementPage({super.key});

  static const _text = '''
# Moodiary 用户协议

感谢您使用 Moodiary。继续使用本软件即代表您同意以下条款。

## 1. 软件归属
Moodiary 是开源软件，源代码遵守 GPL-3.0 协议。

## 2. 责任声明
本软件按"现状"提供，作者不对数据丢失、设备损坏等情形承担责任。建议定期备份。

## 3. 第三方服务
若您在「实验室」内填入和风天气 / 腾讯位置 / 天地图等第三方 API key 并启用相关功能，您需自行遵守对应服务商的服务条款。

## 4. 同步与备份
当您启用 WebDAV / LocalSend 等同步方式时，请妥善保管同步服务商账号与加密密钥。

## 5. 协议变更
随版本更新，本协议可能调整。变更后您再次启动应用即视为接受新版本。

## 6. 联系
github.com/ZhuJHua/moodiary
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(_text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
