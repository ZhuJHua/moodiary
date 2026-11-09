import 'dart:async';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_mobile/app/settings/setting_routes.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

Widget _lead(BuildContext context, IconData icon) =>
    Icon(icon, color: context.theme.colors.onSurfaceVariant);

Widget _chevron(BuildContext context) => Icon(
  LucideIcons.chevronRight,
  color: context.theme.colors.onSurfaceVariant,
);

String _subtitle(
  BuildContext context,
  McpServerState state, {
  required bool enabled,
}) {
  if (!enabled) return context.l10n.app.mcpEnableSubtitleOff;
  return switch (state.status) {
    .stopped => context.l10n.app.mcpEnableSubtitleOn,
    .starting => context.l10n.app.mcpEnableSubtitleStarting,
    .running => context.l10n.app.mcpEnableSubtitleRunning(
      port: state.port ?? 0,
    ),
    .failed => context.l10n.app.mcpEnableSubtitleFailed,
  };
}

/// The local MCP server section of the settings UI.
///
/// It is a sliver, so a host scroll view can spread it directly into its
/// `slivers` list. The app composes it into the assistant settings page
/// through the `extras` hook of `AssistantSettingPage`, because the assistant
/// feature package may not import `moodiary_mcp` itself.
class McpSettingSection extends StatefulWidget {
  const McpSettingSection({super.key});

  @override
  State<McpSettingSection> createState() => _McpSettingSectionState();
}

class _McpSettingSectionState extends State<McpSettingSection> {
  late final McpService _service = getIt<McpService>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.mcpEnabled.getNotifier(),
      builder: (context, enabled, _) => ValueListenableBuilder<McpServerState>(
        valueListenable: _service.state,
        builder: (context, state, _) => MSliverSettingGroup(
          title: context.l10n.app.sectionMcp,
          children: [
            SettingSwitchListTile(
              title: context.l10n.app.mcpEnableTitle,
              subtitle: _subtitle(context, state, enabled: enabled),
              secondary: _lead(context, LucideIcons.server),
              value: enabled,
              onChanged: (on) =>
                  unawaited(on ? _service.enable() : _service.disable()),
            ),
            SettingListTile(
              title: context.l10n.app.mcpEntryTitle,
              subtitle: state.endpoints.isEmpty
                  ? _subtitle(context, state, enabled: enabled)
                  : state.endpoints.first.toString(),
              leading: _lead(context, LucideIcons.plug),
              trailing: _chevron(context),
              onTap: () => const McpRoute().push(context),
            ),
          ],
        ),
      ),
    );
  }
}
