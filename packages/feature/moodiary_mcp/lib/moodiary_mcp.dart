library;

import 'package:moodiary_router/moodiary_router.dart';

import 'src/presentation/mcp_page.dart';

export 'src/presentation/mcp_page.dart';
export 'src/service/mcp_keep_alive.dart';
export 'src/service/mcp_service.dart';

List<RouteBase> mcpRoutes() => [
  GoRoute(path: McpRoute.path, builder: (_, _) => const McpPage()),
];
