import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary/gen/assets.gen.dart';
import 'package:moodiary_router/moodiary_router.dart';
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isDark = context.isDarkMode;
    final appVersion = _packageInfo == null
        ? '...'
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LogoTitle(
              isDark: isDark,
              appVersion: appVersion,
              systemVersion: _systemVersion,
            ),
            const SizedBox(height: 32),
            Card.outlined(
              color: scheme.surfaceContainerLow,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SettingListTile(
                    isFirst: true,
                    leading: const Icon(LucideIcons.refreshCw),
                    title: '检查更新',
                    trailing: Text(
                      appVersion,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    onTap: () {
                      toast.info(message: '当前已是最新版本');
                    },
                  ),
                  SettingListTile(
                    leading: const Icon(LucideIcons.code),
                    title: '源码仓库',
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _open('https://github.com/ZhuJHua/moodiary'),
                  ),
                  SettingListTile(
                    leading: const Icon(LucideIcons.scrollText),
                    title: '用户协议',
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => const AgreementRoute().push(context),
                  ),
                  SettingListTile(
                    leading: const Icon(LucideIcons.shieldAlert),
                    title: '隐私政策',
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => const PrivacyRoute().push(context),
                  ),
                  SettingListTile(
                    leading: const Icon(LucideIcons.bug),
                    title: '反馈 / 答疑',
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _open('https://answer.moodiary.net'),
                  ),
                  SettingListTile(
                    isLast: true,
                    leading: const Icon(LucideIcons.handCoins),
                    title: '赞助',
                    trailing: const Icon(LucideIcons.chevronRight),
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
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        Text(
          'Moodiary',
          style: context.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              appVersion,
              style: context.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 10, child: VerticalDivider(thickness: 2)),
            Text(
              systemVersion,
              style: context.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
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
      style: context.textTheme.labelMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
