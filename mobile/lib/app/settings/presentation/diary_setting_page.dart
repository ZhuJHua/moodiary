import 'package:gap/gap.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class DiarySettingPage extends StatelessWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.diaryPrefsTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            MSliverSettingGroup(
              title: context.l10n.app.diaryPrefsEditor,
              children: [
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
              ],
            ),
            MSliverSettingGroup(
              title: context.l10n.app.diaryPrefsDisplay,
              children: [
                _KvSwitchTile(
                  kv: .diaryHeader,
                  title: context.l10n.app.cardHeaderImage,
                ),
                _KvSwitchTile(
                  kv: .dynamicColor,
                  title: context.l10n.app.dynamicColor,
                ),
              ],
            ),
            MSliverSettingGroup(
              title: context.l10n.app.diaryPrefsMedia,
              children: [
                _KvSwitchTile(
                  kv: .imageOptimize,
                  title: context.l10n.app.imageOptimize,
                  subtitle: context.l10n.app.imageOptimizeSubtitle,
                ),
              ],
            ),
            MSliverSettingGroup(
              title: context.l10n.app.diaryPrefsWeather,
              children: [
                _KvSwitchTile(
                  kv: .autoWeather,
                  title: context.l10n.app.autoWeather,
                ),
              ],
            ),
            SliverGap(context.safeBottom),
          ],
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
        return SettingSwitchListTile(
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: (v) => kv.set(v),
        );
      },
    );
  }
}
