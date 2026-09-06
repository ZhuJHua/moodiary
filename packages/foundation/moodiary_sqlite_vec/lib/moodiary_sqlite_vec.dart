import 'package:sqlite3/sqlite3.dart';

import 'src/bindings.dart';

var _loaded = false;

void loadSqliteVec() {
  if (_loaded) return;
  sqlite3.ensureExtensionLoaded(SqliteExtension(vecInitAddress()));
  _loaded = true;
}
