import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';

class DiarySettingPage extends ConsumerWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('日记偏好')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _Section('编辑器'),
          _KvSwitchTile(kv: MoodiaryKVs.firstLineIndent, title: '首行缩进'),
          _KvSwitchTile(
            kv: MoodiaryKVs.autoCategory,
            title: '保存时自动归类',
            subtitle: '根据上次写作位置 / 标签推测分类',
          ),
          _KvSwitchTile(kv: MoodiaryKVs.showWritingTime, title: '展示写作时长'),
          _KvSwitchTile(kv: MoodiaryKVs.showWordCount, title: '展示字数统计'),
          _Section('日记展示'),
          _KvSwitchTile(kv: MoodiaryKVs.diaryHeader, title: '列表卡片显示头图'),
          _KvSwitchTile(kv: MoodiaryKVs.dynamicColor, title: '基于封面动态配色'),
          _Section('媒体'),
          _ImageQualityTile(),
          _Section('天气'),
          _KvSwitchTile(kv: MoodiaryKVs.autoWeather, title: '保存日记时自动获取天气'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
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

class _ImageQualityTile extends StatelessWidget {
  static const _labels = {1: '原图', 2: '高清', 3: '标清'};

  const _ImageQualityTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.quality.getNotifier(),
      builder: (context, value, _) {
        final label = _labels[value] ?? '高清';
        return ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('图片质量'),
          subtitle: Text(label),
          onTap: () async {
            final selected = await showModalBottomSheet<int>(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: RadioGroup(
                  onChanged: (v) => Navigator.of(ctx).pop(v),
                  groupValue: value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in _labels.entries)
                        RadioListTile<int>(
                          value: entry.key,

                          title: Text(entry.value),
                        ),
                    ],
                  ),
                ),
              ),
            );
            if (selected == null) return;
            await MoodiaryKVs.quality.set(selected);
          },
        );
      },
    );
  }
}
