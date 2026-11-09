import 'dart:async';

import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:mui/mui.dart';

/// Lists the permissions the platform needs before the MCP server can stay
/// reachable in the background, one row per permission, each with its current
/// state and the action that grants it.
///
/// The settings page owns the summary line of its entry; this sheet reads the
/// live state itself and refreshes whenever the app returns from a system
/// settings screen (the app lifecycle observer covers both the runtime
/// permission dialog and a jump into the app info page).
class McpKeepAliveSheet extends StatefulWidget {
  const McpKeepAliveSheet({super.key, required this.keepAlive});

  final McpKeepAlive keepAlive;

  @override
  State<McpKeepAliveSheet> createState() => _McpKeepAliveSheetState();
}

class _McpKeepAliveSheetState extends State<McpKeepAliveSheet>
    with WidgetsBindingObserver {
  List<KeepAlivePermissionStatus> _statuses = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.app;
    final theme = context.theme;
    return MSheetScaffold<void>(
      title: l10n.mcpKeepAliveSheetTitle,
      subtitle: l10n.mcpKeepAliveSheetSubtitle,
      icon: LucideIcons.batteryCharging,
      actions: [MAction(label: l10n.mcpKeepAliveDone, isPrimary: true)],
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          for (final status in _statuses) _permissionTile(context, status),
          _settingsTile(context),
          Padding(
            padding: const .symmetric(horizontal: 4, vertical: 2),
            child: Text(
              l10n.mcpKeepAliveSettingsHint,
              style: theme.typography.bodySmall.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionTile(
    BuildContext context,
    KeepAlivePermissionStatus status,
  ) {
    final theme = context.theme;
    final l10n = context.l10n.app;
    final granted = status.granted;
    final (title, description, icon) = switch (status.permission) {
      KeepAlivePermission.batteryOptimization => (
        l10n.mcpKeepAliveBatteryTitle,
        l10n.mcpKeepAliveBatteryDesc,
        LucideIcons.batteryCharging,
      ),
      KeepAlivePermission.notifications => (
        l10n.mcpKeepAliveNotificationTitle,
        l10n.mcpKeepAliveNotificationDesc,
        LucideIcons.bell,
      ),
    };
    final accent = granted ? theme.colors.primary : theme.colors.error;
    return _surface(
      context,
      SettingListTile(
        title: title,
        subtitle: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(
              description,
              style: theme.typography.bodyMedium.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  granted ? LucideIcons.checkCircle : LucideIcons.circleAlert,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Text(
                  granted
                      ? l10n.mcpKeepAliveGranted
                      : l10n.mcpKeepAliveNotGranted,
                  style: theme.typography.bodySmall.onSurfaceVariant.copyWith(
                    color: accent,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: Icon(icon, color: accent),
        trailing: granted
            ? null
            : TextButton(
                onPressed: _busy ? null : () => unawaited(_request(status)),
                child: Text(l10n.mcpKeepAliveGrant),
              ),
        onTap: granted ? null : () => unawaited(_request(status)),
      ),
    );
  }

  Widget _settingsTile(BuildContext context) {
    final theme = context.theme;
    return _surface(
      context,
      SettingListTile(
        title: context.l10n.app.mcpKeepAliveOpenSettings,
        leading: Icon(
          LucideIcons.settings,
          color: theme.colors.onSurfaceVariant,
        ),
        trailing: Icon(
          LucideIcons.externalLink,
          color: theme.colors.onSurfaceVariant,
        ),
        onTap: () => unawaited(_openSettings()),
      ),
    );
  }

  Widget _surface(BuildContext context, Widget child) {
    final theme = context.theme;
    return Material(
      color: theme.colors.surfaceContainerHigh,
      clipBehavior: .antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radii.lg),
      ),
      child: child,
    );
  }

  Future<void> _request(KeepAlivePermissionStatus status) async {
    setState(() => _busy = true);
    try {
      await widget.keepAlive.request(status.permission);
    } catch (e, s) {
      logger.e('申请后台保活权限失败', error: e, stackTrace: s);
      if (mounted) {
        toast.error(message: context.l10n.app.mcpKeepAliveRequestFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) await _refresh();
  }

  Future<void> _openSettings() async {
    try {
      await widget.keepAlive.openAppSettings();
    } catch (e, s) {
      logger.e('打开应用信息页失败', error: e, stackTrace: s);
      if (mounted) {
        toast.error(message: context.l10n.app.mcpKeepAliveRequestFailed);
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final statuses = await widget.keepAlive.statuses();
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (e, s) {
      logger.e('读取后台保活权限失败', error: e, stackTrace: s);
    }
  }
}
