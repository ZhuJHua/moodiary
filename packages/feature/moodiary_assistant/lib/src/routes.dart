import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moodiary_router/moodiary_router.dart';

import 'presentation/assistant_page.dart';
import 'presentation/assistant_provider_edit_page.dart';
import 'presentation/assistant_provider_list_page.dart';
import 'presentation/assistant_provider_picker_page.dart';
import 'presentation/assistant_setting_page.dart';

export 'package:moodiary_router/moodiary_router.dart'
    show MoodiaryRouteBase, MoodiaryRouteNav;

List<RouteBase> assistantRoutes() => [
  GoRoute(
    path: AssistantSettingRoute.path,
    builder: (_, _) => const AssistantSettingPage(),
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
    builder: (context, state) => AssistantProviderEditPage(
      id: state.uri.queryParameters['id'],
      presetId: state.uri.queryParameters['preset'],
    ),
  ),
  GoRoute(
    path: AssistantConversationRoute.path,
    builder: (context, state) =>
        AssistantConversationRoute.fromState(state).build(),
  ),
];

class AssistantSettingRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant_setting';
  const AssistantSettingRoute();
  @override
  String get location => path;
}

class AssistantConversationRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/conversation';

  final String? sessionId;

  const AssistantConversationRoute({this.sessionId});

  @override
  String get location => buildLocation(path, {'session-id': sessionId});

  static AssistantConversationRoute fromState(GoRouterState state) =>
      AssistantConversationRoute(
        sessionId: state.uri.queryParameters['session-id'],
      );

  Widget build() => AssistantPage(initialSessionId: sessionId);
}

class AssistantDiaryPickerRoute extends MoodiaryRouteBase {
  static const String path = '/assistant/diary_picker';
  const AssistantDiaryPickerRoute();
  @override
  String get location => path;
}

class AssistantProvidersRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/providers';
  const AssistantProvidersRoute();
  @override
  String get location => path;
}

class AssistantProviderPickerRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_picker';
  const AssistantProviderPickerRoute();
  @override
  String get location => path;
}

class AssistantProviderEditRoute extends MoodiaryRouteBase {
  static const String path = '/setting/assistant/provider_edit';

  final String? id;
  final String? presetId;
  const AssistantProviderEditRoute({this.id, this.presetId});
  @override
  String get location => buildLocation(path, {'id': id, 'preset': presetId});
}
