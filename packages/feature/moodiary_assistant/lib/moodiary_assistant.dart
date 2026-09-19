library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/assistant_notes_page.dart';
import 'src/presentation/assistant_page.dart';
import 'src/presentation/assistant_provider_edit_page.dart';
import 'src/presentation/assistant_provider_list_page.dart';
import 'src/presentation/assistant_provider_picker_page.dart';
import 'src/presentation/assistant_setting_page.dart';
import 'src/presentation/memory_list_page.dart';

export 'src/data/assistant.dart';
export 'src/data/impl/rig_assistant.dart';
export 'src/presentation/assistant_page.dart';
export 'src/presentation/assistant_summary_tile.dart';

List<RouteBase> assistantRoutes() => [
  GoRoute(
    path: AssistantSettingRoute.path,
    builder: (_, _) => const AssistantSettingPage(),
  ),
  GoRoute(
    path: AssistantMemoriesRoute.path,
    builder: (_, _) => const MemoryListPage(),
  ),
  GoRoute(
    path: AssistantNotesRoute.path,
    builder: (_, _) => const AssistantNotesPage(),
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
