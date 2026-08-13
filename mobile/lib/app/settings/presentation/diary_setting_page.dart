import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:mui/mui.dart';

class DiarySettingPage extends ConsumerWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('日记偏好')),
      body: ListView(
        padding: const .symmetric(vertical: 8),
        children: const [
          _Section('编辑器'),
          _KvSwitchTile(kv: .firstLineIndent, title: '首行缩进'),
          _KvSwitchTile(
            kv: .autoCategory,
            title: '保存时自动归类',
            subtitle: '根据上次写作位置 / 标签推测分类',
          ),
          _KvSwitchTile(kv: .showWritingTime, title: '展示写作时长'),
          _KvSwitchTile(kv: .showWordCount, title: '展示字数统计'),
          _Section('日记展示'),
          _KvSwitchTile(kv: .diaryHeader, title: '列表卡片显示头图'),
          _KvSwitchTile(kv: .dynamicColor, title: '基于封面动态配色'),
          _Section('媒体'),
          _KvSwitchTile(
            kv: .imageOptimize,
            title: '图片优化',
            subtitle: '压缩尺寸并统一转为 WebP；关闭则保存原图',
          ),
          _Section('天气'),
          _KvSwitchTile(kv: .autoWeather, title: '保存日记时自动获取天气'),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(16, 16, 16, 4),
      child: Text(title, style: context.theme.typography.labelMedium.primary),
    );
  }
}

class _KvSwitchTile extends StatelessWidget {
  final MoodiaryKVs<bool> kv;
  final String title;
  final String? subtitle;

  const _KvSwitchTile({required this.kv, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: kv.getNotifier(),
      builder: (context, value, _) {
        return SwitchListTile(
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          value: value,
          onChanged: (v) => kv.set(v),
        );
      },
    );
  }
}
