import 'dart:async';
import 'dart:io';

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

/// Shown instead of the token until the user reveals it.
const String _maskedToken = '••••••••';

String _statusText(BuildContext context, McpServerState state) =>
    switch (state.status) {
      .stopped => context.l10n.app.mcpStatusStopped,
      .starting => context.l10n.app.mcpStatusStarting,
      .running => context.l10n.app.mcpStatusRunning(port: state.port ?? 0),
      .failed => context.l10n.app.mcpStatusFailed(
        error: state.error ?? context.l10n.common.loadFailed,
      ),
    };

/// Loopback-only servers may run without a token, but LAN access never may.
bool _requiresToken({required bool lan, required bool stored}) => lan || stored;

class McpPage extends StatefulWidget {
  const McpPage({super.key});

  @override
  State<McpPage> createState() => _McpPageState();
}

class _McpPageState extends State<McpPage> with WidgetsBindingObserver {
  final McpService _service = getIt<McpService>();
  final McpKeepAlive _keepAlive = getIt<McpKeepAlive>();

  bool _revealToken = false;
  List<KeepAlivePermissionStatus> _permissions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadToken());
    unawaited(_refreshPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshPermissions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.mcpPageTitle)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: ValueListenableBuilder<McpServerState>(
          valueListenable: _service.state,
          builder: (context, state, _) => CustomScrollView(
            slivers: [
              _serverSection(context, state),
              _keepAliveSection(context),
              _accessSection(context, state),
              _networkSection(context, state),
              SliverGap(context.safeBottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverSection(BuildContext context, McpServerState state) {
    return MSliverSettingGroup(
      title: context.l10n.app.mcpGroupServer,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: MoodiaryKVs.mcpEnabled.getNotifier(),
          builder: (context, enabled, _) => SettingSwitchListTile(
            title: context.l10n.app.mcpEnableTitle,
            subtitle: enabled ? null : context.l10n.app.mcpEnableSubtitleOff,
            secondary: _lead(context, LucideIcons.server),
            value: enabled,
            onChanged: (on) => unawaited(_setEnabled(on)),
          ),
        ),
        SettingListTile(
          title: context.l10n.app.mcpStatusTitle,
          subtitle: _statusText(context, state),
          leading: _lead(
            context,
            LucideIcons.power,
            failed: state.status == .failed,
          ),
        ),
      ],
    );
  }

  Widget _keepAliveSection(BuildContext context) {
    if (!_keepAlive.supported) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return MSliverSettingGroup(
      title: context.l10n.app.mcpGroupKeepAlive,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: MoodiaryKVs.mcpBackgroundKeepAlive.getNotifier(),
          builder: (context, keepAlive, _) => SettingSwitchListTile(
            title: context.l10n.app.mcpKeepAliveTitle,
            subtitle: context.l10n.app.mcpKeepAliveSubtitle,
            secondary: _lead(context, LucideIcons.batteryCharging),
            value: keepAlive,
            onChanged: (on) => unawaited(_setKeepAlive(on)),
          ),
        ),
        // 安卓的前台服务要一项电池优化豁免和通知权限；iOS 没有对应的系统开关。
        if (Platform.isAndroid)
          SettingListTile(
            title: context.l10n.app.mcpKeepAlivePermissionTitle,
            subtitle: _keepAliveSubtitle(context),
            leading: _lead(context, LucideIcons.shield),
            trailing: _chevron(context),
            onTap: () => unawaited(_openKeepAliveSheet()),
          ),
      ],
    );
  }

  Widget _accessSection(BuildContext context, McpServerState state) {
    final endpoints = state.endpoints;
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.mcpAllowLan.getNotifier(),
      builder: (context, lan, _) => ValueListenableBuilder<bool>(
        valueListenable: MoodiaryKVs.mcpRequireToken.getNotifier(),
        builder: (context, stored, _) {
          final required = _requiresToken(lan: lan, stored: stored);
          return MSliverSettingGroup(
            title: context.l10n.app.mcpGroupAccess,
            children: [
              if (endpoints.isEmpty)
                SettingListTile(
                  title: context.l10n.app.mcpEndpointTitle,
                  subtitle: context.l10n.app.mcpEndpointHint,
                  leading: _lead(context, LucideIcons.link),
                )
              else
                for (final endpoint in endpoints)
                  SettingListTile(
                    title: context.l10n.app.mcpEndpointTitle,
                    subtitle: endpoint.toString(),
                    leading: _lead(context, LucideIcons.link),
                    trailing: IconButton(
                      tooltip: context.l10n.app.mcpCopy,
                      icon: Icon(
                        LucideIcons.copy,
                        color: context.theme.colors.onSurfaceVariant,
                      ),
                      onPressed: () => _copy(
                        endpoint.toString(),
                        context.l10n.app.mcpEndpointCopied,
                      ),
                    ),
                    onTap: () => _copy(
                      endpoint.toString(),
                      context.l10n.app.mcpEndpointCopied,
                    ),
                  ),
              SettingSwitchListTile(
                title: context.l10n.app.mcpRequireTokenTitle,
                subtitle: lan
                    ? context.l10n.app.mcpRequireTokenForced
                    : context.l10n.app.mcpRequireTokenSubtitle,
                secondary: _lead(context, LucideIcons.key),
                value: required,
                onChanged: lan ? null : (on) => unawaited(_setRequireToken(on)),
              ),
              if (!required)
                SettingListTile(
                  title: context.l10n.app.mcpTokenTitle,
                  subtitle: context.l10n.app.mcpTokenDisabled,
                  leading: _lead(context, LucideIcons.key),
                )
              else ...[
                SettingListTile(
                  title: context.l10n.app.mcpTokenTitle,
                  subtitle: _revealToken
                      ? (_service.token ?? context.l10n.app.mcpTokenLoading)
                      : _maskedToken,
                  leading: _lead(context, LucideIcons.key),
                  trailing: IconButton(
                    tooltip: _revealToken
                        ? context.l10n.app.mcpTokenHide
                        : context.l10n.app.mcpTokenShow,
                    icon: Icon(
                      _revealToken ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: context.theme.colors.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        setState(() => _revealToken = !_revealToken),
                  ),
                  onTap: () => unawaited(_copyToken()),
                ),
                SettingListTile(
                  title: context.l10n.app.mcpTokenRegenerate,
                  subtitle: context.l10n.app.mcpSecurityHint,
                  leading: _lead(context, LucideIcons.refreshCw),
                  trailing: _chevron(context),
                  onTap: _regenerateToken,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _networkSection(BuildContext context, McpServerState state) {
    return MSliverSettingGroup(
      title: context.l10n.app.mcpGroupNetwork,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: MoodiaryKVs.mcpAllowLan.getNotifier(),
          builder: (context, lan, _) => SettingSwitchListTile(
            title: context.l10n.app.mcpLanTitle,
            subtitle: context.l10n.app.mcpLanSubtitle,
            secondary: _lead(context, LucideIcons.wifi),
            value: lan,
            onChanged: (on) => unawaited(_setLan(on)),
          ),
        ),
        SettingListTile(
          title: context.l10n.app.mcpPortTitle,
          subtitle: context.l10n.app.mcpPortBound(
            port: state.port ?? McpService.configuredPort,
          ),
          leading: _lead(context, LucideIcons.plug),
          trailing: _chevron(context),
          onTap: () => unawaited(_editPort(state)),
        ),
      ],
    );
  }

  String _keepAliveSubtitle(BuildContext context) {
    final l10n = context.l10n.app;
    if (_permissions.isEmpty) return l10n.mcpKeepAlivePermissionSubtitle;
    final granted = _permissions.where((status) => status.granted).length;
    if (granted == _permissions.length) {
      return l10n.mcpKeepAlivePermissionReady;
    }
    return l10n.mcpKeepAlivePermissionSummary(
      granted: granted,
      total: _permissions.length,
    );
  }

  Widget _lead(BuildContext context, IconData icon, {bool failed = false}) {
    final colors = context.theme.colors;
    return Icon(icon, color: failed ? colors.error : colors.onSurfaceVariant);
  }

  Widget _chevron(BuildContext context) => Icon(
    LucideIcons.chevronRight,
    color: context.theme.colors.onSurfaceVariant,
  );

  void _copy(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    toast.success(message: tip);
  }

  Future<void> _loadToken() async {
    if (!_requiresToken(
      lan: MoodiaryKVs.mcpAllowLan.get() ?? false,
      stored: MoodiaryKVs.mcpRequireToken.get() ?? true,
    )) {
      return;
    }
    final token = await _ensureToken();
    if (!mounted || token == null) return;
    setState(() {});
  }

  Future<String?> _ensureToken() async {
    try {
      return await _service.ensureToken();
    } catch (e, s) {
      logger.e('读取 MCP 令牌失败', error: e, stackTrace: s);
      return null;
    }
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
    await _service.updateConfig(lan: lan);
    if (!mounted) return;
    toast.success(message: context.l10n.app.mcpSaved);
    if (lan) await _loadToken();
  }

  Future<void> _setRequireToken(bool required) async {
    await _service.updateConfig(requireToken: required);
    if (!mounted) return;
    toast.success(message: context.l10n.app.mcpSaved);
    if (required) await _loadToken();
  }

  Future<void> _setKeepAlive(bool on) async {
    try {
      await _keepAlive.setEnabled(on);
      if (!mounted) return;
      toast.success(message: context.l10n.app.mcpKeepAliveSaved);
    } catch (e, s) {
      logger.e('切换 MCP 后台保活失败', error: e, stackTrace: s);
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
    if (!Platform.isAndroid) return;
    try {
      final permissions = await _keepAlive.statuses();
      if (!mounted) return;
      setState(() => _permissions = permissions);
    } catch (e, s) {
      logger.e('读取后台保活权限失败', error: e, stackTrace: s);
    }
  }

  Future<void> _copyToken() async {
    final token = _service.token ?? await _ensureToken();
    if (!mounted || token == null) return;
    setState(() {});
    _copy(token, context.l10n.app.mcpTokenCopied);
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
      setState(() {});
      toast.success(message: context.l10n.app.mcpTokenRegenerated);
    } catch (e, s) {
      logger.e('重新生成 MCP 令牌失败', error: e, stackTrace: s);
      if (!mounted) return;
      toast.error(message: context.l10n.common.loadFailed);
    }
  }

  Future<void> _editPort(McpServerState state) async {
    final current = state.port ?? McpService.configuredPort;
    final input = await MAlert.prompt(
      context,
      title: context.l10n.app.mcpPortTitle,
      message: context.l10n.app.mcpPortHelp,
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
    if (!mounted || port == null) return;
    await _service.updateConfig(port: port);
    if (!mounted) return;
    final bound = _service.state.value.port;
    if (bound != null && bound != port) {
      toast.info(message: context.l10n.app.mcpPortBound(port: bound));
    } else {
      toast.success(message: context.l10n.app.mcpSaved);
    }
  }
}
