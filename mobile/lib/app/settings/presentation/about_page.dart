import 'dart:io';

import 'package:moodiary/gen/assets.gen.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;
  String _systemVersion = '...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pkg = await AppInfo.getPackageInfo();
    final device = await AppInfo.getInfo();
    if (!mounted) return;
    setState(() {
      _packageInfo = pkg;
      _systemVersion = _formatSystemVersion(device);
    });
  }

  String _formatSystemVersion(BaseDeviceInfo info) {
    if (info is AndroidDeviceInfo) return 'Android ${info.version.release}';
    if (info is IosDeviceInfo) return 'iOS ${info.systemVersion}';
    if (info is MacOsDeviceInfo) return 'macOS ${info.osRelease}';
    if (info is WindowsDeviceInfo) {
      return 'Windows ${info.displayVersion}';
    }
    if (info is LinuxDeviceInfo) {
      return info.prettyName;
    }
    return Platform.operatingSystem;
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: .externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final isDark = context.theme.isDark;
    final appVersion = _packageInfo == null
        ? '...'
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.about)),
      body: SingleChildScrollView(
        padding: const .all(16),
        child: Column(
          children: [
            _LogoTitle(
              isDark: isDark,
              appVersion: appVersion,
              systemVersion: _systemVersion,
            ),
            const SizedBox(height: 32),
            // 全仓卡片一律 filled：cardTheme 的 shape 会盖掉 `.outlined` 自带的那道边，
            // 写 `.outlined` 只是名不副实。
            Card.filled(
              color: scheme.surfaceContainerLow,
              margin: .zero,
              child: Column(
                children: [
                  SettingListTile(
                    isFirst: true,
                    leading: Icon(
                      LucideIcons.refreshCw,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.aboutCheckUpdate,
                    trailing: Text(
                      appVersion,
                      style: context.theme.typography.bodySmall.primary,
                    ),
                    onTap: () {
                      toast.info(message: l10n.app.aboutUpToDate);
                    },
                  ),
                  SettingListTile(
                    leading: Icon(
                      LucideIcons.code,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.aboutSource,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => _open('https://github.com/ZhuJHua/moodiary'),
                  ),
                  SettingListTile(
                    leading: Icon(
                      LucideIcons.scrollText,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.onboarding.userAgreement,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => const AgreementRoute().push(context),
                  ),
                  SettingListTile(
                    leading: Icon(
                      LucideIcons.shieldAlert,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.onboarding.privacyPolicy,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => const PrivacyRoute().push(context),
                  ),
                  SettingListTile(
                    leading: Icon(
                      LucideIcons.bug,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.aboutFeedback,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => _open('https://answer.moodiary.net'),
                  ),
                  SettingListTile(
                    isLast: true,
                    leading: Icon(
                      LucideIcons.handCoins,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.aboutSponsor,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => const SponsorRoute().push(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _IcpFiling(),
          ],
        ),
      ),
    );
  }
}

class _LogoTitle extends StatelessWidget {
  final bool isDark;
  final String appVersion;
  final String systemVersion;

  const _LogoTitle({
    required this.isDark,
    required this.appVersion,
    required this.systemVersion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final scheme = theme.colors;
    return Column(
      mainAxisSize: .min,
      children: [
        Image.asset(
          isDark
              ? Assets.icon.dark.darkForeground.path
              : Assets.icon.light.lightForeground.path,
          color: scheme.onSurface,
          height: 160,
          width: 160,
        ),
        const SizedBox(height: 8),
        Text('Moodiary', style: theme.typography.titleLarge.onSurface),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: .center,
          children: [
            Text(appVersion, style: theme.typography.labelSmall.primary),
            const SizedBox(height: 10, child: VerticalDivider(thickness: 2)),
            Text(systemVersion, style: theme.typography.labelSmall.onSurface),
          ],
        ),
      ],
    );
  }
}

class _IcpFiling extends StatelessWidget {
  const _IcpFiling();

  @override
  Widget build(BuildContext context) {
    return Text(
      '赣ICP备2022010939号-4A',
      style: context.theme.typography.labelMedium.onSurfaceVariant,
    );
  }
}
