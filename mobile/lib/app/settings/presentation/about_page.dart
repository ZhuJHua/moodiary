import 'dart:io';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mobile/app/settings/data/app_update_repository.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:url_launcher/url_launcher.dart';

const _legalese =
    'Moodiary is free software licensed under the GNU General Public License '
    'v3.0. The licenses below cover the Dart, Rust and JavaScript packages it '
    'is built on.';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final _updateRepository = getIt<AppUpdateRepository>();

  PackageInfo? _packageInfo;
  String _systemVersion = '...';
  bool _checkingUpdate = false;

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

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final current =
          _packageInfo?.version ?? (await AppInfo.getPackageInfo()).version;
      final release = await _updateRepository.checkForUpdate(current);
      if (!mounted) return;
      if (release == null) {
        toast.info(message: l10n.app.aboutUpToDate);
        return;
      }
      final download = await MAlert.confirm(
        context,
        title: l10n.app.aboutUpdateAvailable(version: release.version),
        content: release.notes.isEmpty
            ? null
            : _ReleaseNotes(notes: release.notes),
        confirmLabel: l10n.app.aboutUpdateDownload,
        icon: LucideIcons.download,
      );
      if (download) await _open(release.pageUrl);
    } catch (error, stackTrace) {
      logger.e('check for updates failed', error: error, stackTrace: stackTrace);
      toast.error(message: l10n.app.aboutUpdateFailed);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
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
    final appVersion = _packageInfo == null
        ? '...'
        : '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.about)),
      body: SingleChildScrollView(
        padding: const .all(16),
        child: Column(
          spacing: 32,
          children: [
            _LogoTitle(appVersion: appVersion, systemVersion: _systemVersion),
            Card.filled(
              color: scheme.surfaceContainerLow,
              margin: .zero,
              child: Column(
                children: [
                  if (Platform.isAndroid)
                    SettingListTile(
                      isFirst: true,
                      leading: Icon(
                        LucideIcons.refreshCw,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: context.l10n.app.aboutCheckUpdate,
                      trailing: _checkingUpdate
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              LucideIcons.chevronRight,
                              color: scheme.onSurfaceVariant,
                            ),
                      onTap: _checkingUpdate ? null : _checkUpdate,
                    ),
                  SettingListTile(
                    isFirst: !Platform.isAndroid,
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
                      LucideIcons.scale,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.aboutLicenses,
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Moodiary',
                      applicationVersion: appVersion,
                      applicationLegalese: _legalese,
                    ),
                  ),
                  SettingListTile(
                    isLast: true,
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
                ],
              ),
            ),
            const _IcpFiling(),
          ],
        ),
      ),
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  final String notes;

  const _ReleaseNotes({required this.notes});

  String get _plainText => notes
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1')
      .replaceAll(RegExp(r'^- ', multiLine: true), '• ')
      .trim();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Text(
          _plainText,
          style: context.theme.typography.bodyMedium.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LogoTitle extends StatelessWidget {
  final String appVersion;
  final String systemVersion;

  const _LogoTitle({required this.appVersion, required this.systemVersion});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: .min,
      spacing: 16,
      children: [
        const MoodiaryLogo(size: 160),
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
