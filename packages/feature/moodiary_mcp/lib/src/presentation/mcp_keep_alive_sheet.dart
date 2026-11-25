import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:mui/mui.dart';

import '../service/mcp_keep_alive.dart';

/// Permissions for keeping MCP reachable in the background.
class McpKeepAliveSheet extends ConsumerStatefulWidget {
  const McpKeepAliveSheet({super.key});

  @override
  ConsumerState<McpKeepAliveSheet> createState() => _McpKeepAliveSheetState();
}

class _McpKeepAliveSheetState extends ConsumerState<McpKeepAliveSheet>
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
    final colors = context.theme.colors;
    final tiles = [
      for (final status in _statuses) _permissionTile(context, status),
      SettingListTile(
        title: l10n.mcpKeepAliveOpenSettings,
        leading: const Icon(LucideIcons.settings),
        trailing: const Icon(LucideIcons.externalLink, size: 20),
        onTap: () => unawaited(_openSettings()),
      ),
    ];
    return MSheetScaffold<void>(
      title: l10n.mcpKeepAlivePermissionTitle,
      icon: LucideIcons.batteryCharging,
      actions: [MAction(label: l10n.mcpKeepAliveDone, isPrimary: true)],
      child: Material(
        color: colors.surfaceContainerHigh,
        clipBehavior: .antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.theme.radii.lg),
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const MSettingDivider(),
              tiles[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _permissionTile(
    BuildContext context,
    KeepAlivePermissionStatus status,
  ) {
    final theme = context.theme;
    final l10n = context.l10n.app;
    final (title, icon, done, action) = switch (status.permission) {
      KeepAlivePermission.batteryOptimization => (
        l10n.mcpKeepAliveBatteryTitle,
        LucideIcons.batteryCharging,
        l10n.mcpKeepAliveBatteryOff,
        l10n.mcpKeepAliveBatteryTurnOff,
      ),
      KeepAlivePermission.notifications => (
        l10n.mcpKeepAliveNotificationPermissionTitle,
        LucideIcons.bell,
        l10n.mcpKeepAliveNotificationsOn,
        l10n.mcpKeepAliveNotificationsTurnOn,
      ),
    };
    return SettingListTile(
      title: title,
      leading: Icon(icon),
      trailing: status.granted
          ? Row(
              mainAxisSize: .min,
              spacing: 4,
              children: [
                const Icon(LucideIcons.check, size: 18),
                Text(done, style: theme.typography.bodyMedium.onSurfaceVariant),
              ],
            )
          : TextButton(
              onPressed: _busy ? null : () => unawaited(_request(status)),
              child: Text(action),
            ),
      onTap: status.granted ? null : () => unawaited(_request(status)),
    );
  }

  Future<void> _request(KeepAlivePermissionStatus status) async {
    setState(() => _busy = true);
    try {
      await ref.read(mcpKeepAliveProvider).request(status.permission);
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
      await ref.read(mcpKeepAliveProvider).openAppSettings();
    } catch (e, s) {
      logger.e('打开应用信息页失败', error: e, stackTrace: s);
      if (mounted) {
        toast.error(message: context.l10n.app.mcpKeepAliveRequestFailed);
      }
    }
  }

  Future<void> _refresh() async {
    try {
      final statuses = await ref.read(mcpKeepAliveProvider).statuses();
      if (!mounted) return;
      setState(() => _statuses = statuses);
    } catch (e, s) {
      logger.e('读取后台保活权限失败', error: e, stackTrace: s);
    }
  }
}
