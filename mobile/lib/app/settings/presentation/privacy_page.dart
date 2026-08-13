import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:mui/mui.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  static const _text = '''
Moodiary 是一款离线优先的日记应用，您的内容默认仅保存在本机。

## 数据收集
本应用不主动采集您的任何个人信息。所有日记、分类、标签、媒体均保存在本地数据库与文件系统中。

## 数据同步
当且仅当您主动配置 WebDAV / S3 等备份目的地时，对应数据才会上传至您指定的第三方服务。Moodiary 不会将您的数据上传至 Moodiary 团队自有服务器。

## 第三方服务
如果您启用了天气、定位、AI 助手等可选功能，相关请求会按您填写的 API key 直接发往对应服务商（和风天气、腾讯位置、混元等）。请知悉对应服务商的隐私政策。

## 权限
- 存储/相册：保存日记媒体
- 位置：可选，仅在请求天气时使用
- 麦克风：可选，录音条
- 相机：可选，拍照

## 联系
如有疑问请发起 issue：github.com/ZhuJHua/moodiary
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      body: const Markdown(data: _text, selectable: true, padding: .all(16)),
    );
  }
}
