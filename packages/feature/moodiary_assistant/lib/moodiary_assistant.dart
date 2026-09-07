library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/agent_preset_edit_page.dart';
import 'src/presentation/agent_preset_list_page.dart';
import 'src/presentation/assistant_page.dart';
import 'src/presentation/assistant_provider_edit_page.dart';
import 'src/presentation/assistant_provider_list_page.dart';
import 'src/presentation/assistant_provider_picker_page.dart';
import 'src/presentation/assistant_setting_page.dart';

export 'src/data/assistant.dart' show AssistantService;
export 'src/data/impl/rig_assistant.dart' show RigAssistantService;
export 'src/presentation/assistant_page.dart'
    show AssistantPage, AssistantSessionListPage;
export 'src/presentation/assistant_summary_tile.dart' show AssistantSummaryTile;

List<RouteBase> assistantRoutes() => [
  GoRoute(
    path: AssistantSettingRoute.path,
    builder: (_, _) => const AssistantSettingPage(),
  ),
  GoRoute(
    path: AssistantPresetsRoute.path,
    builder: (_, _) => const AgentPresetListPage(),
  ),
  GoRoute(
    path: AssistantPresetEditRoute.path,
    builder: (_, state) => AgentPresetEditPage.fromRoute(state),
  ),
  GoRoute(
    path: AssistantProvidersRoute.path,
    builder: (_, _) => const AssistantProviderListPage(),
  ),
  GoRoute(
    path: AssistantProviderPickerRoute.path,
    builder: (_, _) => const AssistantProviderPickerPage(),
  ),
  GoRoute(
    path: AssistantProviderEditRoute.path,
    builder: (_, state) => AssistantProviderEditPage.fromRoute(state),
  ),
  GoRoute(
    path: AssistantConversationRoute.path,
    builder: (_, state) => AssistantPage.fromRoute(state),
  ),
];
