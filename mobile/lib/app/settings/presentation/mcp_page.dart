import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

import 'widget/mcp_keep_alive_sheet.dart';

/// Lowest port the settings page accepts; anything below is privileged.
const int _minPort = 1024;
const int _maxPort = 65535;

enum _TokenAction { copy, regenerate }

class McpPage extends StatefulWidget {
  const McpPage({super.key});

  @override
  State<McpPage> createState() => _McpPageState();
}

class _McpPageState extends State<McpPage> with WidgetsBindingObserver {
  final McpService _service = getIt<McpService>();
  final McpKeepAlive _keepAlive = getIt<McpKeepAlive>();

  String? _lanHost;
  List<KeepAlivePermissionStatus> _permissions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.state.addListener(_onStateChanged);
    _onStateChanged();
    unawaited(_refreshPermissions());
  }

  @override
  void dispose() {
    _service.state.removeListener(_onStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _onStateChanged();
    unawaited(_refreshPermissions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.mcpPageTitle)),
      body: ValueListenableBuilder<McpServerState>(
        valueListenable: _service.state,
        builder: (context, state, _) => ValueListenableBuilder<bool>(
          valueListenable: MoodiaryKVs.mcpAllowLan.getNotifier(),
          builder: (context, lan, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const .fromLTRB(12, 4, 12, 0),
                sliver: SliverToBoxAdapter(child: _panel(context, state, lan)),
              ),
              SliverPadding(
                padding: const .symmetric(horizontal: 8),
                sliver: MSliverSettingGroup(
                  title: context.l10n.app.mcpGroupSettings,
                  children: _settingTiles(context, state, lan),
                ),
              ),
              SliverGap(context.safeBottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, McpServerState state, bool lan) {
    final l10n = context.l10n.app;
    final local = _localUri(state);
    final lanUri = lan ? _lanUri(state) : null;
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.surfaceContainerLow,
        borderRadius: .circular(context.theme.radii.lg),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          _header(context, state, lan),
          _hair(context),
          const Gap(6),
          _addressRow(context, l10n.mcpAddressLocal, local),
          _addressRow(
            context,
            l10n.mcpAddressLan,
            lanUri,
            placeholder: lan ? l10n.mcpNoWifi : l10n.mcpLanOff,
          ),
          Padding(
            padding: const .fromLTRB(12, 6, 12, 12),
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => unawaited(_copyConfig(local, lanUri)),
                child: Text(l10n.mcpCopyConfig),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, McpServerState state, bool lan) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n.app;
    final led = switch (state.status) {
      .running => context.theme.success,
      .failed => colors.error,
      .starting || .stopped => colors.outline,
    };
    final title = switch (state.status) {
      .running => l10n.mcpStatusRunning,
      .starting => l10n.mcpStatusStarting,
      .failed => l10n.mcpStatusFailedTitle,
      .stopped => l10n.mcpStatusStopped,
    };
    final micro = [
      'MCP',
      lan ? l10n.mcpAddressLan : l10n.mcpMicroLocal,
      l10n.mcpMicroPort(port: _port(state)),
    ].join(' · ');
    return Padding(
      padding: const .fromLTRB(18, 18, 12, 16),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: .circle,
                        color: led,
                        boxShadow: [
                          BoxShadow(
                            color: led.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        micro,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: typography.labelSmall.onSurfaceVariant.copyWith(
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                Text(
                  title,
                  style: state.status == .failed
                      ? typography.headlineSmall.error
                      : typography.headlineSmall.onSurface,
                ),
                if (state.status == .failed && state.failure == .portInUse) ...[
                  const Gap(4),
                  Text(
                    l10n.mcpPortInUse(port: _port(state)),
                    maxLines: 2,
                    overflow: .ellipsis,
                    style: typography.bodySmall.outline,
                  ),
                ],
              ],
            ),
          ),
          const Gap(4),
          Padding(
            padding: const .only(top: 6),
            child: ValueListenableBuilder<bool>(
              valueListenable: MoodiaryKVs.mcpEnabled.getNotifier(),
              builder: (context, enabled, _) => Switch(
                value: enabled,
                onChanged: (on) => unawaited(_setEnabled(on)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressRow(
    BuildContext context,
    String label,
    Uri? uri, {
    String placeholder = '',
  }) {
    final typography = context.theme.typography;
    final l10n = context.l10n.app;
    return Padding(
      padding: const .fromLTRB(18, 2, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  label,
                  style: typography.labelSmall.onSurfaceVariant.copyWith(
                    letterSpacing: 0.8,
                  ),
                ),
                const Gap(2),
                Text(
                  uri?.authority ?? placeholder,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: uri == null
                      ? typography.titleMedium.outline
                      : typography.titleMedium.emphasized.onSurface.tabular,
                ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: 48,
            child: uri == null
                ? null
                : IconButton(
                    tooltip: l10n.mcpCopyAddress,
                    icon: Icon(
                      LucideIcons.copy,
                      size: 20,
                      color: context.theme.colors.onSurfaceVariant,
                    ),
                    onPressed: () => _copy('$uri', l10n.mcpEndpointCopied),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _settingTiles(
    BuildContext context,
    McpServerState state,
    bool lan,
  ) {
    final l10n = context.l10n.app;
    return [
      SettingSwitchListTile(
        title: l10n.mcpLanTitle,
        secondary: const Icon(LucideIcons.wifi),
        value: lan,
        onChanged: (on) => unawaited(_setLan(on)),
      ),
      SettingListTile(
        title: l10n.mcpPortTitle,
        leading: const Icon(LucideIcons.plug),
        trailing: _value(context, '${_port(state)}'),
        onTap: () => unawaited(_editPort(state)),
      ),
      SettingListTile(
        title: l10n.mcpTokenTitle,
        leading: const Icon(LucideIcons.key),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => unawaited(_openToken()),
      ),
      SettingListTile(
        title: l10n.mcpKeepAlivePermissionTitle,
        leading: const Icon(LucideIcons.batteryCharging),
        trailing: Row(
          mainAxisSize: .min,
          spacing: 4,
          children: [
            if (_permissions.isNotEmpty)
              _value(context, _keepAliveSummary(context)),
            const Icon(LucideIcons.chevronRight),
          ],
        ),
        onTap: () => unawaited(_openKeepAliveSheet()),
      ),
    ];
  }

  Widget _hair(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 18),
    child: Divider(
      height: 1,
      thickness: 0,
      color: context.theme.colors.outlineVariant,
    ),
  );

  int _port(McpServerState state) => state.port ?? McpService.configuredPort;

  Uri _endpoint(String host, int port) =>
      Uri(scheme: 'http', host: host, port: port, path: '/mcp');

  Uri _localUri(McpServerState state) =>
      state.endpoints.firstOrNull ?? _endpoint('127.0.0.1', _port(state));

  Uri? _lanUri(McpServerState state) {
    if (state.running) return state.endpoints.skip(1).firstOrNull;
    final host = _lanHost;
    return host == null ? null : _endpoint(host, _port(state));
  }

  String _keepAliveSummary(BuildContext context) {
    final granted = _permissions.where((status) => status.granted).length;
    return granted == _permissions.length
        ? context.l10n.app.mcpKeepAlivePermissionReady
        : context.l10n.app.mcpKeepAlivePermissionSummary(
            granted: granted,
            total: _permissions.length,
          );
  }

  Widget _value(BuildContext context, String text) =>
      Text(text, style: context.theme.typography.bodyMedium.onSurfaceVariant);

  void _copy(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    toast.success(message: tip);
  }

  void _onStateChanged() {
    if (McpService.allowLan && !_service.state.value.running) {
      unawaited(_refreshLanHost());
    }
  }

  Future<void> _refreshLanHost() async {
    final host = await _service.lanHost();
    if (!mounted || host == _lanHost) return;
    setState(() => _lanHost = host);
  }

  Future<String?> _ensureToken() async {
    try {
      return await _service.ensureToken();
    } catch (e, s) {
      logger.e('读取 MCP 令牌失败', error: e, stackTrace: s);
      return null;
    }
  }

  /// With a LAN address the user picks which one the config points at.
  Future<void> _copyConfig(Uri local, Uri? lan) async {
    final l10n = context.l10n.app;
    var address = local;
    if (lan != null) {
      final picked = await MSheet.picker<Uri>(
        context,
        title: l10n.mcpConfigPickTitle,
        icon: LucideIcons.clipboardCopy,
        options: [
          MSheetOption(
            value: local,
            label: l10n.mcpAddressLocal,
            subtitle: local.authority,
            icon: LucideIcons.smartphone,
          ),
          MSheetOption(
            value: lan,
            label: l10n.mcpAddressLan,
            subtitle: lan.authority,
            icon: LucideIcons.wifi,
          ),
        ],
      );
      if (picked == null || !mounted) return;
      address = picked;
    }
    final token = await _ensureToken();
    if (!mounted || token == null) return;
    final config = const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'moodiary': {
          'url': '$address',
          'headers': {'Authorization': 'Bearer $token'},
        },
      },
    });
    _copy(config, l10n.mcpConfigCopied);
  }

  Future<void> _setEnabled(bool on) async {
    try {
      if (on) {
        await _service.enable();
      } else {
        await _service.disable();
      }
    } catch (e, s) {
      logger.e('切换 MCP 服务失败', error: e, stackTrace: s);
      if (!mounted) return;
      toast.error(message: context.l10n.common.loadFailed);
    }
  }

  Future<void> _setLan(bool lan) async {
    if (lan) {
      final confirmed = await MAlert.confirm(
        context,
        title: context.l10n.app.mcpLanConfirmTitle,
        message: context.l10n.app.mcpLanConfirmMessage,
        confirmLabel: context.l10n.app.mcpLanConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    await _service.updateConfig(lan: lan);
    _onStateChanged();
  }

  Future<void> _openToken() async {
    final token = await _ensureToken();
    if (!mounted || token == null) return;
    final l10n = context.l10n.app;
    final action = await MSheet.show<_TokenAction>(
      context,
      builder: (context) => MSheetScaffold<_TokenAction>(
        title: l10n.mcpTokenTitle,
        subtitle: l10n.mcpSecurityHint,
        icon: LucideIcons.key,
        actions: [
          MAction(label: l10n.mcpTokenRegenerate, value: .regenerate),
          MAction(label: l10n.mcpCopy, value: .copy, isPrimary: true),
        ],
        child: Container(
          padding: const .all(12),
          decoration: BoxDecoration(
            color: context.theme.colors.surfaceContainerHigh,
            borderRadius: .circular(context.theme.radii.md),
          ),
          child: SelectableText(
            token,
            style: context.theme.typography.bodyMedium.onSurface.tabular,
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case .copy:
        _copy(token, l10n.mcpTokenCopied);
      case .regenerate:
        await _regenerateToken();
      case null:
        break;
    }
  }

  Future<void> _regenerateToken() async {
    final confirmed = await MAlert.confirm(
      context,
      title: context.l10n.app.mcpTokenRegenerateTitle,
      message: context.l10n.app.mcpTokenRegenerateMessage,
      confirmLabel: context.l10n.app.mcpTokenRegenerateConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.regenerateToken();
      if (!mounted) return;
      toast.success(message: context.l10n.app.mcpTokenRegenerated);
    } catch (e, s) {
      logger.e('重新生成 MCP 令牌失败', error: e, stackTrace: s);
      if (!mounted) return;
      toast.error(message: context.l10n.common.loadFailed);
    }
  }

  Future<void> _openKeepAliveSheet() async {
    await MSheet.show<void>(
      context,
      builder: (_) => McpKeepAliveSheet(keepAlive: _keepAlive),
    );
    await _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final permissions = await _keepAlive.statuses();
    if (!mounted) return;
    setState(() => _permissions = permissions);
  }

  Future<void> _editPort(McpServerState state) async {
    final current = _port(state);
    final input = await MAlert.prompt(
      context,
      title: context.l10n.app.mcpPortTitle,
      initialValue: '$current',
      hintText: '$_minPort–$_maxPort',
      keyboardType: .number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final port = int.tryParse(value);
        return port == null || port < _minPort || port > _maxPort
            ? l10n.app.mcpPortInvalid
            : null;
      },
    );
    final port = int.tryParse(input ?? '');
    if (!mounted || port == null || port == current) return;
    await _service.updateConfig(port: port);
  }
}
