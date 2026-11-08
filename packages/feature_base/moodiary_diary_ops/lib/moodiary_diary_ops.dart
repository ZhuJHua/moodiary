/// Diary, category and statistics use cases shared by the in-app assistant
/// tools and the local MCP server.
///
/// The package owns the business rules (content conversion, media re-derivation,
/// recycle versus permanent delete, category validation, search fusion) and
/// returns domain objects. Tool names, JSON schemas, model-facing text and the
/// protocol adapters stay in each client.
library;

export 'src/category_ops.dart';
export 'src/diary_display.dart';
export 'src/diary_queries.dart';
export 'src/diary_stats.dart';
export 'src/diary_writes.dart';
