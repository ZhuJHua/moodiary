library;

/// The package surface the app consumes: the service, its keep-alive companion
/// and the renderer port the composition root implements. Protocol, transport,
/// tools and registry stay inside `src/`, reachable through direct imports from
/// the package's own tests.
export 'src/export/diary_image_renderer.dart';
export 'src/service/mcp_keep_alive.dart';
export 'src/service/mcp_service.dart';
