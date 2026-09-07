import 'dart:io';

import 'package:isar_plus/isar_plus.dart';
import 'package:path/path.dart' as p;

const String legacyDbFileName = 'default.isar';

const int legacyMaxSizeMiB = 4096;

bool legacyDbExistsIn(String dir) =>
    File(p.join(dir, legacyDbFileName)).existsSync();

Isar? openLegacyIsar({
  required List<IsarGeneratedSchema> schemas,
  required String dir,
  bool inspector = true,
}) {
  if (!legacyDbExistsIn(dir)) return null;
  return Isar.open(
    schemas: schemas,
    directory: dir,
    maxSizeMiB: legacyMaxSizeMiB,
    inspector: inspector,
  );
}
