import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class DiarySettingPage extends ConsumerWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.diaryPrefsTitle)),
      body: ListView(
        padding: const .symmetric(vertical: 8),
        children: [
          _Section(context.l10n.app.diaryPrefsEditor),
          _KvSwitchTile(
            kv: .firstLineIndent,
            title: context.l10n.app.firstLineIndent,
          ),
          _KvSwitchTile(
            kv: .autoCategory,
            title: context.l10n.app.autoCategory,
            subtitle: context.l10n.app.autoCategorySubtitle,
          ),
          _KvSwitchTile(
            kv: .showWritingTime,
            title: context.l10n.app.showWritingTime,
          ),
          _KvSwitchTile(
            kv: .showWordCount,
            title: context.l10n.app.showWordCount,
          ),
          _Section(context.l10n.app.diaryPrefsDisplay),
          _KvSwitchTile(
            kv: .diaryHeader,
            title: context.l10n.app.cardHeaderImage,
          ),
          _KvSwitchTile(
            kv: .dynamicColor,
            title: context.l10n.app.dynamicColor,
          ),
          _Section(context.l10n.app.diaryPrefsMedia),
          _KvSwitchTile(
            kv: .imageOptimize,
            title: context.l10n.app.imageOptimize,
            subtitle: context.l10n.app.imageOptimizeSubtitle,
          ),
          _Section(context.l10n.app.diaryPrefsWeather),
          _KvSwitchTile(kv: .autoWeather, title: context.l10n.app.autoWeather),
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
