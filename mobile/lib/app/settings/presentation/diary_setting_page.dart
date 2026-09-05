import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class DiarySettingPage extends StatelessWidget {
  const DiarySettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.diarySettings)),
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
              title: context.l10n.app.diaryPrefsWeather,
              children: [
                // 三条各管一件事：前两条走和风（没配好就灰掉、点行跳去配），第三条
                // 只要定位权限。都打开时也只打一发 GPS。
                _GatedKvSwitchTile(
                  kv: .autoWeather,
                  title: context.l10n.app.autoWeather,
                  subtitle: context.l10n.app.autoWeatherSubtitle,
                ),
                _GatedKvSwitchTile(
                  kv: .autoPosition,
                  title: context.l10n.app.autoPosition,
                  subtitle: context.l10n.app.autoPositionSubtitle,
                ),
                _KvSwitchTile(
                  kv: .autoNearestPlace,
                  title: context.l10n.app.autoNearestPlace,
                  subtitle: context.l10n.app.autoNearestPlaceSubtitle,
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

/// 依赖和风的开关：未配置时开关灰掉显示关（KV 值保留，配好即恢复），副标题改成
/// 提示，整行点击跳到第三方服务页。
///
/// 和风是否可用：host 在明文 KV（同步、可监听），key 在钥匙串（异步，走 provider，
/// 未读到前按不可用）。
class _GatedKvSwitchTile extends ConsumerWidget {
  final MoodiaryKVs<bool> kv;
  final String title;
  final String subtitle;

  const _GatedKvSwitchTile({
    required this.kv,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref
        .watch(secretKvProvider(MoodiarySecureKVs.qweatherKey))
        .value;
    return ValueListenableBuilder(
      valueListenable: MoodiaryKVs.qweatherApiHost.getNotifierOr(''),
      builder: (context, host, _) {
        final ready = host.isNotEmpty && (key?.isNotEmpty ?? false);
        if (ready) {
          return _KvSwitchTile(kv: kv, title: title, subtitle: subtitle);
        }
        return SettingListTile(
          title: title,
          subtitle: context.l10n.app.qweatherRequired,
          trailing: const Switch(value: false, onChanged: null),
          onTap: () => const ServicesRoute().push(context),
        );
      },
    );
  }
}
