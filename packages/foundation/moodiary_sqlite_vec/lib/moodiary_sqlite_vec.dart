import 'package:sqlite3/sqlite3.dart';

import 'src/bindings.dart';

var _loaded = false;

/// 把 sqlite-vec 注册进 sqlite3 包自带的 SQLite（`sqlite3_auto_extension`，
/// 进程级一次性；必须在打开任何连接之前调用，之后的每个连接自动带上 vec0）。
void loadSqliteVec() {
  if (_loaded) return;
  sqlite3.ensureExtensionLoaded(SqliteExtension(vecInitAddress()));
  _loaded = true;
}
